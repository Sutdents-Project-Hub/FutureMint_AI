import type { SubscriptionPlan } from "../contracts/models";

export const demoCatalog: SubscriptionPlan[] = [
  {
    id: "stream-student-yearly",
    name: "學生年繳方案",
    priceMinor: 2400,
    billingCycle: "yearly",
    eligibility: "student",
    sourceType: "synthetic",
    asOf: "2026-07-13",
  },
  {
    id: "stream-shared-four",
    name: "合法共享月繳方案",
    priceMinor: 520,
    billingCycle: "monthly",
    eligibility: "shared-4",
    sourceType: "synthetic",
    asOf: "2026-07-13",
  },
  {
    id: "stream-basic",
    name: "基本月繳方案",
    priceMinor: 220,
    billingCycle: "monthly",
    eligibility: "any",
    sourceType: "synthetic",
    asOf: "2026-07-13",
  },
];
