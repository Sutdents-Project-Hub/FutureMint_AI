import { randomUUID } from "node:crypto";

import type {
  Account,
  Lesson,
  MoneyEvent,
  SaveInvestmentOrderInput,
  SessionRecord,
  UserProfile,
  VirtualInvestmentAccount,
  VirtualInvestmentOrder,
} from "../contracts/models";
import { DomainError } from "../contracts/errors";
import type {
  AuthRepository,
  ConfirmedMoneyEventInput,
  FutureMintRepository,
} from "../application/ports";

const profileSeed = (): UserProfile => ({
  userId: "demo-user",
  monthlyBudgetMinor: 6000,
  weeklyBudgetMinor: 1500,
  goalName: "校外活動基金",
  goalTargetMinor: 12000,
  goalSavedMinor: 4200,
  goalDate: "2026-10-31",
  preferredTone: "supportive",
  accountRole: "child",
});

const eventSeed = (): MoneyEvent[] => [
  {
    id: "seed-income",
    userId: "demo-user",
    type: "income",
    amountMinor: 1500,
    currency: "TWD",
    category: "income",
    merchant: "打工收入",
    occurredAt: "2026-07-05T18:00:00+08:00",
    createdAt: "2026-07-05T18:00:00+08:00",
    updatedAt: "2026-07-05T18:00:00+08:00",
  },
  {
    id: "seed-drink-one",
    userId: "demo-user",
    type: "expense",
    amountMinor: 75,
    currency: "TWD",
    category: "food",
    spendingIntent: "uncertain",
    intentReason: "餐飲支出需要依當時情境由使用者確認。",
    merchant: "珍奶",
    occurredAt: "2026-07-08T16:30:00+08:00",
    createdAt: "2026-07-08T16:30:00+08:00",
    updatedAt: "2026-07-08T16:30:00+08:00",
  },
  {
    id: "seed-game",
    userId: "demo-user",
    type: "expense",
    amountMinor: 450,
    currency: "TWD",
    category: "entertainment",
    spendingIntent: "want",
    intentReason: "娛樂支出較接近提升體驗的選擇。",
    merchant: "遊戲點數",
    occurredAt: "2026-07-09T20:10:00+08:00",
    createdAt: "2026-07-09T20:10:00+08:00",
    updatedAt: "2026-07-09T20:10:00+08:00",
  },
  {
    id: "seed-subscription",
    userId: "demo-user",
    type: "subscription",
    amountMinor: 390,
    currency: "TWD",
    category: "subscription",
    spendingIntent: "uncertain",
    intentReason: "訂閱是否必要要看使用頻率與替代方案。",
    merchant: "影音訂閱",
    occurredAt: "2026-07-01T08:00:00+08:00",
    recurrence: {
      billingCycle: "monthly",
      nextBillingAt: "2026-08-01T08:00:00+08:00",
    },
    split: { participants: 4, userShareMinor: 98 },
    createdAt: "2026-07-01T08:00:00+08:00",
    updatedAt: "2026-07-01T08:00:00+08:00",
  },
];

export class InMemoryRepository
  implements FutureMintRepository, AuthRepository
{
  private profiles = new Map<string, UserProfile>();
  private events = new Map<string, MoneyEvent[]>();
  private lessons = new Map<string, Lesson[]>();
  private investmentAccounts = new Map<string, VirtualInvestmentAccount>();
  private investmentOrders = new Map<string, VirtualInvestmentOrder[]>();
  private accountsByEmail = new Map<string, Account>();
  private accountsById = new Map<string, Account>();
  private sessions = new Map<string, SessionRecord>();

  constructor() {
    this.seed("demo-user");
  }

  private seed(userId: string): void {
    const profile = { ...profileSeed(), userId };
    const events = eventSeed().map((event) => ({ ...event, userId }));
    this.profiles.set(userId, profile);
    this.events.set(userId, events);
    this.lessons.set(userId, []);
    this.investmentAccounts.delete(userId);
    this.investmentOrders.set(userId, []);
  }

  async getProfile(userId: string): Promise<UserProfile> {
    const profile = this.profiles.get(userId);
    if (!profile) {
      throw new DomainError("profile_not_found", "找不到使用者設定。", 404);
    }
    return { ...profile };
  }

  async saveProfile(profile: UserProfile): Promise<UserProfile> {
    this.profiles.set(profile.userId, { ...profile });
    return { ...profile };
  }

  async listMoneyEvents(userId: string): Promise<MoneyEvent[]> {
    return [...(this.events.get(userId) ?? [])].map((event) => ({ ...event }));
  }

  async saveMoneyEvent(
    userId: string,
    input: ConfirmedMoneyEventInput,
  ): Promise<MoneyEvent> {
    const events = this.events.get(userId) ?? [];
    const existing = events.find(
      (event) => event.idempotencyKey === input.idempotencyKey,
    );
    if (existing) return { ...existing };

    const now = new Date().toISOString();
    const event: MoneyEvent = {
      id: randomUUID(),
      userId,
      type: input.type,
      amountMinor: input.amountMinor,
      currency: input.currency,
      category: input.category,
      merchant: input.merchant,
      occurredAt: input.occurredAt,
      recurrence: input.recurrence,
      split: input.split,
      spendingIntent: input.spendingIntent,
      intentReason: input.intentReason,
      idempotencyKey: input.idempotencyKey,
      createdAt: now,
      updatedAt: now,
    };
    events.push(event);
    this.events.set(userId, events);
    return { ...event };
  }

  async getLesson(userId: string, lessonId: string): Promise<Lesson | null> {
    return (
      this.lessons.get(userId)?.find((lesson) => lesson.id === lessonId) ?? null
    );
  }

  async getLatestLesson(userId: string): Promise<Lesson | null> {
    const lessons = this.lessons.get(userId) ?? [];
    return lessons.length === 0 ? null : { ...lessons[lessons.length - 1] };
  }

  async saveLesson(lesson: Lesson): Promise<Lesson> {
    const lessons = this.lessons.get(lesson.userId) ?? [];
    const index = lessons.findIndex((item) => item.id === lesson.id);
    if (index >= 0) lessons[index] = lesson;
    else lessons.push(lesson);
    this.lessons.set(lesson.userId, lessons);
    return { ...lesson };
  }

  async getOrCreateInvestmentAccount(
    userId: string,
    startingCashMinor: number,
  ): Promise<VirtualInvestmentAccount> {
    const existing = this.investmentAccounts.get(userId);
    if (existing) return { ...existing };
    const account: VirtualInvestmentAccount = {
      userId,
      startingCashMinor,
      createdAt: new Date().toISOString(),
    };
    this.investmentAccounts.set(userId, account);
    return { ...account };
  }

  async listInvestmentOrders(
    userId: string,
  ): Promise<VirtualInvestmentOrder[]> {
    return (this.investmentOrders.get(userId) ?? []).map((order) => ({
      ...order,
    }));
  }

  async saveInvestmentOrder(
    userId: string,
    input: SaveInvestmentOrderInput,
  ): Promise<VirtualInvestmentOrder> {
    const orders = this.investmentOrders.get(userId) ?? [];
    const existing = orders.find(
      (order) => order.idempotencyKey === input.idempotencyKey,
    );
    if (existing) return { ...existing };
    const order: VirtualInvestmentOrder = {
      id: randomUUID(),
      userId,
      ...input,
      createdAt: new Date().toISOString(),
    };
    orders.push(order);
    this.investmentOrders.set(userId, orders);
    return { ...order };
  }

  async resetDemo(userId: string): Promise<void> {
    this.seed(userId);
  }

  async findAccountByEmail(email: string): Promise<Account | null> {
    const account = this.accountsByEmail.get(email);
    return account ? { ...account } : null;
  }

  async findAccountById(userId: string): Promise<Account | null> {
    const account = this.accountsById.get(userId);
    return account ? { ...account } : null;
  }

  async createAccount(account: Account): Promise<Account> {
    const copy = { ...account };
    this.accountsByEmail.set(copy.email, copy);
    this.accountsById.set(copy.id, copy);
    return { ...copy };
  }

  async setProfileComplete(userId: string): Promise<void> {
    const account = this.accountsById.get(userId);
    if (!account) {
      throw new DomainError("account_not_found", "找不到登入帳號。", 404);
    }
    const updated = { ...account, profileComplete: true };
    this.accountsById.set(userId, updated);
    this.accountsByEmail.set(updated.email, updated);
  }

  async createSession(session: SessionRecord): Promise<void> {
    this.sessions.set(session.tokenHash, { ...session });
  }

  async findSessionByTokenHash(
    tokenHash: string,
  ): Promise<SessionRecord | null> {
    const session = this.sessions.get(tokenHash);
    return session ? { ...session } : null;
  }

  async revokeSession(tokenHash: string): Promise<void> {
    const session = this.sessions.get(tokenHash);
    if (!session) return;
    this.sessions.set(tokenHash, {
      ...session,
      revokedAt: new Date().toISOString(),
    });
  }
}
