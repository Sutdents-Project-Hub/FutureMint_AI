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

export const accountRoles = ["child", "parent"] as const;
export type AccountRole = (typeof accountRoles)[number];

export interface FamilyGroupRecord {
  familyId: string;
  inviteCode: string;
  createdBy: string;
}

export interface FamilyMemberRecord {
  familyId: string;
  userId: string;
  email: string;
  role: AccountRole;
  joinedAt: string;
}

export interface FamilyMember {
  userId: string;
  role: AccountRole;
  label: string;
  isSelf: boolean;
}

export interface FamilyChildSummary {
  userId: string;
  label: string;
  monthlyBudgetMinor: number;
  incomeMinor: number;
  expenseMinor: number;
  subscriptionMinor: number;
  availableMinor: number;
  goalProgress: number;
  summary: string;
  noticeCount: number;
}

export interface FamilyOverview {
  familyId: string;
  inviteCode?: string;
  members: FamilyMember[];
  childSummaries: FamilyChildSummary[];
}

export const spendingIntents = ["need", "want", "uncertain"] as const;
export type SpendingIntent = (typeof spendingIntents)[number];

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
  spendingIntent?: SpendingIntent;
  intentReason?: string;
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
  accountRole: AccountRole;
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
  spendingIntent?: SpendingIntent;
  intentReason?: string;
  confidence: number;
  missingFields: string[];
  needsConfirmation: true;
  source: "liangjie-ai" | "deterministic-demo";
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
  source: "liangjie-ai" | "deterministic-demo";
  selectedOption?: string;
  completedAt?: string;
  createdAt: string;
}

export interface MonthlyCashflowPoint {
  month: string;
  incomeMinor: number;
  expenseMinor: number;
  subscriptionMinor: number;
  netMinor: number;
}

export interface InsightNotice {
  id: string;
  kind: "subscription" | "spending" | "saving" | "learning";
  level: "info" | "attention" | "positive";
  title: string;
  message: string;
  actionPath: string;
  amountMinor?: number;
}

export interface FinancialInsights {
  generatedAt: string;
  monthlyCashflow: MonthlyCashflowPoint[];
  needMinor: number;
  wantMinor: number;
  uncertainMinor: number;
  subscriptionMinor: number;
  summary: string;
  notices: InsightNotice[];
}

export interface LearningPlanModule {
  id: "need-want" | "subscription" | "compound" | "risk";
  title: string;
  reason: string;
  nextAction: string;
  status: "next" | "queued";
}

export interface LearningPlan {
  title: string;
  summary: string;
  modules: LearningPlanModule[];
  source: "liangjie-ai" | "deterministic-demo";
  disclaimer: string;
}

export const investmentScenarioIds = [
  "steady",
  "balanced",
  "high-risk",
] as const;
export type InvestmentScenarioId = (typeof investmentScenarioIds)[number];

export interface InvestmentSimulationInput {
  initialAmountMinor: number;
  monthlyContributionMinor: number;
  years: number;
}

export interface InvestmentYearPoint {
  year: number;
  principalMinor: number;
  balanceMinor: number;
  annualReturnPercent: number;
  eventLabel?: string;
}

export interface InvestmentScenario {
  id: InvestmentScenarioId;
  title: string;
  description: string;
  assumedAnnualRatePercent: number;
  riskLabel: string;
  principalMinor: number;
  growthMinor: number;
  endingBalanceMinor: number;
  maxDrawdownPercent: number;
  yearlyPoints: InvestmentYearPoint[];
}

export interface InvestmentSimulation {
  initialAmountMinor: number;
  monthlyContributionMinor: number;
  years: number;
  scenarios: InvestmentScenario[];
  assumptionVersion: string;
  disclaimer: string;
}

export interface CoachRequest {
  topic: "spending" | "subscription" | "compound" | "risk" | "general";
  question: string;
  style?: "brief" | "example" | "steps";
  scenarioId?: InvestmentScenarioId;
  selectedYear?: number;
}

export interface CoachReply {
  answer: string;
  takeaway: string;
  suggestions: string[];
  source: "liangjie-ai" | "deterministic-demo";
  disclaimer: string;
}

export const investmentOrderSides = ["buy", "sell"] as const;
export type InvestmentOrderSide = (typeof investmentOrderSides)[number];

export const marketQuoteSources = [
  "twse-openapi",
  "educational-snapshot",
] as const;
export type MarketQuoteSource = (typeof marketQuoteSources)[number];

export interface MarketQuote {
  symbol: string;
  name: string;
  kind: "etf" | "stock";
  sector: string;
  price: number;
  change: number;
  changePercent: number;
  asOf: string;
  source: MarketQuoteSource;
}

export interface MarketSnapshot {
  quotes: MarketQuote[];
  fetchedAt: string;
  source: MarketQuoteSource;
  sourceLabel: string;
  sourceUrl: string;
  isFallback: boolean;
  disclaimer: string;
}

export interface VirtualInvestmentAccount {
  userId: string;
  startingCashMinor: number;
  createdAt: string;
}

export interface VirtualInvestmentOrder {
  id: string;
  userId: string;
  symbol: string;
  name: string;
  side: InvestmentOrderSide;
  quantity: number;
  unitPrice: number;
  totalMinor: number;
  quoteAsOf: string;
  quoteSource: MarketQuoteSource;
  idempotencyKey: string;
  createdAt: string;
}

export interface VirtualHolding {
  symbol: string;
  name: string;
  quantity: number;
  averageCost: number;
  currentPrice: number;
  costMinor: number;
  marketValueMinor: number;
  gainLossMinor: number;
  allocationPercent: number;
}

export interface InvestmentLab {
  startingCashMinor: number;
  cashMinor: number;
  marketValueMinor: number;
  totalAssetMinor: number;
  gainLossMinor: number;
  returnPercent: number;
  diversificationScore: number;
  learningSummary: string;
  holdings: VirtualHolding[];
  orders: VirtualInvestmentOrder[];
  market: MarketSnapshot;
  disclaimer: string;
}

export interface InvestmentOrderInput {
  symbol: string;
  side: InvestmentOrderSide;
  quantity: number;
  idempotencyKey: string;
}

export interface SaveInvestmentOrderInput extends InvestmentOrderInput {
  name: string;
  unitPrice: number;
  totalMinor: number;
  quoteAsOf: string;
  quoteSource: MarketQuoteSource;
}

export interface PracticeDiceEvent {
  id: string;
  rollIndex: number;
  title: string;
  situation: string;
  practicePrompt: string;
  coachQuestion: string;
  learningFocus: "diversification" | "discipline" | "risk" | "fees";
  deckVersion: string;
  disclaimer: string;
}
