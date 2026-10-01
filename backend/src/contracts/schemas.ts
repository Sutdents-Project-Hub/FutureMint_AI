import { z } from "zod";

import {
  accountRoles,
  billingCycles,
  investmentOrderSides,
  investmentScenarioIds,
  moneyCategories,
  moneyEventTypes,
  spendingIntents,
} from "./models";

const positiveMoney = z.number().int().positive().max(100_000_000);
const isoDateTime = z.string().datetime({ offset: true });

export const authCredentialsSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z
    .string()
    .min(8, "密碼至少需要 8 個字元。")
    .max(128, "密碼不得超過 128 個字元。")
    .regex(/[A-Za-z]/, "密碼需包含英文字母。")
    .regex(/\d/, "密碼需包含數字。"),
});

export const aiConsentInputSchema = z.object({
  granted: z.boolean(),
});

export const accountDeletionSchema = z.object({
  password: authCredentialsSchema.shape.password,
});

export const splitDetailsSchema = z.object({
  participants: z.number().int().min(2).max(20),
  userShareMinor: positiveMoney,
});

const moneyEventFieldsSchema = z.object({
    type: z.enum(moneyEventTypes),
    amountMinor: positiveMoney,
    currency: z.literal("TWD").default("TWD"),
    category: z.enum(moneyCategories),
    merchant: z.string().trim().min(1).max(80).optional(),
    subscriptionId: z.string().trim().min(1).max(120).optional(),
    occurredAt: isoDateTime,
    recurrence: z
      .object({
        billingCycle: z.enum(billingCycles),
        nextBillingAt: isoDateTime.optional(),
      })
      .optional(),
    split: splitDetailsSchema.optional(),
    spendingIntent: z.enum(spendingIntents).optional(),
    intentReason: z.string().trim().min(1).max(160).optional(),
    source: z.enum(["manual","liangjie-ai","openai-ai","deterministic-demo"]).optional(),
    confirmed: z.literal(true),
    idempotencyKey: z.string().min(8).max(120),
  });

type MoneyEventValidationInput = {
  type: string;
  category: string;
  recurrence?: unknown;
  subscriptionId?: string;
  split?: unknown;
  spendingIntent?: unknown;
};

const validateMoneyEvent = (
  event: MoneyEventValidationInput,
  context: z.RefinementCtx,
  resolvingExistingLink = false,
) => {
    const validCategory =
      (event.type === "income" && event.category === "income") ||
      (event.type === "subscription" && event.category === "subscription") ||
      (event.type === "expense" &&
        event.category !== "income" &&
        event.category !== "subscription");
    if (!validCategory) {
      context.addIssue({
        code: "custom",
        path: ["category"],
        message: "交易類型與分類不一致。",
      });
    }
    if (!resolvingExistingLink && event.type === "subscription" && !event.recurrence && !event.subscriptionId) {
      context.addIssue({
        code: "custom",
        path: ["recurrence"],
        message: "訂閱必須確認計費週期。",
      });
    }
    if (event.type !== "subscription" && event.recurrence) {
      context.addIssue({
        code: "custom",
        path: ["recurrence"],
        message: "只有訂閱可以設定計費週期。",
      });
    }
    if (event.subscriptionId && event.type !== "subscription") {
      context.addIssue({ code: "custom", path: ["subscriptionId"], message: "只有訂閱付款可以連結訂閱。" });
    }
    if (event.type === "income" && event.split) {
      context.addIssue({
        code: "custom",
        path: ["split"],
        message: "收入事件不使用分帳。",
      });
    }
    if (event.type === "income" && event.spendingIntent) {
      context.addIssue({
        code: "custom",
        path: ["spendingIntent"],
        message: "收入不使用需要或想要分類。",
      });
    }
  };

export const moneyEventInputSchema = moneyEventFieldsSchema.superRefine(
  validateMoneyEvent,
);

export const moneyEventUpdateSchema = moneyEventFieldsSchema
  .omit({ idempotencyKey: true })
  .superRefine((event, context) => validateMoneyEvent({
    ...event,
    subscriptionId: event.type === "subscription" ? event.subscriptionId : undefined,
  }, context, true));

export const moneyEventIdParamsSchema = z.object({
  eventId: z.string().trim().min(1).max(120),
});

export const moneyEventListQuerySchema = z
  .object({
    type: z.enum(moneyEventTypes).optional(),
    from: isoDateTime.optional(),
    to: isoDateTime.optional(),
  })
  .refine(({ from, to }) => !from || !to || new Date(from) <= new Date(to), {
    message: "from 不得晚於 to。",
    path: ["from"],
  });

export const profileInputSchema = z.object({
  monthlyBudgetMinor: positiveMoney,
  weeklyBudgetMinor: positiveMoney.optional(),
  goalName: z.string().trim().min(1).max(60),
  goalTargetMinor: positiveMoney,
  goalSavedMinor: z.number().int().min(0).max(100_000_000),
  goalDate: z.string().date(),
  preferredTone: z.enum(["supportive", "direct"]),
  accountRole: z.enum(accountRoles).default("child"),
});

export const captureParseInputSchema = z.object({
  text: z.string().trim().min(1).max(800),
  locale: z.literal("zh-TW").default("zh-TW"),
  referenceTime: isoDateTime,
});

export const futureSeedInputSchema = z.object({
  monthlyContributionMinor: positiveMoney,
  years: z.number().int().min(1).max(50),
  annualRatePercent: z.number().min(0).max(20),
});

export const investmentSimulationInputSchema = z.object({
  initialAmountMinor: z.number().int().min(0).max(100_000_000),
  monthlyContributionMinor: positiveMoney,
  years: z.number().int().min(1).max(30),
});

export const coachRequestSchema = z.object({
  topic: z.enum(["spending", "subscription", "compound", "risk", "general"]),
  question: z.string().trim().min(1).max(300),
  style: z.enum(["brief", "example", "steps"]).default("example"),
  scenarioId: z.enum(investmentScenarioIds).optional(),
  selectedYear: z.number().int().min(1).max(30).optional(),
});

export const familyJoinInputSchema = z.object({
  inviteCode: z
    .string()
    .trim()
    .regex(
      /^[A-Za-z0-9_-]{24}$/u,
      "邀請碼應為 24 碼安全英數字元。",
    ),
});

export const lessonCompletionInputSchema = z.object({
  selectedOption: z.string().trim().min(1).max(200),
});

export const investmentOrderInputSchema = z.object({
  symbol: z.string().trim().regex(/^\d{4,6}[A-Z]?$/).max(8),
  side: z.enum(investmentOrderSides),
  quantity: z.number().int().min(1).max(1000),
  idempotencyKey: z.string().min(8).max(120),
});

export const practiceDiceInputSchema = z.object({
  rollIndex: z.number().int().min(0).max(10_000),
});

export const subscriptionCompareInputSchema = z.object({
  currentName: z.string().trim().min(1).max(80),
  currentPriceMinor: positiveMoney,
  currentBillingCycle: z.enum(billingCycles),
  members: z.number().int().min(1).max(20),
  isStudent: z.boolean(),
});

export const subscriptionInputSchema = z.object({
  name: z.string().trim().min(1).max(80),
  amountMinor: positiveMoney,
  currency: z.literal("TWD").default("TWD"),
  billingCycle: z.enum(billingCycles),
  anchorDate: z.string().date(),
}).strict();
export const subscriptionCreateInputSchema = subscriptionInputSchema.extend({
  idempotencyKey: z.string().min(8).max(120),
  legacyPaymentId: z.string().trim().min(1).max(120).optional(),
  initialPayment: moneyEventFieldsSchema.superRefine((event,context)=>validateMoneyEvent({...event,subscriptionId:"new"},context)).optional(),
}).strict().refine((input)=>!input.initialPayment || !input.legacyPaymentId,{path:["legacyPaymentId"],message:"首次付款與舊付款採用只能擇一。"});
export const subscriptionIdParamsSchema = z.object({ subscriptionId: z.string().trim().min(1).max(120) });
export const moneyEventPageQuerySchema = z.object({
  type: z.enum(moneyEventTypes).optional(),
  from: isoDateTime.optional(), to: isoDateTime.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  cursor: z.string().min(1).max(600).optional(),
}).strict().refine(({from,to}) => !from || !to || new Date(from) <= new Date(to), {path:["from"], message:"from 不得晚於 to。"});
