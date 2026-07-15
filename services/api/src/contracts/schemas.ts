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
    .min(12, "密碼至少需要 12 個字元。")
    .max(128, "密碼不得超過 128 個字元。")
    .regex(/[A-Za-z]/, "密碼需包含英文字母。")
    .regex(/\d/, "密碼需包含數字。"),
});

export const splitDetailsSchema = z.object({
  participants: z.number().int().min(2).max(20),
  userShareMinor: positiveMoney,
});

export const moneyEventInputSchema = z
  .object({
    type: z.enum(moneyEventTypes),
    amountMinor: positiveMoney,
    currency: z.literal("TWD").default("TWD"),
    category: z.enum(moneyCategories),
    merchant: z.string().trim().min(1).max(80).optional(),
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
    confirmed: z.literal(true),
    idempotencyKey: z.string().min(8).max(120),
  })
  .superRefine((event, context) => {
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
    if (event.type === "subscription" && !event.recurrence) {
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
  scenarioId: z.enum(investmentScenarioIds).optional(),
  selectedYear: z.number().int().min(1).max(30).optional(),
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
