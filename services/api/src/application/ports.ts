import type {
  Account,
  CoachReply,
  CoachRequest,
  CaptureParseResult,
  FinancialInsights,
  MarketSnapshot,
  Lesson,
  LearningPlan,
  MoneyEvent,
  SaveInvestmentOrderInput,
  SessionRecord,
  UserProfile,
  VirtualInvestmentAccount,
  VirtualInvestmentOrder,
} from "../contracts/models";

export interface CaptureInput {
  text: string;
  locale: "zh-TW";
  referenceTime: string;
}

export interface LessonContext {
  userId: string;
  profile: UserProfile;
  events: MoneyEvent[];
}

export interface LearningPlanContext extends LessonContext {
  insights: FinancialInsights;
}

export interface AiProvider {
  parseCapture(input: CaptureInput): Promise<CaptureParseResult>;
  generateLesson(context: LessonContext): Promise<Lesson>;
  generateLearningPlan(context: LearningPlanContext): Promise<LearningPlan>;
  coach(request: CoachRequest): Promise<CoachReply>;
}

export interface MarketDataProvider {
  getSnapshot(): Promise<MarketSnapshot>;
}

export interface ConfirmedMoneyEventInput {
  type: MoneyEvent["type"];
  amountMinor: number;
  currency: "TWD";
  category: MoneyEvent["category"];
  merchant?: string;
  occurredAt: string;
  recurrence?: MoneyEvent["recurrence"];
  split?: MoneyEvent["split"];
  spendingIntent?: MoneyEvent["spendingIntent"];
  intentReason?: MoneyEvent["intentReason"];
  confirmed: true;
  idempotencyKey: string;
}

export interface FutureMintRepository {
  getProfile(userId: string): Promise<UserProfile>;
  saveProfile(profile: UserProfile): Promise<UserProfile>;
  listMoneyEvents(userId: string): Promise<MoneyEvent[]>;
  saveMoneyEvent(
    userId: string,
    input: ConfirmedMoneyEventInput,
  ): Promise<MoneyEvent>;
  getLesson(userId: string, lessonId: string): Promise<Lesson | null>;
  getLatestLesson(userId: string): Promise<Lesson | null>;
  saveLesson(lesson: Lesson): Promise<Lesson>;
  getOrCreateInvestmentAccount(
    userId: string,
    startingCashMinor: number,
  ): Promise<VirtualInvestmentAccount>;
  listInvestmentOrders(userId: string): Promise<VirtualInvestmentOrder[]>;
  saveInvestmentOrder(
    userId: string,
    input: SaveInvestmentOrderInput,
  ): Promise<VirtualInvestmentOrder>;
  resetDemo(userId: string): Promise<void>;
}

export interface AuthRepository {
  findAccountByEmail(email: string): Promise<Account | null>;
  findAccountById(userId: string): Promise<Account | null>;
  createAccount(account: Account): Promise<Account>;
  setProfileComplete(userId: string): Promise<void>;
  createSession(session: SessionRecord): Promise<void>;
  findSessionByTokenHash(tokenHash: string): Promise<SessionRecord | null>;
  revokeSession(tokenHash: string): Promise<void>;
}
