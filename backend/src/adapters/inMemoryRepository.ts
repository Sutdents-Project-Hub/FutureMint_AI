import { randomUUID } from "node:crypto";

import type {
  Account,
  AccountActionToken,
  AiConsent,
  FamilyGroupRecord,
  FamilyMemberRecord,
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
  EditableMoneyEventInput,
  FutureMintRepository,
  RateLimitStore,
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
  implements FutureMintRepository, AuthRepository, RateLimitStore
{
  private profiles = new Map<string, UserProfile>();
  private events = new Map<string, MoneyEvent[]>();
  private lessons = new Map<string, Lesson[]>();
  private investmentAccounts = new Map<string, VirtualInvestmentAccount>();
  private investmentOrders = new Map<string, VirtualInvestmentOrder[]>();
  private accountsByEmail = new Map<string, Account>();
  private accountsById = new Map<string, Account>();
  private sessions = new Map<string, SessionRecord>();
  private aiConsents = new Map<string, AiConsent>();
  private familyGroups = new Map<string, FamilyGroupRecord>();
  private familyInviteHashes = new Map<string, string>();
  private familyMembers = new Map<string, FamilyMemberRecord>();
  private accountActionTokens = new Map<string, AccountActionToken>();
  private rateLimits = new Map<string, { current: number; expiresAt: number }>();
  private userLocks = new Map<string, Promise<void>>();

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

  private async withUserLock<T>(
    userId: string,
    operation: () => Promise<T>,
  ): Promise<T> {
    const previous = this.userLocks.get(userId) ?? Promise.resolve();
    let release: (() => void) | undefined;
    const current = previous.then(
      () =>
        new Promise<void>((resolve) => {
          release = resolve;
        }),
    );
    this.userLocks.set(userId, current);
    await previous;
    try {
      return await operation();
    } finally {
      release?.();
      if (this.userLocks.get(userId) === current) this.userLocks.delete(userId);
    }
  }

  async withUsersTransaction<T>(
    userIds: string[],
    operation: (repository: FutureMintRepository) => Promise<T>,
  ): Promise<T> {
    const ordered = [...new Set(userIds)].sort();
    const acquire = (index: number): Promise<T> =>
      index >= ordered.length
        ? operation(this)
        : this.withUserLock(ordered[index], () => acquire(index + 1));
    return acquire(0);
  }

  async getProfile(userId: string): Promise<UserProfile> {
    const profile = this.profiles.get(userId);
    if (!profile) {
      throw new DomainError("profile_not_found", "找不到使用者設定。", 404);
    }
    return { ...profile };
  }

  async saveProfile(profile: UserProfile): Promise<UserProfile> {
    const membership = this.familyMembers.get(profile.userId);
    if (membership && membership.role !== profile.accountRole) {
      throw new DomainError(
        "family_role_locked",
        "加入家庭後不能直接更換家長／孩子角色；請先離開家庭再修改。",
        409,
      );
    }
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

  async updateMoneyEvent(
    userId: string,
    eventId: string,
    input: EditableMoneyEventInput,
  ): Promise<MoneyEvent> {
    const events = this.events.get(userId) ?? [];
    const index = events.findIndex((event) => event.id === eventId);
    if (index < 0) {
      throw new DomainError("money_event_not_found", "找不到這筆紀錄。", 404);
    }
    const existing = events[index];
    const updated: MoneyEvent = {
      ...existing,
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
      updatedAt: new Date().toISOString(),
    };
    events[index] = updated;
    this.events.set(userId, events);
    return { ...updated };
  }

  async deleteMoneyEvent(userId: string, eventId: string): Promise<void> {
    const events = this.events.get(userId) ?? [];
    const index = events.findIndex((event) => event.id === eventId);
    if (index < 0) {
      throw new DomainError("money_event_not_found", "找不到這筆紀錄。", 404);
    }
    events.splice(index, 1);
    this.events.set(userId, events);
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

  async getFamilyMembership(
    userId: string,
  ): Promise<FamilyMemberRecord | null> {
    const member = this.familyMembers.get(userId);
    return member ? { ...member } : null;
  }

  async getFamilyGroup(familyId: string): Promise<FamilyGroupRecord | null> {
    const group = this.familyGroups.get(familyId);
    return group ? { ...group } : null;
  }

  async createFamilyGroup(
    userId: string,
    familyId: string,
    inviteCodeHash: string,
    inviteCodeExpiresAt: string,
  ): Promise<FamilyGroupRecord> {
    if ([...this.familyInviteHashes.values()].includes(inviteCodeHash)) {
      throw new DomainError(
        "family_invite_unavailable",
        "家庭邀請碼剛好重複，請再建立一次。",
        409,
        true,
      );
    }
    if (this.familyMembers.has(userId)) {
      throw new DomainError(
        "family_already_linked",
        "這個帳號已經加入家庭。",
        409,
      );
    }
    if (this.profiles.get(userId)?.accountRole !== "parent") {
      throw new DomainError(
        "family_parent_required",
        "只有家長帳號可以建立家庭邀請。",
        403,
      );
    }
    const group: FamilyGroupRecord = {
      familyId,
      createdBy: userId,
      inviteCodeExpiresAt,
      inviteActive: true,
    };
    this.familyGroups.set(familyId, group);
    this.familyInviteHashes.set(familyId, inviteCodeHash);
    this.familyMembers.set(userId, {
      familyId,
      userId,
      email: this.accountsById.get(userId)?.email ?? `${userId}@demo.local`,
      role: "parent",
      joinedAt: new Date().toISOString(),
    });
    return { ...group };
  }

  async rotateFamilyInvite(
    familyId: string,
    inviteCodeHash: string,
    inviteCodeExpiresAt: string,
  ): Promise<FamilyGroupRecord> {
    const group = this.familyGroups.get(familyId);
    if (!group) {
      throw new DomainError("family_not_found", "找不到家庭關聯。", 404);
    }
    const duplicate = [...this.familyInviteHashes.entries()].some(
      ([id, hash]) => id !== familyId && hash === inviteCodeHash,
    );
    if (duplicate) {
      throw new DomainError(
        "family_invite_unavailable",
        "家庭邀請碼剛好重複，請再建立一次。",
        409,
        true,
      );
    }
    const updated = {
      ...group,
      inviteCodeExpiresAt,
      inviteActive: true,
    };
    this.familyGroups.set(familyId, updated);
    this.familyInviteHashes.set(familyId, inviteCodeHash);
    return { ...updated };
  }

  async revokeFamilyInvite(familyId: string): Promise<FamilyGroupRecord> {
    const group = this.familyGroups.get(familyId);
    if (!group) {
      throw new DomainError("family_not_found", "找不到家庭關聯。", 404);
    }
    const updated: FamilyGroupRecord = {
      familyId: group.familyId,
      createdBy: group.createdBy,
      inviteActive: false,
    };
    this.familyGroups.set(familyId, updated);
    this.familyInviteHashes.delete(familyId);
    return { ...updated };
  }

  async findFamilyByInviteCodeHash(
    inviteCodeHash: string,
  ): Promise<FamilyGroupRecord | null> {
    const familyId = [...this.familyInviteHashes.entries()].find(
      ([, hash]) => hash === inviteCodeHash,
    )?.[0];
    const group = familyId ? this.familyGroups.get(familyId) : undefined;
    if (
      !group?.inviteActive ||
      !group.inviteCodeExpiresAt ||
      new Date(group.inviteCodeExpiresAt).getTime() <= Date.now()
    ) {
      return null;
    }
    return group ? { ...group } : null;
  }

  async listFamilyMembers(familyId: string): Promise<FamilyMemberRecord[]> {
    return [...this.familyMembers.values()]
      .filter((member) => member.familyId === familyId)
      .sort((a, b) => a.joinedAt.localeCompare(b.joinedAt))
      .map((member) => ({ ...member }));
  }

  async addFamilyMember(familyId: string, userId: string): Promise<void> {
    if (this.familyMembers.has(userId)) {
      throw new DomainError(
        "family_already_linked",
        "這個帳號已經加入家庭。",
        409,
      );
    }
    if (!this.familyGroups.has(familyId)) {
      throw new DomainError("family_invite_not_found", "找不到家庭邀請碼。", 404);
    }
    if (this.profiles.get(userId)?.accountRole !== "child") {
      throw new DomainError(
        "family_child_required",
        "只有孩子帳號可以使用家長邀請碼加入家庭。",
        403,
      );
    }
    if (
      ![...this.familyMembers.values()].some(
        (member) => member.familyId === familyId && member.role === "parent",
      )
    ) {
      throw new DomainError(
        "family_parent_missing",
        "這個家庭目前沒有可用的家長帳號。",
        409,
      );
    }
    this.familyMembers.set(userId, {
      familyId,
      userId,
      email: this.accountsById.get(userId)?.email ?? `${userId}@demo.local`,
      role: "child",
      joinedAt: new Date().toISOString(),
    });
  }

  async removeFamilyMember(userId: string): Promise<void> {
    this.familyMembers.delete(userId);
  }

  async deleteFamilyGroup(familyId: string): Promise<void> {
    this.familyGroups.delete(familyId);
    this.familyInviteHashes.delete(familyId);
    for (const [userId, member] of this.familyMembers) {
      if (member.familyId === familyId) this.familyMembers.delete(userId);
    }
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
    if (this.accountsByEmail.has(account.email)) {
      throw new DomainError(
        "account_unavailable",
        "此電子郵件無法完成註冊。",
        409,
      );
    }
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

  async createSession(session: SessionRecord, expectedPasswordHash?: string): Promise<void> {
    if (expectedPasswordHash && this.accountsById.get(session.userId)?.passwordHash !== expectedPasswordHash) {
      throw new DomainError("invalid_credentials", "電子郵件或密碼不正確。", 401);
    }
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

  async deleteExpiredOrRevokedSessions(
    cutoff: string,
    limit = 1000,
  ): Promise<number> {
    const cutoffMs = new Date(cutoff).getTime();
    let deleted = 0;
    for (const [tokenHash, session] of this.sessions) {
      if (deleted >= limit) break;
      if (
        new Date(session.expiresAt).getTime() <= cutoffMs ||
        (session.revokedAt && new Date(session.revokedAt).getTime() <= cutoffMs)
      ) {
        this.sessions.delete(tokenHash);
        deleted += 1;
      }
    }
    return deleted;
  }

  async saveAccountActionToken(record: AccountActionToken): Promise<void> {
    for (const [hash, token] of this.accountActionTokens) {
      if (token.userId === record.userId && token.purpose === record.purpose) {
        this.accountActionTokens.delete(hash);
      }
    }
    this.accountActionTokens.set(record.tokenHash, { ...record });
  }

  async consumeEmailVerification(tokenHash: string, now: string): Promise<boolean> {
    const token = this.accountActionTokens.get(tokenHash);
    if (
      !token ||
      token.purpose !== "verify-email" ||
      new Date(token.expiresAt).getTime() <= new Date(now).getTime()
    ) {
      return false;
    }
    const account = this.accountsById.get(token.userId);
    if (!account) return false;
    this.accountActionTokens.delete(tokenHash);
    const updated = { ...account, emailVerifiedAt: now };
    this.accountsById.set(updated.userId, updated);
    this.accountsByEmail.set(updated.email, updated);
    return true;
  }

  async consumePasswordReset(
    tokenHash: string,
    now: string,
    password: { passwordHash: string; passwordSalt: string },
  ): Promise<boolean> {
    const token = this.accountActionTokens.get(tokenHash);
    if (
      !token ||
      token.purpose !== "reset-password" ||
      new Date(token.expiresAt).getTime() <= new Date(now).getTime()
    ) {
      return false;
    }
    const account = this.accountsById.get(token.userId);
    if (!account) return false;
    this.accountActionTokens.delete(tokenHash);
    const updated = { ...account, ...password };
    this.accountsById.set(updated.userId, updated);
    this.accountsByEmail.set(updated.email, updated);
    for (const [hash, session] of this.sessions) {
      if (session.userId === updated.userId) {
        this.sessions.set(hash, { ...session, revokedAt: now });
      }
    }
    return true;
  }

  async deleteAccountActionToken(tokenHash: string): Promise<void> {
    this.accountActionTokens.delete(tokenHash);
  }

  async deleteExpiredAccountActionTokens(
    cutoff: string,
    limit = 1000,
  ): Promise<number> {
    const cutoffMs = new Date(cutoff).getTime();
    let deleted = 0;
    for (const [hash, token] of this.accountActionTokens) {
      if (deleted >= limit) break;
      if (new Date(token.expiresAt).getTime() <= cutoffMs) {
        this.accountActionTokens.delete(hash);
        deleted += 1;
      }
    }
    return deleted;
  }

  async consumeRateLimit(
    key: string,
    windowMs: number,
  ): Promise<{ current: number; ttl: number }> {
    const now = Date.now();
    const existing = this.rateLimits.get(key);
    const entry =
      existing && existing.expiresAt > now
        ? { current: existing.current + 1, expiresAt: existing.expiresAt }
        : { current: 1, expiresAt: now + windowMs };
    this.rateLimits.set(key, entry);
    return { current: entry.current, ttl: Math.max(0, entry.expiresAt - now) };
  }

  async clearRateLimit(key: string): Promise<void> {
    this.rateLimits.delete(key);
  }

  async deleteExpiredRateLimits(cutoff: string, limit = 1000): Promise<number> {
    const cutoffMs = new Date(cutoff).getTime();
    let deleted = 0;
    for (const [key, counter] of this.rateLimits) {
      if (deleted >= limit) break;
      if (counter.expiresAt <= cutoffMs) {
        this.rateLimits.delete(key);
        deleted += 1;
      }
    }
    return deleted;
  }

  async getAiConsent(userId: string): Promise<AiConsent | null> {
    const consent = this.aiConsents.get(userId);
    return consent ? { ...consent } : null;
  }

  async saveAiConsent(userId: string, consent: AiConsent): Promise<AiConsent> {
    const copy = { ...consent };
    this.aiConsents.set(userId, copy);
    return { ...copy };
  }

  async deleteAccount(userId: string, expectedPasswordHash?: string): Promise<void> {
    const membership = this.familyMembers.get(userId);
    const parentId = membership && this.familyGroups.get(membership.familyId)?.createdBy;
    return this.withUsersTransaction([userId, ...(parentId ? [parentId] : [])], () => this.deleteAccountLocked(userId, expectedPasswordHash));
  }

  private async deleteAccountLocked(userId: string, expectedPasswordHash?: string): Promise<void> {
    if (expectedPasswordHash && this.accountsById.get(userId)?.passwordHash !== expectedPasswordHash) {
      throw new DomainError("invalid_credentials", "電子郵件或密碼不正確。", 401);
    }
    const account = this.accountsById.get(userId);
    if (!account) return;

    const createdGroups = [...this.familyGroups.values()]
      .filter((group) => group.createdBy === userId)
      .map((group) => group.familyId);
    for (const familyId of createdGroups) {
      await this.deleteFamilyGroup(familyId);
    }
    this.familyMembers.delete(userId);
    this.profiles.delete(userId);
    this.events.delete(userId);
    this.lessons.delete(userId);
    this.investmentAccounts.delete(userId);
    this.investmentOrders.delete(userId);
    this.aiConsents.delete(userId);
    for (const [hash, token] of this.accountActionTokens) {
      if (token.userId === userId) this.accountActionTokens.delete(hash);
    }
    for (const [tokenHash, session] of this.sessions) {
      if (session.userId === userId) this.sessions.delete(tokenHash);
    }
    this.accountsById.delete(userId);
    this.accountsByEmail.delete(account.email);
  }
}
