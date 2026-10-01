import { createHash, randomBytes, randomUUID } from "node:crypto";

import type {
  AiProvider,
  CaptureInput,
  ConfirmedMoneyEventInput,
  EditableMoneyEventInput,
  FutureMintRepository,
  MarketDataProvider,
} from "./ports";
import type {
  CoachRequest,
  DashboardSummary,
  FinancialInsights,
  FutureSeedInput,
  FamilyOverview,
  InvestmentSimulationInput,
  InvestmentOrderInput,
  Lesson,
  MoneyEvent,
  MoneyEventPageQuery,
  SubscriptionInput,
  SubscriptionCompareInput,
  SubscriptionComparison,
  SubscriptionPlan,
  UserProfile,
} from "../contracts/models";
import {
  captureParseInputSchema,
  coachRequestSchema,
  futureSeedInputSchema,
  investmentSimulationInputSchema,
  investmentOrderInputSchema,
  moneyEventInputSchema,
  moneyEventUpdateSchema,
  moneyEventListQuerySchema,
  profileInputSchema,
  practiceDiceInputSchema,
  familyJoinInputSchema,
  subscriptionCompareInputSchema,
  subscriptionInputSchema,
  subscriptionCreateInputSchema,
  moneyEventPageQuerySchema,
} from "../contracts/schemas";
import { calculateDashboard } from "../domain/budget";
import { calculateFinancialInsights } from "../domain/analytics";
import { calculateFutureSeed } from "../domain/futureSeed";
import { simulateInvestmentScenarios } from "../domain/investmentSimulation";
import {
  buildInvestmentLab,
  rollPracticeEvent,
  validateInvestmentOrder,
} from "../domain/investmentLab";
import { compareSubscription } from "../domain/subscriptions";
import { monthlySubscriptionCommitment, withNextBillingDate } from "../domain/subscriptionSchedule";
import { assertSameOrderRequest, moneyRequestFingerprint } from "../domain/idempotency";
import { DomainError } from "../contracts/errors";

export class FutureMintService {
  constructor(
    private readonly repository: FutureMintRepository,
    private readonly aiProvider: AiProvider,
    private readonly subscriptionCatalog: SubscriptionPlan[],
    private readonly marketDataProvider: MarketDataProvider,
  ) {}

  private recentEvents(events: MoneyEvent[]): MoneyEvent[] {
    return [...events]
      .sort(
        (a, b) =>
          new Date(a.occurredAt).getTime() - new Date(b.occurredAt).getTime(),
      )
      .slice(-5);
  }

  getProfile(userId: string): Promise<UserProfile> {
    return this.repository.getProfile(userId);
  }

  async updateProfile(
    userId: string,
    input: Omit<UserProfile, "userId">,
  ): Promise<UserProfile> {
    const parsed = profileInputSchema.parse(input);
    return this.repository.withUsersTransaction([userId], async (repository) => {
      const membership = await repository.getFamilyMembership(userId);
      if (membership && membership.role !== parsed.accountRole) {
        throw new DomainError(
          "family_role_locked",
          "加入家庭後不能直接更換家長／孩子角色；請先離開家庭再修改。",
          409,
        );
      }
      return repository.saveProfile({ userId, ...parsed });
    });
  }

  async parseCapture(userId: string, input: CaptureInput) {
    void userId;
    const parsed = captureParseInputSchema.parse(input);
    return this.aiProvider.parseCapture(parsed);
  }

  async saveMoneyEvent(
    userId: string,
    input: ConfirmedMoneyEventInput,
  ): Promise<MoneyEvent> {
    const parsed = moneyEventInputSchema.parse(input);
    return this.repository.withUsersTransaction([userId], (repository) => repository.saveMoneyEvent(userId,this.normalizedMoneyEventInput(parsed)));
  }

  async updateMoneyEvent(
    userId: string,
    eventId: string,
    input: EditableMoneyEventInput,
  ): Promise<MoneyEvent> {
    const parsed = moneyEventUpdateSchema.parse(input);
    return this.repository.withUsersTransaction([userId], (repository)=>repository.updateMoneyEvent(userId,eventId,this.normalizedMoneyEventInput(parsed)));
  }

  async deleteMoneyEvent(userId: string, eventId: string): Promise<void> {
    await this.repository.deleteMoneyEvent(userId, eventId);
  }

  private normalizedMoneyEventInput<T extends EditableMoneyEventInput>(
    input: T,
  ): T {
    return {
      ...input,
      ...(input.split
        ? {
            split: {
              participants: input.split.participants,
              userShareMinor: Math.round(
                input.amountMinor / input.split.participants,
              ),
            },
          }
        : {}),
    };
  }

  async listMoneyEvents(
    userId: string,
    filters: { type?: string; from?: string; to?: string } = {},
  ): Promise<MoneyEvent[]> {
    const parsed = moneyEventListQuerySchema.parse(filters);
    const events = await this.repository.listMoneyEvents(userId);
    return events
      .filter(
        (event) =>
          (!parsed.type || event.type === parsed.type) &&
          (!parsed.from || new Date(event.occurredAt) >= new Date(parsed.from)) &&
          (!parsed.to || new Date(event.occurredAt) <= new Date(parsed.to)),
      )
      .sort(
        (a, b) =>
          new Date(b.occurredAt).getTime() - new Date(a.occurredAt).getTime(),
      );
  }

  async listMoneyEventsPage(userId: string, query: MoneyEventPageQuery = {}) {
    return this.repository.listMoneyEventsPage(userId,moneyEventPageQuerySchema.parse(query));
  }

  async getSubscriptions(userId: string, now = new Date()) {
    const [events, subscriptions] = await Promise.all([this.repository.listMoneyEvents(userId),this.repository.listSubscriptions(userId)]);
    const items=subscriptions.map((item)=>withNextBillingDate(item,now));
    return {
      subscriptions: events.filter((event) => event.type === "subscription"),
      items,
      monthlyCommitmentMinor: monthlySubscriptionCommitment(items),
      legacyCandidates: events.filter((event)=>event.type === "subscription" && event.recurrence && !event.subscriptionId),
      catalog: this.subscriptionCatalog.map((plan) => ({ ...plan })),
      disclaimer: "方案價格與資格為合成展示資料，並非即時市場資訊。",
    };
  }

  async createSubscription(userId: string, input: SubscriptionInput & {idempotencyKey:string;legacyPaymentId?:string;initialPayment?: ConfirmedMoneyEventInput}) {
    const {initialPayment,legacyPaymentId,...parsed}=subscriptionCreateInputSchema.parse(input);
    if (initialPayment && (initialPayment.type !== "subscription" || initialPayment.subscriptionId)) throw new DomainError("invalid_subscription_payment","首次付款須為尚未連結的訂閱付款。",422);
    return this.repository.withUsersTransaction([userId],async(repository)=>{
      const normalizedPayment=initialPayment ? this.normalizedMoneyEventInput(initialPayment) : undefined;
      const requestFingerprint=createHash("sha256").update(JSON.stringify([parsed.name,parsed.amountMinor,parsed.currency,parsed.billingCycle,parsed.anchorDate,legacyPaymentId ?? null,normalizedPayment ? [normalizedPayment.idempotencyKey,moneyRequestFingerprint(normalizedPayment)] : null])).digest("hex");
      const subscription=await repository.createSubscription(userId,{...parsed,requestFingerprint});
      if(legacyPaymentId) {
        const payment=(await repository.listMoneyEvents(userId)).find((item)=>item.id===legacyPaymentId);
        if(!payment || payment.type!=="subscription" || !payment.recurrence || (payment.subscriptionId && payment.subscriptionId!==subscription.id)) throw new DomainError("invalid_legacy_subscription","這筆舊付款無法採用為此訂閱。",409);
        if(!payment.subscriptionId) await repository.updateMoneyEvent(userId,payment.id,{...payment,subscriptionId:subscription.id,confirmed:true});
      }
      if (initialPayment) await repository.saveMoneyEvent(userId,this.normalizedMoneyEventInput({...initialPayment,subscriptionId:subscription.id}));
      return subscription;
    });
  }

  async updateSubscription(userId:string,subscriptionId:string,input:SubscriptionInput) {
    const parsed=subscriptionInputSchema.parse(input);
    return this.repository.withUsersTransaction([userId],(repository)=>repository.updateSubscription(userId,subscriptionId,parsed));
  }

  async deactivateSubscription(userId:string,subscriptionId:string) {
    return this.repository.withUsersTransaction([userId],(repository)=>repository.deactivateSubscription(userId,subscriptionId));
  }

  async exportUserData(userId: string) {
    return this.repository.withUsersTransaction([userId],async(repository)=>{
      const [profile,moneyEvents,subscriptions,investmentOrders,familyMembership,lessons] = await Promise.all([
        repository.getProfile(userId).catch((error: unknown) => { if (error instanceof DomainError && error.code === "profile_not_found") return null; throw error; }),repository.listMoneyEvents(userId),repository.listSubscriptions(userId),repository.listInvestmentOrders(userId),repository.getFamilyMembership(userId),repository.listLessons(userId),
      ]);
      return {profile,moneyEvents,subscriptions,lessons,investmentOrders,familyMembership:familyMembership ? {familyId:familyMembership.familyId,role:familyMembership.role,joinedAt:familyMembership.joinedAt} : null};
    });
  }

  async getDashboard(
    userId: string,
    now = new Date(),
  ): Promise<DashboardSummary> {
    const [profile, events, subscriptions] = await Promise.all([this.repository.getProfile(userId),this.repository.listMoneyEvents(userId),this.repository.listSubscriptions(userId)]);
    return {...calculateDashboard(profile, events, now),monthlyCommitmentMinor:monthlySubscriptionCommitment(subscriptions)};
  }

  async getInsights(
    userId: string,
    now = new Date(),
  ): Promise<FinancialInsights> {
    const [profile, events, subscriptions] = await Promise.all([this.repository.getProfile(userId),this.repository.listMoneyEvents(userId),this.repository.listSubscriptions(userId)]);
    return calculateFinancialInsights(profile, events, now, subscriptions);
  }

  compareSubscriptions(
    input: SubscriptionCompareInput,
  ): SubscriptionComparison {
    return compareSubscription(
      subscriptionCompareInputSchema.parse(input),
      this.subscriptionCatalog,
    );
  }

  async generateLesson(userId: string): Promise<Lesson> {
    const [profile, events] = await Promise.all([
      this.repository.getProfile(userId),
      this.repository.listMoneyEvents(userId),
    ]);
    const recentEvents = this.recentEvents(events);
    const lesson = await this.aiProvider.generateLesson({
      userId,
      profile,
      events: recentEvents,
    });
    return this.repository.saveLesson(lesson);
  }

  async getLearningPlan(userId: string) {
    const [profile, events, subscriptions] = await Promise.all([
      this.repository.getProfile(userId),
      this.repository.listMoneyEvents(userId),
      this.repository.listSubscriptions(userId),
    ]);
    const insights = calculateFinancialInsights(profile, events, new Date(), subscriptions);
    return this.aiProvider.generateLearningPlan({
      userId,
      profile,
      events: this.recentEvents(events),
      insights,
    });
  }

  async getCurrentLesson(userId: string): Promise<Lesson> {
    const [lesson, events] = await Promise.all([
      this.repository.getLatestLesson(userId),
      this.repository.listMoneyEvents(userId),
    ]);
    if (!lesson) {
      throw new DomainError("lesson_not_found", "目前還沒有微課。", 404);
    }
    const currentSourceIds = this.recentEvents(events).map((event) => event.id);
    const sourceContentChanged = events
      .filter((event) => lesson.sourceEventIds.includes(event.id))
      .some(
        (event) =>
          new Date(event.updatedAt).getTime() >
          new Date(lesson.createdAt).getTime(),
      );
    if (
      currentSourceIds.length !== lesson.sourceEventIds.length ||
      currentSourceIds.some(
        (eventId, index) => lesson.sourceEventIds[index] !== eventId,
      ) ||
      sourceContentChanged
    ) {
      throw new DomainError(
        "lesson_not_found",
        "有新紀錄可用於產生更適合的微課。",
        404,
      );
    }
    return lesson;
  }

  async completeLesson(
    userId: string,
    lessonId: string,
    selectedOption: string,
  ): Promise<Lesson> {
    const lesson = await this.repository.getLesson(userId, lessonId);
    if (!lesson) {
      throw new DomainError("lesson_not_found", "找不到這堂微課。", 404);
    }
    if (!lesson.options.includes(selectedOption)) {
      throw new DomainError(
        "invalid_lesson_option",
        "請從課程提供的選項中選擇。",
        422,
        false,
        { selectedOption: "選擇的內容不在課程選項內。" },
      );
    }
    return this.repository.saveLesson({
      ...lesson,
      selectedOption,
      completedAt: new Date().toISOString(),
    });
  }

  previewFutureSeed(input: FutureSeedInput) {
    return calculateFutureSeed(futureSeedInputSchema.parse(input));
  }

  simulateInvestments(input: InvestmentSimulationInput) {
    return simulateInvestmentScenarios(
      investmentSimulationInputSchema.parse(input),
    );
  }

  coach(input: CoachRequest) {
    return this.aiProvider.coach(coachRequestSchema.parse(input));
  }

  private familyLabel(role: "child" | "parent", index: number): string {
    return role === "parent" ? "家長帳號" : `孩子帳號 ${index + 1}`;
  }

  async getFamilyOverview(userId: string): Promise<FamilyOverview | null> {
    const initial = await this.repository.getFamilyMembership(userId);
    if (!initial) return null;
    const members = await this.repository.listFamilyMembers(initial.familyId);
    return this.repository.withUsersTransaction([userId, ...members.map((member) => member.userId)], async (repository) => {
      const current = await repository.getFamilyMembership(userId);
      if (!current) return null;
      if (current.familyId !== initial.familyId) {
        throw new DomainError("family_changed", "家庭關聯已更新，請重新載入。", 409, true);
      }
      return this.getFamilyOverviewFromRepository(userId, repository);
    });
  }

  private async getFamilyOverviewFromRepository(
    userId: string,
    repository: FutureMintRepository,
  ): Promise<FamilyOverview | null> {
    const membership = await repository.getFamilyMembership(userId);
    if (!membership) return null;
    const [group, records] = await Promise.all([
      repository.getFamilyGroup(membership.familyId),
      repository.listFamilyMembers(membership.familyId),
    ]);
    if (!group) {
      throw new DomainError(
        "family_not_found",
        "家庭關聯已失效，請重新加入家庭。",
        409,
      );
    }

    let childIndex = 0;
    const members = records.map((record) => {
      const label = this.familyLabel(record.role, childIndex);
      if (record.role === "child") childIndex += 1;
      return {
        userId: record.userId,
        role: record.role,
        label: record.userId === userId ? `${label}（你）` : label,
        isSelf: record.userId === userId,
      };
    });
    const children = records.filter(
      (record) => record.role === "child" && record.userId !== userId,
    );
    const scopedService = new FutureMintService(repository, this.aiProvider, this.subscriptionCatalog, this.marketDataProvider);
    const childSummaries =
      membership.role === "parent"
        ? await Promise.all(
            children.map(async (child, index) => {
              const [dashboard, insights] = await Promise.all([
                scopedService.getDashboard(child.userId),
                scopedService.getInsights(child.userId),
              ]);
              return {
                userId: child.userId,
                label: `孩子帳號 ${index + 1}`,
                monthlyBudgetMinor: dashboard.monthlyBudgetMinor,
                incomeMinor: dashboard.incomeMinor,
                expenseMinor: dashboard.expenseMinor,
                subscriptionMinor: dashboard.subscriptionMinor,
                monthlyCommitmentMinor: dashboard.monthlyCommitmentMinor,
                availableMinor: dashboard.availableMinor,
                goalProgress: dashboard.goalProgress,
                summary: insights.summary,
                noticeCount: insights.notices.length,
              };
            }),
          )
        : [];

    return {
      familyId: membership.familyId,
      inviteActive: membership.role === "parent" && group.inviteActive &&
        Boolean(group.inviteCodeExpiresAt && new Date(group.inviteCodeExpiresAt).getTime() > Date.now()),
      ...(membership.role === "parent" && group.inviteCodeExpiresAt
        ? { inviteCodeExpiresAt: group.inviteCodeExpiresAt }
        : {}),
      members,
      childSummaries,
    };
  }

  async createFamilyInvite(userId: string): Promise<FamilyOverview> {
    const inviteCode = randomBytes(18).toString("base64url");
    const inviteCodeHash = createHash("sha256").update(inviteCode).digest("hex");
    const inviteCodeExpiresAt = new Date(
      Date.now() + 24 * 60 * 60 * 1000,
    ).toISOString();
    await this.repository.withUsersTransaction([userId], async (repository) => {
      const profile = await repository.getProfile(userId);
      if (profile.accountRole !== "parent") {
        throw new DomainError(
          "family_parent_required",
          "只有家長帳號可以建立家庭邀請。",
          403,
        );
      }
      const existing = await repository.getFamilyMembership(userId);
      if (!existing) {
        await repository.createFamilyGroup(
          userId,
          randomUUID(),
          inviteCodeHash,
          inviteCodeExpiresAt,
        );
        return;
      }
      if (existing.role !== "parent") {
        throw new DomainError(
          "family_parent_required",
          "只有家長帳號可以建立家庭邀請。",
          403,
        );
      }
      await repository.rotateFamilyInvite(
        existing.familyId,
        inviteCodeHash,
        inviteCodeExpiresAt,
      );
    });
    const overview = await this.getFamilyOverview(userId);
    if (!overview) {
      throw new DomainError(
        "family_not_ready",
        "家庭邀請尚未準備完成，請稍後再試。",
        503,
        true,
      );
    }
    return { ...overview, inviteCode, inviteCodeExpiresAt, inviteActive: true };
  }

  rotateFamilyInvite(userId: string): Promise<FamilyOverview> {
    return this.createFamilyInvite(userId);
  }

  async revokeFamilyInvite(userId: string): Promise<FamilyOverview> {
    await this.repository.withUsersTransaction([userId], async (repository) => {
      const membership = await repository.getFamilyMembership(userId);
      if (!membership || membership.role !== "parent") {
        throw new DomainError(
          "family_parent_required",
          "只有家長帳號可以撤銷家庭邀請。",
          403,
        );
      }
      await repository.revokeFamilyInvite(membership.familyId);
    });
    const overview = await this.getFamilyOverview(userId);
    if (!overview) {
      throw new DomainError("family_not_found", "找不到家庭關聯。", 404);
    }
    return overview;
  }

  async joinFamily(
    userId: string,
    input: { inviteCode: string },
  ): Promise<FamilyOverview> {
    const parsed = familyJoinInputSchema.parse(input);
    const inviteCodeHash = createHash("sha256")
      .update(parsed.inviteCode)
      .digest("hex");
    const group = await this.repository.findFamilyByInviteCodeHash(inviteCodeHash);
    if (!group) {
      throw new DomainError("family_invite_not_found", "找不到家庭邀請碼。", 404);
    }
    await this.repository.withUsersTransaction(
      [userId, group.createdBy],
      async (repository) => {
        const [profile, existing, currentGroup] = await Promise.all([
          repository.getProfile(userId),
          repository.getFamilyMembership(userId),
          repository.findFamilyByInviteCodeHash(inviteCodeHash),
        ]);
        if (profile.accountRole !== "child") {
          throw new DomainError(
            "family_child_required",
            "只有孩子帳號可以使用家長邀請碼加入家庭。",
            403,
          );
        }
        if (existing) {
          throw new DomainError(
            "family_already_linked",
            "這個孩子帳號已經加入家庭。",
            409,
          );
        }
        if (!currentGroup || currentGroup.familyId !== group.familyId) {
          throw new DomainError(
            "family_invite_not_found",
            "找不到家庭邀請碼。",
            404,
          );
        }
        const members = await repository.listFamilyMembers(group.familyId);
        if (!members.some((member) => member.role === "parent")) {
          throw new DomainError(
            "family_parent_missing",
            "這個家庭目前沒有可用的家長帳號。",
            409,
          );
        }
        await repository.addFamilyMember(group.familyId, userId);
      },
    );
    const overview = await this.getFamilyOverview(userId);
    if (!overview) {
      throw new DomainError(
        "family_not_ready",
        "加入家庭後無法載入關聯資料，請稍後再試。",
        503,
        true,
      );
    }
    return overview;
  }

  async leaveFamily(userId: string): Promise<void> {
    const membership = await this.repository.getFamilyMembership(userId);
    if (!membership) return;
    const members = await this.repository.listFamilyMembers(membership.familyId);
    await this.repository.withUsersTransaction(
      [userId,...members.map((member) => member.userId)],
      async (repository) => {
        const currentMembership = await repository.getFamilyMembership(userId);
        if (!currentMembership || currentMembership.familyId !== membership.familyId) throw new DomainError("family_changed","家庭關聯已更新，請重新載入。",409,true);
        const currentMembers = await repository.listFamilyMembers(
          currentMembership.familyId,
        );
        if (currentMembership.role === "parent" && currentMembers.length > 1) {
          throw new DomainError(
            "family_parent_has_children",
            "家長帳號仍有孩子關聯，請先由孩子離開家庭或重新安排關聯。",
            409,
          );
        }
        await repository.removeFamilyMember(userId);
        if (currentMembers.length <= 1) {
          await repository.deleteFamilyGroup(currentMembership.familyId);
        }
      },
    );
  }

  getMarketSnapshot() {
    return this.marketDataProvider.getSnapshot();
  }

  async getInvestmentLab(userId: string) {
    const [profile, market] = await Promise.all([
      this.repository.getProfile(userId),
      this.marketDataProvider.getSnapshot(),
    ]);
    const account = await this.repository.getOrCreateInvestmentAccount(
      userId,
      profile.goalSavedMinor > 0 ? profile.goalSavedMinor : 1000,
    );
    const orders = await this.repository.listInvestmentOrders(userId);
    return buildInvestmentLab(account, orders, market);
  }

  async placeInvestmentOrder(userId: string, input: InvestmentOrderInput) {
    const parsed = investmentOrderInputSchema.parse(input);
    const market = await this.marketDataProvider.getSnapshot();
    return this.repository.withUsersTransaction([userId], async (repository) => {
      const profile = await repository.getProfile(userId);
      const account = await repository.getOrCreateInvestmentAccount(
        userId,
        profile.goalSavedMinor > 0 ? profile.goalSavedMinor : 1000,
      );
      const existingOrders = await repository.listInvestmentOrders(userId);
      const existingOrder=existingOrders.find((order)=>order.idempotencyKey === parsed.idempotencyKey);
      if (existingOrder) {
        assertSameOrderRequest(existingOrder,parsed);
        return buildInvestmentLab(account,existingOrders,market);
      }
      const quote = market.quotes.find(
        (candidate) => candidate.symbol === parsed.symbol,
      );
      if (!quote) {
        throw new DomainError(
          "market_quote_not_found",
          "目前找不到這個教學標的的盤後價格。",
          404,
        );
      }
      const totalMinor = Math.round(quote.price * parsed.quantity);
      const current = buildInvestmentLab(account, existingOrders, market);
      validateInvestmentOrder(
        current,
        parsed.symbol,
        parsed.side,
        parsed.quantity,
        totalMinor,
      );
      await repository.saveInvestmentOrder(userId, {
        ...parsed,
        name: quote.name,
        unitPrice: quote.price,
        totalMinor,
        quoteAsOf: quote.asOf,
        quoteSource: quote.source,
      });
      return buildInvestmentLab(
        account,
        await repository.listInvestmentOrders(userId),
        market,
      );
    });
  }

  rollInvestmentPracticeEvent(userId: string, input: { rollIndex: number }) {
    const parsed = practiceDiceInputSchema.parse(input);
    return rollPracticeEvent(userId, parsed.rollIndex);
  }

  resetDemo(userId: string): Promise<void> {
    return this.repository.resetDemo(userId);
  }
}
