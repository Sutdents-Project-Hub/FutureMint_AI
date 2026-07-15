import { describe, expect, it, vi } from "vitest";

import { LiangjieAiProvider } from "../../src/adapters/liangjieAiProvider";
import { DomainError } from "../../src/contracts/errors";

const validCapture = JSON.stringify({
  drafts: [
    {
      type: "expense",
      amountMinor: 75,
      category: "food",
      merchant: "珍奶",
      occurredAt: "2026-07-13T12:00:00+08:00",
      confidence: 0.93,
      missingFields: [],
    },
  ],
});

const completion = (content: string) => ({
  choices: [{ message: { content } }],
});

describe("LiangjieAiProvider", () => {
  it("validates structured capture output and marks its source", async () => {
    const create = vi.fn().mockResolvedValue(completion(validCapture));
    const provider = new LiangjieAiProvider({
      client: { chat: { completions: { create } } },
      model: "gemini-2.5-flash",
    });

    const result = await provider.parseCapture({
      text: "今天買珍奶 75",
      locale: "zh-TW",
      referenceTime: "2026-07-13T12:00:00+08:00",
    });

    expect(result.drafts[0]).toMatchObject({
      type: "expense",
      amountMinor: 75,
      source: "liangjie-ai",
      needsConfirmation: true,
    });
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        model: "gemini-2.5-flash",
        messages: expect.any(Array),
      }),
      expect.any(Object),
    );
    expect(create.mock.calls[0][0]).not.toHaveProperty("response_format");
  });

  it("accepts JSON wrapped in a markdown fence before validating it", async () => {
    const provider = new LiangjieAiProvider({
      client: {
        chat: {
          completions: {
            create: vi
              .fn()
              .mockResolvedValue(completion(`\`\`\`json\n${validCapture}\n\`\`\``)),
          },
        },
      },
      model: "gemini-2.5-flash",
    });

    await expect(
      provider.parseCapture({
        text: "珍奶 75",
        locale: "zh-TW",
        referenceTime: "2026-07-13T12:00:00+08:00",
      }),
    ).resolves.toMatchObject({ drafts: [{ amountMinor: 75 }] });
  });

  it("normalizes nullable fields required by strict structured output", async () => {
    const create = vi.fn().mockResolvedValue(
      completion(
        JSON.stringify({
          drafts: [
            {
              type: "subscription",
              amountMinor: 75,
              category: "subscription",
              merchant: null,
              occurredAt: "2026-07-13T12:00:00+08:00",
              recurrence: { billingCycle: "monthly", nextBillingAt: null },
              split: null,
              confidence: 0.93,
              missingFields: [],
            },
          ],
          clarificationQuestion: null,
          rejectedReason: null,
        }),
      ),
    );
    const provider = new LiangjieAiProvider({
      client: { chat: { completions: { create } } },
      model: "gemini-2.5-flash",
    });

    const result = await provider.parseCapture({
      text: "訂閱 75",
      locale: "zh-TW",
      referenceTime: "2026-07-13T12:00:00+08:00",
    });

    expect(result.drafts[0]).not.toHaveProperty("merchant");
    expect(result.drafts[0].recurrence).toEqual({ billingCycle: "monthly" });
    expect(result.clarificationQuestion).toBeUndefined();
  });

  it("rejects malformed model output as a retryable sanitized domain error", async () => {
    const provider = new LiangjieAiProvider({
      client: {
        chat: {
          completions: {
            create: vi
              .fn()
              .mockResolvedValue(completion('{"drafts":[{"amountMinor":-1}]}')),
          },
        },
      },
      model: "gemini-2.5-flash",
    });

    await expect(
      provider.parseCapture({
        text: "早餐 65",
        locale: "zh-TW",
        referenceTime: "2026-07-13T12:00:00+08:00",
      }),
    ).rejects.toMatchObject<Partial<DomainError>>({
      code: "ai_invalid_output",
      status: 503,
      retryable: true,
    });
  });

  it("rejects a semantic type and category contradiction", async () => {
    const contradictory = JSON.stringify({
      drafts: [
        {
          type: "expense",
          amountMinor: 1500,
          category: "income",
          merchant: null,
          occurredAt: "2026-07-13T12:00:00+08:00",
          recurrence: null,
          split: null,
          confidence: 0.9,
          missingFields: [],
        },
      ],
      clarificationQuestion: null,
      rejectedReason: null,
    });
    const provider = new LiangjieAiProvider({
      client: {
        chat: {
          completions: {
            create: vi.fn().mockResolvedValue(completion(contradictory)),
          },
        },
      },
      model: "gemini-2.5-flash",
    });

    await expect(
      provider.parseCapture({
        text: "打工收入 1500",
        locale: "zh-TW",
        referenceTime: "2026-07-13T12:00:00+08:00",
      }),
    ).rejects.toMatchObject({ code: "ai_invalid_output", status: 503 });
  });

  it("retries one 429 without logging the original financial text", async () => {
    const rateLimit = Object.assign(new Error("rate limited"), {
      status: 429,
      headers: new Headers({ "retry-after": "0" }),
    });
    const create = vi
      .fn()
      .mockRejectedValueOnce(rateLimit)
      .mockResolvedValueOnce(completion(validCapture));
    const logged: unknown[] = [];
    const provider = new LiangjieAiProvider({
      client: { chat: { completions: { create } } },
      model: "gemini-2.5-flash",
      sleep: async () => undefined,
      logger: (event) => logged.push(event),
    });

    await provider.parseCapture({
      text: "秘密商家消費 75",
      locale: "zh-TW",
      referenceTime: "2026-07-13T12:00:00+08:00",
    });

    expect(create).toHaveBeenCalledTimes(2);
    expect(JSON.stringify(logged)).not.toContain("秘密商家");
  });

  it("aborts a call that exceeds the configured per-call timeout", async () => {
    const create = vi.fn(
      (_body: unknown, options?: { signal?: AbortSignal }) =>
        new Promise((_resolve, reject) => {
          options?.signal?.addEventListener("abort", () =>
            reject(Object.assign(new Error("aborted"), { name: "AbortError" })),
          );
        }),
    );
    const provider = new LiangjieAiProvider({
      client: { chat: { completions: { create } } },
      model: "gemini-2.5-flash",
      perCallTimeoutMs: 5,
      totalBudgetMs: 20,
    });

    await expect(
      provider.parseCapture({
        text: "早餐 65",
        locale: "zh-TW",
        referenceTime: "2026-07-13T12:00:00+08:00",
      }),
    ).rejects.toMatchObject({ code: "ai_timeout", status: 503 });
  });

  it("validates a bounded lesson without sending a full event ledger", async () => {
    const create = vi.fn().mockResolvedValue(
      completion(
        JSON.stringify({
          title: "固定支出，也能重新選擇",
          concept: "先把固定支出換算成月成本，再比較使用頻率與方案資格。",
          example: "把使用頻率與方案資格放在一起比較。",
          question: "你會先檢查哪一項？",
          options: ["使用頻率", "方案資格"],
          action: "今天先檢查一項訂閱。",
          disclaimer: "內容僅供金融教育。",
        }),
      ),
    );
    const provider = new LiangjieAiProvider({
      client: { chat: { completions: { create } } },
      model: "gemini-2.5-flash",
    });

    const lesson = await provider.generateLesson({
      userId: "demo-user",
      profile: {
        userId: "demo-user",
        monthlyBudgetMinor: 6000,
        goalName: "活動基金",
        goalTargetMinor: 12000,
        goalSavedMinor: 4200,
        goalDate: "2026-10-31",
        preferredTone: "supportive",
      },
      events: [
        {
          id: "event-1",
          userId: "demo-user",
          type: "subscription",
          amountMinor: 390,
          currency: "TWD",
          category: "subscription",
          merchant: "合成影音服務",
          occurredAt: "2026-07-01T08:00:00+08:00",
          createdAt: "2026-07-01T08:00:00+08:00",
          updatedAt: "2026-07-01T08:00:00+08:00",
        },
      ],
    });

    expect(lesson.source).toBe("liangjie-ai");
    expect(lesson.sourceEventIds).toEqual(["event-1"]);
    expect(JSON.stringify(create.mock.calls[0])).not.toContain("userId");
    expect(JSON.stringify(create.mock.calls[0])).not.toContain("amountMinor");
  });

  it("rejects lesson prose that invents numeric financial facts", async () => {
    const create = vi.fn().mockResolvedValue(
      completion(
        JSON.stringify({
          title: "固定支出",
          concept: "先檢查需求與資格。",
          example: "每月 390 元，一年就是 4680 元。",
          question: "你會先檢查什麼？",
          options: ["使用頻率", "方案資格"],
          action: "先檢查固定訂閱。",
          disclaimer: "內容僅供金融教育。",
        }),
      ),
    );
    const provider = new LiangjieAiProvider({
      client: { chat: { completions: { create } } },
      model: "gemini-2.5-flash",
    });

    await expect(
      provider.generateLesson({
        userId: "demo-user",
        profile: {
          userId: "demo-user",
          monthlyBudgetMinor: 6000,
          goalName: "活動基金",
          goalTargetMinor: 12000,
          goalSavedMinor: 4200,
          goalDate: "2026-10-31",
          preferredTone: "supportive",
        },
        events: [],
      }),
    ).rejects.toMatchObject({ code: "ai_invalid_output", status: 503 });
  });
});
