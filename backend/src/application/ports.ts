import type {
  Account,
  AccountActionToken,
  AiConsent,
  CoachReply,
  CoachRequest,
  CaptureParseResult,
  FamilyGroupRecord,
  FamilyMemberRecord,
  FinancialInsights,
  MarketSnapshot,
  Lesson,
  LearningPlan,
  MoneyEvent,
  MoneyEventPage,
  MoneyEventPageQuery,
  Subscription,
  SubscriptionInput,
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
  subscriptionId?: string;
  recurrence?: MoneyEvent["recurrence"];
  split?: MoneyEvent["split"];
  spendingIntent?: MoneyEvent["spendingIntent"];
  intentReason?: MoneyEvent["intentReason"];
  source?: MoneyEvent["source"];
  confirmed: true;
  idempotencyKey: string;
}

export interface SubscriptionCreateRecordInput extends SubscriptionInput {
  idempotencyKey: string;
  requestFingerprint: string;
}

export type EditableMoneyEventInput = Omit<
  ConfirmedMoneyEventInput,
  "idempotencyKey"
>;

export interface FutureMintRepository {
  withUsersTransaction<T>(
    userIds: string[],
    operation: (repository: FutureMintRepository) => Promise<T>,
  ): Promise<T>;
  getProfile(userId: string): Promise<UserProfile>;
  saveProfile(profile: UserProfile): Promise<UserProfile>;
  listMoneyEvents(userId: string): Promise<MoneyEvent[]>;
  listMoneyEventsPage(userId: string, query: MoneyEventPageQuery): Promise<MoneyEventPage>;
  listSubscriptions(userId: string): Promise<Subscription[]>;
  getSubscription(userId: string, subscriptionId: string): Promise<Subscription | null>;
  createSubscription(userId: string, input: SubscriptionCreateRecordInput): Promise<Subscription>;
  updateSubscription(userId: string, subscriptionId: string, input: SubscriptionInput): Promise<Subscription>;
  deactivateSubscription(userId: string, subscriptionId: string): Promise<Subscription>;
  saveMoneyEvent(
    userId: string,
    input: ConfirmedMoneyEventInput,
  ): Promise<MoneyEvent>;
  updateMoneyEvent(
    userId: string,
    eventId: string,
    input: EditableMoneyEventInput,
  ): Promise<MoneyEvent>;
  deleteMoneyEvent(userId: string, eventId: string): Promise<void>;
  listLessons(userId: string): Promise<Lesson[]>;
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
  getFamilyMembership(userId: string): Promise<FamilyMemberRecord | null>;
  getFamilyGroup(familyId: string): Promise<FamilyGroupRecord | null>;
  createFamilyGroup(
    userId: string,
    familyId: string,
    inviteCodeHash: string,
    inviteCodeExpiresAt: string,
  ): Promise<FamilyGroupRecord>;
  rotateFamilyInvite(
    familyId: string,
    inviteCodeHash: string,
    inviteCodeExpiresAt: string,
  ): Promise<FamilyGroupRecord>;
  revokeFamilyInvite(familyId: string): Promise<FamilyGroupRecord>;
  findFamilyByInviteCodeHash(
    inviteCodeHash: string,
  ): Promise<FamilyGroupRecord | null>;
  listFamilyMembers(familyId: string): Promise<FamilyMemberRecord[]>;
  addFamilyMember(familyId: string, userId: string): Promise<void>;
  removeFamilyMember(userId: string): Promise<void>;
  deleteFamilyGroup(familyId: string): Promise<void>;
}

export interface AuthRepository {
  findAccountByEmail(email: string): Promise<Account | null>;
  findAccountById(userId: string): Promise<Account | null>;
  createAccount(account: Account): Promise<Account>;
  setProfileComplete(userId: string): Promise<void>;
  createSession(session: SessionRecord, expectedPasswordHash?: string): Promise<void>;
  findSessionByTokenHash(tokenHash: string): Promise<SessionRecord | null>;
  revokeSession(tokenHash: string): Promise<void>;
  deleteExpiredOrRevokedSessions(cutoff: string, limit?: number): Promise<number>;
  saveAccountActionToken(record: AccountActionToken): Promise<void>;
  consumeEmailVerification(tokenHash: string, now: string): Promise<boolean>;
  consumePasswordReset(
    tokenHash: string,
    now: string,
    password: { passwordHash: string; passwordSalt: string },
  ): Promise<boolean>;
  deleteAccountActionToken(tokenHash: string): Promise<void>;
  deleteExpiredAccountActionTokens(
    cutoff: string,
    limit?: number,
  ): Promise<number>;
  getAiConsent(userId: string): Promise<AiConsent | null>;
  saveAiConsent(userId: string, consent: AiConsent): Promise<AiConsent>;
  deleteAccount(userId: string, expectedPasswordHash?: string): Promise<void>;
}

export interface RateLimitStore {
  consumeRateLimit(
    key: string,
    windowMs: number,
  ): Promise<{ current: number; ttl: number }>;
  clearRateLimit(key: string): Promise<void>;
  deleteExpiredRateLimits(cutoff: string, limit?: number): Promise<number>;
}
