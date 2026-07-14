export const moneyEventTypes = ["income", "expense", "subscription"] as const;
export type MoneyEventType = (typeof moneyEventTypes)[number];

export const moneyCategories = [
  "food",
  "transport",
  "entertainment",
  "education",
  "shopping",
  "income",
  "subscription",
  "other",
] as const;
export type MoneyCategory = (typeof moneyCategories)[number];

export const billingCycles = ["monthly", "yearly"] as const;
export type BillingCycle = (typeof billingCycles)[number];

export interface SplitDetails {
  participants: number;
  userShareMinor: number;
}

export interface Recurrence {
  billingCycle: BillingCycle;
  nextBillingAt?: string;
}

export interface MoneyEvent {
  id: string;
  userId: string;
  type: MoneyEventType;
  amountMinor: number;
  currency: "TWD";
  category: MoneyCategory;
  merchant?: string;
  occurredAt: string;
  recurrence?: Recurrence;
  split?: SplitDetails;
  idempotencyKey?: string;
  createdAt: string;
  updatedAt: string;
}

export interface UserProfile {
  userId: string;
  monthlyBudgetMinor: number;
  weeklyBudgetMinor?: number;
  goalName: string;
  goalTargetMinor: number;
  goalSavedMinor: number;
  goalDate: string;
  preferredTone: "supportive" | "direct";
}

export interface Account {
  id: string;
  userId: string;
  email: string;
  passwordHash: string;
  passwordSalt: string;
  passwordAlgorithm: "scrypt-v1";
  profileComplete: boolean;
  createdAt: string;
}

export interface PublicAccount {
  id: string;
  email: string;
  profileComplete: boolean;
  createdAt: string;
}

export interface SessionRecord {
  id: string;
  userId: string;
  tokenHash: string;
  createdAt: string;
  expiresAt: string;
  revokedAt?: string;
}

export interface CategoryTotal {
  category: MoneyCategory;
  amountMinor: number;
}

export interface DashboardSummary {
  monthlyBudgetMinor: number;
  incomeMinor: number;
  expenseMinor: number;
  subscriptionMinor: number;
  availableMinor: number;
  goalRemainingMinor: number;
  goalProgress: number;
  categoryTotals: CategoryTotal[];
  recentEvents: MoneyEvent[];
}

export interface FutureSeedInput {
  monthlyContributionMinor: number;
  years: number;
  annualRatePercent: number;
}

export interface FutureSeedYearPoint {
  year: number;
  principalMinor: number;
  balanceMinor: number;
}

export interface FutureSeedPreview {
  principalMinor: number;
  growthMinor: number;
  endingBalanceMinor: number;
  yearlyPoints: FutureSeedYearPoint[];
  disclaimer: string;
}

export interface SubscriptionCompareInput {
  currentName: string;
  currentPriceMinor: number;
  currentBillingCycle: BillingCycle;
  members: number;
  isStudent: boolean;
}

export interface SubscriptionPlan {
  id: string;
  name: string;
  priceMinor: number;
  billingCycle: BillingCycle;
  eligibility: "any" | "student" | `shared-${number}`;
  sourceType: "synthetic" | "manual" | "licensed-public";
  asOf: string;
}

export interface SubscriptionOption extends SubscriptionPlan {
  monthlyCostMinor: number;
  userMonthlyCostMinor: number;
  monthlySavingsMinor: number | null;
  eligible: boolean;
  eligibilityMessage: string;
}

export interface SubscriptionComparison {
  currentName: string;
  currentMonthlyCostMinor: number;
  options: SubscriptionOption[];
  disclaimer: string;
}

export interface ApiProblem {
  code: string;
  message: string;
  requestId: string;
  retryable: boolean;
  fieldErrors?: Record<string, string>;
}

export interface CaptureDraft {
  draftId: string;
  type: MoneyEventType;
  amountMinor?: number;
  currency: "TWD";
  category: MoneyCategory;
  merchant?: string;
  occurredAt: string;
  recurrence?: Recurrence;
  split?: SplitDetails;
  confidence: number;
  missingFields: string[];
  needsConfirmation: true;
  source: "azure-ai" | "deterministic-demo";
}

export interface CaptureParseResult {
  drafts: CaptureDraft[];
  clarificationQuestion?: string;
  rejectedReason?: string;
}

export interface Lesson {
  id: string;
  userId: string;
  title: string;
  concept: string;
  example: string;
  question: string;
  options: string[];
  action: string;
  disclaimer: string;
  sourceEventIds: string[];
  source: "azure-ai" | "deterministic-demo";
  selectedOption?: string;
  completedAt?: string;
  createdAt: string;
}
