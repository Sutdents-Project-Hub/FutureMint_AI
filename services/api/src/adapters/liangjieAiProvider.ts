import { randomUUID } from "node:crypto";

import OpenAI from "openai";
import { z } from "zod";

import type {
  AiProvider,
  CaptureInput,
  LessonContext,
  LearningPlanContext,
} from "../application/ports";
import { DomainError } from "../contracts/errors";
import {
  billingCycles,
  moneyCategories,
  moneyEventTypes,
  spendingIntents,
  type CoachReply,
  type CoachRequest,
  type CaptureParseResult,
  type Lesson,
  type LearningPlan,
} from "../contracts/models";

interface ChatClient {
  chat: {
    completions: {
      create(
        body: unknown,
        options?: { signal?: AbortSignal },
      ): Promise<unknown>;
    };
  };
}

interface ProviderOptions {
  client: ChatClient;
  model: string;
  perCallTimeoutMs?: number;
  totalBudgetMs?: number;
  sleep?: (milliseconds: number) => Promise<void>;
  logger?: (event: Record<string, unknown>) => void;
}

const draftSchema = z
  .object({
    type: z.enum(moneyEventTypes),
    amountMinor: z
      .number()
      .int()
      .positive()
      .max(100_000_000)
      .nullable()
      .optional(),
    category: z.enum(moneyCategories),
    merchant: z.string().trim().min(1).max(80).nullable().optional(),
    occurredAt: z.string().datetime({ offset: true }),
    recurrence: z
      .object({
        billingCycle: z.enum(billingCycles),
        nextBillingAt: z
          .string()
          .datetime({ offset: true })
          .nullable()
          .optional(),
      })
      .nullable()
      .optional(),
    split: z
      .object({
        participants: z.number().int().min(2).max(20),
        userShareMinor: z.number().int().positive(),
      })
      .nullable()
      .optional(),
    spendingIntent: z.enum(spendingIntents).nullable().optional(),
    intentReason: z.string().trim().min(1).max(160).nullable().optional(),
    confidence: z.number().min(0).max(1),
    missingFields: z.array(z.string()).max(5),
  })
  .superRefine((draft, context) => {
    const validCategory =
      (draft.type === "income" && draft.category === "income") ||
      (draft.type === "subscription" && draft.category === "subscription") ||
      (draft.type === "expense" &&
        draft.category !== "income" &&
        draft.category !== "subscription");
    if (!validCategory) {
      context.addIssue({
        code: "custom",
        path: ["category"],
        message: "交易類型與分類不一致。",
      });
    }
    if (draft.type !== "subscription" && draft.recurrence) {
      context.addIssue({
        code: "custom",
        path: ["recurrence"],
        message: "非訂閱事件不得含計費週期。",
      });
    }
    if (draft.type === "income" && draft.split) {
      context.addIssue({
        code: "custom",
        path: ["split"],
        message: "收入事件不使用分帳。",
      });
    }
    if (draft.type === "income" && draft.spendingIntent) {
      context.addIssue({
        code: "custom",
        path: ["spendingIntent"],
        message: "收入不使用需要或想要分類。",
      });
    }
  });

const captureOutputSchema = z.object({
  drafts: z.array(draftSchema).max(5),
  clarificationQuestion: z.string().max(100).nullable().optional(),
  rejectedReason: z.string().max(120).nullable().optional(),
});

const unverifiedQuantity =
  /[0-9０-９]|百分之|[一二三四五六七八九十百千萬兩半]+(?:元|年|個?月|週|天|日|%|％|分鐘)/u;
const lessonText = (max: number) =>
  z
    .string()
    .min(1)
    .max(max)
    .refine((value) => !unverifiedQuantity.test(value), {
      message: "AI 課程不得新增未驗證的數量、金額或期限。",
    });

const lessonOutputSchema = z.object({
  title: lessonText(60),
  concept: lessonText(100),
  example: lessonText(160),
  question: lessonText(100),
  options: z.array(lessonText(80)).min(2).max(4),
  action: lessonText(120),
  disclaimer: z.string().min(1).max(120),
});

const learningPlanOutputSchema = z.object({
  title: lessonText(60),
  summary: lessonText(180),
  modules: z
    .array(
      z.object({
        id: z.enum(["need-want", "subscription", "compound", "risk"]),
        title: lessonText(60),
        reason: lessonText(140),
        nextAction: lessonText(120),
      }),
    )
    .length(4)
    .refine((modules) => new Set(modules.map((item) => item.id)).size === 4, {
      message: "學習規劃主題不得重複。",
    }),
  disclaimer: z.string().min(1).max(120),
});

const unsafeCoachLanguage =
  /(?:建議|推薦).{0,6}(?:買入|賣出|投資)|買進|賣出|穩賺|保證報酬|必定獲利/u;
const coachOutputSchema = z.object({
  answer: z.string().min(1).max(320).refine((value) => !unsafeCoachLanguage.test(value)),
  takeaway: z.string().min(1).max(160).refine((value) => !unsafeCoachLanguage.test(value)),
  suggestions: z.array(z.string().min(1).max(80)).min(2).max(3),
  disclaimer: z.string().min(1).max(120),
});

const captureJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["drafts", "clarificationQuestion", "rejectedReason"],
  properties: {
    drafts: {
      type: "array",
      maxItems: 5,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "type",
          "amountMinor",
          "category",
          "merchant",
          "occurredAt",
          "recurrence",
          "split",
          "spendingIntent",
          "intentReason",
          "confidence",
          "missingFields",
        ],
        properties: {
          type: { type: "string", enum: moneyEventTypes },
          amountMinor: { type: ["integer", "null"], minimum: 1 },
          category: { type: "string", enum: moneyCategories },
          merchant: { type: ["string", "null"] },
          occurredAt: { type: "string" },
          recurrence: {
            anyOf: [
              {
                type: "object",
                additionalProperties: false,
                required: ["billingCycle", "nextBillingAt"],
                properties: {
                  billingCycle: { type: "string", enum: billingCycles },
                  nextBillingAt: { type: ["string", "null"] },
                },
              },
              { type: "null" },
            ],
          },
          split: {
            anyOf: [
              {
                type: "object",
                additionalProperties: false,
                required: ["participants", "userShareMinor"],
                properties: {
                  participants: { type: "integer", minimum: 2, maximum: 20 },
                  userShareMinor: { type: "integer", minimum: 1 },
                },
              },
              { type: "null" },
            ],
          },
          spendingIntent: {
            type: ["string", "null"],
            enum: [...spendingIntents, null],
          },
          intentReason: { type: ["string", "null"] },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          missingFields: { type: "array", items: { type: "string" } },
        },
      },
    },
    clarificationQuestion: { type: ["string", "null"] },
    rejectedReason: { type: ["string", "null"] },
  },
};

const lessonJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "title",
    "concept",
    "example",
    "question",
    "options",
    "action",
    "disclaimer",
  ],
  properties: {
    title: { type: "string" },
    concept: { type: "string" },
    example: { type: "string" },
    question: { type: "string" },
    options: {
      type: "array",
      minItems: 2,
      maxItems: 4,
      items: { type: "string" },
    },
    action: { type: "string" },
    disclaimer: { type: "string" },
  },
};

const learningPlanJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["title", "summary", "modules", "disclaimer"],
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
    modules: {
      type: "array",
      minItems: 4,
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["id", "title", "reason", "nextAction"],
        properties: {
          id: {
            type: "string",
            enum: ["need-want", "subscription", "compound", "risk"],
          },
          title: { type: "string" },
          reason: { type: "string" },
          nextAction: { type: "string" },
        },
      },
    },
    disclaimer: { type: "string" },
  },
};

const coachJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["answer", "takeaway", "suggestions", "disclaimer"],
  properties: {
    answer: { type: "string" },
    takeaway: { type: "string" },
    suggestions: {
      type: "array",
      minItems: 2,
      maxItems: 3,
      items: { type: "string" },
    },
    disclaimer: { type: "string" },
  },
};

const completionContent = (response: unknown): string => {
  const content = (
    response as { choices?: Array<{ message?: { content?: unknown } }> }
  ).choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new DomainError(
      "ai_invalid_output",
      "AI 回覆格式無法驗證。",
      503,
      true,
    );
  }
  return content;
};

const completionJson = (response: unknown): unknown => {
  const content = completionContent(response).trim();
  const withoutFence = content
    .replace(/^```(?:json)?\s*/iu, "")
    .replace(/\s*```$/u, "")
    .trim();
  const start = withoutFence.indexOf("{");
  const end = withoutFence.lastIndexOf("}");
  if (start < 0 || end < start) {
    throw new DomainError(
      "ai_invalid_output",
      "AI 回覆格式無法驗證。",
      503,
      true,
    );
  }
  return JSON.parse(withoutFence.slice(start, end + 1));
};

const retryAfterSeconds = (error: unknown): number => {
  const headers = (
    error as {
      headers?: Headers | Record<string, string | undefined>;
    }
  ).headers;
  if (!headers) return 0;
  const value =
    typeof (headers as Headers).get === "function"
      ? (headers as Headers).get("retry-after")
      : (headers as Record<string, string | undefined>)["retry-after"];
  const parsed = Number(value ?? "0");
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
};

export class LiangjieAiProvider implements AiProvider {
  private readonly client: ChatClient;
  private readonly model: string;
  private readonly perCallTimeoutMs: number;
  private readonly totalBudgetMs: number;
  private readonly sleep: (milliseconds: number) => Promise<void>;
  private readonly logger: (event: Record<string, unknown>) => void;

  constructor(options: ProviderOptions) {
    this.client = options.client;
    this.model = options.model;
    this.perCallTimeoutMs = options.perCallTimeoutMs ?? 8000;
    this.totalBudgetMs = options.totalBudgetMs ?? 12000;
    this.sleep =
      options.sleep ??
      ((milliseconds) =>
        new Promise((resolve) => setTimeout(resolve, milliseconds)));
    this.logger = options.logger ?? (() => undefined);
  }

  private async request(body: Record<string, unknown>): Promise<unknown> {
    const startedAt = Date.now();
    for (let attempt = 1; attempt <= 2; attempt += 1) {
      const controller = new AbortController();
      const timeout = setTimeout(
        () => controller.abort(),
        this.perCallTimeoutMs,
      );
      try {
        const response = await this.client.chat.completions.create(body, {
          signal: controller.signal,
        });
        this.logger({
          event: "liangjie_ai_success",
          attempt,
          elapsedMs: Date.now() - startedAt,
        });
        return response;
      } catch (error) {
        const status = (error as { status?: number }).status;
        const aborted = (error as { name?: string }).name === "AbortError";
        this.logger({
          event: aborted ? "liangjie_ai_timeout" : "liangjie_ai_error",
          attempt,
          status,
        });
        if (aborted) {
          throw new DomainError(
            "ai_timeout",
            "AI 回應逾時，請稍後再試。",
            503,
            true,
          );
        }
        if (status !== 429 || attempt === 2) {
          throw new DomainError(
            status === 429 ? "ai_rate_limited" : "ai_unavailable",
            "AI 服務暫時無法使用，請稍後再試。",
            status === 429 ? 429 : 503,
            true,
          );
        }
        const retryAfter = retryAfterSeconds(error);
        const delayMs =
          Math.max(0, retryAfter * 1000) + Math.floor(Math.random() * 50);
        if (
          Date.now() - startedAt + delayMs + this.perCallTimeoutMs >
          this.totalBudgetMs
        ) {
          throw new DomainError(
            "ai_rate_limited",
            "AI 使用量暫時過高，請稍後再試。",
            429,
            true,
          );
        }
        await this.sleep(delayMs);
      } finally {
        clearTimeout(timeout);
      }
    }
    throw new DomainError("ai_unavailable", "AI 服務暫時無法使用。", 503, true);
  }

  async parseCapture(input: CaptureInput): Promise<CaptureParseResult> {
    const response = await this.request({
      model: this.model,
      messages: [
        {
          role: "system",
          content:
            `你是青少年金錢事件解析器。只抽取已發生的收入、支出或訂閱；否定句不得建立草稿。金額不可猜測。對支出與訂閱提供 need、want 或 uncertain 建議與非責備理由；資訊不足必須選 uncertain，這只是可修改建議。收入的 spendingIntent 與 intentReason 都輸出 null。只輸出一個 JSON object，不得加上 Markdown 或解釋。JSON Schema：${JSON.stringify(captureJsonSchema)}`,
        },
        {
          role: "user",
          content: JSON.stringify({
            text: input.text,
            locale: input.locale,
            referenceTime: input.referenceTime,
          }),
        },
      ],
    });

    try {
      const parsed = captureOutputSchema.parse(
        completionJson(response),
      );
      return {
        drafts: parsed.drafts.map((draft) => ({
          draftId: randomUUID(),
          type: draft.type,
          ...(draft.amountMinor == null
            ? {}
            : { amountMinor: draft.amountMinor }),
          currency: "TWD",
          category: draft.category,
          ...(draft.merchant == null ? {} : { merchant: draft.merchant }),
          occurredAt: draft.occurredAt,
          ...(draft.recurrence == null
            ? {}
            : {
                recurrence: {
                  billingCycle: draft.recurrence.billingCycle,
                  ...(draft.recurrence.nextBillingAt == null
                    ? {}
                    : { nextBillingAt: draft.recurrence.nextBillingAt }),
                },
              }),
          ...(draft.split == null ? {} : { split: draft.split }),
          ...(draft.type === "income"
            ? {}
            : {
                spendingIntent: draft.spendingIntent ?? "uncertain",
                intentReason:
                  draft.intentReason ??
                  "AI 沒有足夠情境判斷，請依當時狀況自行確認。",
              }),
          confidence: draft.confidence,
          missingFields: draft.missingFields,
          needsConfirmation: true,
          source: "liangjie-ai",
        })),
        clarificationQuestion: parsed.clarificationQuestion ?? undefined,
        rejectedReason: parsed.rejectedReason ?? undefined,
      };
    } catch (error) {
      if (error instanceof DomainError) throw error;
      throw new DomainError(
        "ai_invalid_output",
        "AI 回覆格式無法驗證。",
        503,
        true,
      );
    }
  }

  async generateLesson(context: LessonContext): Promise<Lesson> {
    const eventSummary = context.events.slice(-5).map((event) => ({
      type: event.type,
      category: event.category,
      hasRecurrence: Boolean(event.recurrence),
      hasSplit: Boolean(event.split),
    }));
    const response = await this.request({
      model: this.model,
      messages: [
        {
          role: "system",
          content:
            `產生非責備語氣的繁體中文青少年金融微課。不得推薦投資標的或保證報酬；不得自行新增、推算或回述任何金額、比例、期限或數量。只輸出一個 JSON object，不得加上 Markdown 或解釋。JSON Schema：${JSON.stringify(lessonJsonSchema)}`,
        },
        {
          role: "user",
          content: JSON.stringify({
            goalName: context.profile.goalName,
            eventSummary,
          }),
        },
      ],
    });

    try {
      const parsed = lessonOutputSchema.parse(
        completionJson(response),
      );
      return {
        id: randomUUID(),
        userId: context.userId,
        ...parsed,
        sourceEventIds: context.events.slice(-5).map((event) => event.id),
        source: "liangjie-ai",
        createdAt: new Date().toISOString(),
      };
    } catch (error) {
      if (error instanceof DomainError) throw error;
      throw new DomainError(
        "ai_invalid_output",
        "AI 課程格式無法驗證。",
        503,
        true,
      );
    }
  }

  async generateLearningPlan(
    context: LearningPlanContext,
  ): Promise<LearningPlan> {
    const response = await this.request({
      model: this.model,
      messages: [
        {
          role: "system",
          content:
            `你是青少年金融教育規劃助手。依聚合分類調整四個固定主題的順序與理由：need-want、subscription、compound、risk。不得推薦標的、保證報酬或自行新增任何數量。每個 id 必須恰好出現一次。只輸出 JSON object。JSON Schema：${JSON.stringify(learningPlanJsonSchema)}`,
        },
        {
          role: "user",
          content: JSON.stringify({
            accountRole: context.profile.accountRole,
            hasGoal: context.profile.goalName.length > 0,
            eventCategories: context.events.map((event) => event.category),
            hasSubscriptions: context.insights.subscriptionMinor > 0,
            hasUncertainIntent: context.insights.uncertainMinor > 0,
          }),
        },
      ],
    });
    try {
      const parsed = learningPlanOutputSchema.parse(completionJson(response));
      return {
        ...parsed,
        modules: parsed.modules.map((module, index) => ({
          ...module,
          status: index === 0 ? "next" : "queued",
        })),
        source: "liangjie-ai",
      };
    } catch (error) {
      if (error instanceof DomainError) throw error;
      throw new DomainError(
        "ai_invalid_output",
        "AI 學習規劃格式無法驗證。",
        503,
        true,
      );
    }
  }

  async coach(request: CoachRequest): Promise<CoachReply> {
    const response = await this.request({
      model: this.model,
      messages: [
        {
          role: "system",
          content:
            `你是青少年金融教育陪讀員，只能解釋需要與想要、訂閱檢查、複利、波動與分散。不得推薦或評價任何投資標的，不得保證報酬，不得重算或新增金額、報酬率、期限。使用繁體中文與非責備語氣，只輸出 JSON object。JSON Schema：${JSON.stringify(coachJsonSchema)}`,
        },
        {
          role: "user",
          content: JSON.stringify({
            topic: request.topic,
            question: request.question,
            scenarioId: request.scenarioId,
            selectedYear: request.selectedYear,
          }),
        },
      ],
    });
    try {
      return {
        ...coachOutputSchema.parse(completionJson(response)),
        source: "liangjie-ai",
      };
    } catch (error) {
      if (error instanceof DomainError) throw error;
      throw new DomainError(
        "ai_invalid_output",
        "AI 陪讀回覆格式無法驗證。",
        503,
        true,
      );
    }
  }
}

export const createLiangjieAiProviderFromEnvironment =
  (): LiangjieAiProvider => {
    const baseURL = process.env.LIANGJIE_BASE_URL;
    const model = process.env.LIANGJIE_MODEL;
    const apiKey = process.env.LIANGJIE_API_KEY;
    if (!baseURL || !model || !apiKey) {
      throw new Error(
        "LIANGJIE_BASE_URL, LIANGJIE_MODEL and LIANGJIE_API_KEY are required",
      );
    }
    const client = new OpenAI({
      baseURL: baseURL.replace(/\/+$/u, ""),
      apiKey,
      maxRetries: 0,
    });
    return new LiangjieAiProvider({
      client: client as unknown as ChatClient,
      model,
      logger: (event) => console.info("futuremint_ai_provider", event),
    });
  };
