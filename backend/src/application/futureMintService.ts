import { randomBytes, randomUUID } from "node:crypto";

import type {
  AiProvider,
  CaptureInput,
  ConfirmedMoneyEventInput,
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
  moneyEventListQuerySchema,
  profileInputSchema,
  practiceDiceInputSchema,
  familyJoinInputSchema,
  subscriptionCompareInputSchema,
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
import { DomainError } from "../contracts/errors";

export class FutureMintService {
  private readonly investmentOrderLocks = new Map<string, Promise<void>>();

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

  private async withInvestmentOrderLock<T>(
    userId: string,
    operation: () => Promise<T>,
  ): Promise<T> {
    const previous = this.investmentOrderLocks.get(userId) ?? Promise.resolve();
    let release: (() => void) | undefined;
    const current = previous.then(
      () =>
        new Promise<void>((resolve) => {
          release = resolve;
        }),
    );
    this.investmentOrderLocks.set(userId, current);
    await previous;
    try {
      return await operation();
    } finally {
      release?.();
      if (this.investmentOrderLocks.get(userId) === current) {
        this.investmentOrderLocks.delete(userId);
      }
    }
  }

  getProfile(userId: string): Promise<UserProfile> {
    return this.repository.getProfile(userId);
  }

  async updateProfile(
    userId: string,
    input: Omit<UserProfile, "userId">,
  ): Promise<UserProfile> {
    const parsed = profileInputSchema.parse(input);
    const membership = await this.repository.getFamilyMembership(userId);
    if (membership && membership.role !== parsed.accountRole) {
      throw new DomainError(
        "family_role_locked",
        "加入家庭後不能直接更換家長／孩子角色；請先離開家庭再修改。",
        409,
      );
    }
    return this.repository.saveProfile({ userId, ...parsed });
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
    return this.repository.saveMoneyEvent(userId, {
      ...parsed,
      ...(parsed.split
        ? {
            split: {
              participants: parsed.split.participants,
              userShareMinor: Math.round(
                parsed.amountMinor / parsed.split.participants,
              ),
            },
          }
        : {}),
    });
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

  async getSubscriptions(userId: string) {
    const events = await this.repository.listMoneyEvents(userId);
    return {
      subscriptions: events.filter((event) => event.type === "subscription"),
      catalog: this.subscriptionCatalog.map((plan) => ({ ...plan })),
      disclaimer: "方案價格與資格為合成展示資料，並非即時市場資訊。",
    };
  }

  async getDashboard(
    userId: string,
    now = new Date(),
  ): Promise<DashboardSummary> {
    const [profile, events] = await Promise.all([
      this.repository.getProfile(userId),
      this.repository.listMoneyEvents(userId),
    ]);
    return calculateDashboard(profile, events, now);
  }

  async getInsights(
    userId: string,
    now = new Date(),
  ): Promise<FinancialInsights> {
    const [profile, events] = await Promise.all([
      this.repository.getProfile(userId),
      this.repository.listMoneyEvents(userId),
    ]);
    return calculateFinancialInsights(profile, events, now);
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
    const [profile, events] = await Promise.all([
      this.repository.getProfile(userId),
      this.repository.listMoneyEvents(userId),
    ]);
    const insights = calculateFinancialInsights(profile, events);
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
    if (
      currentSourceIds.length !== lesson.sourceEventIds.length ||
      currentSourceIds.some(
        (eventId, index) => lesson.sourceEventIds[index] !== eventId,
      )
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
    const membership = await this.repository.getFamilyMembership(userId);
    if (!membership) return null;
    const [group, records] = await Promise.all([
      this.repository.getFamilyGroup(membership.familyId),
      this.repository.listFamilyMembers(membership.familyId),
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
    const childSummaries =
      membership.role === "parent"
        ? await Promise.all(
            children.map(async (child, index) => {
              const [dashboard, insights] = await Promise.all([
                this.getDashboard(child.userId),
                this.getInsights(child.userId),
              ]);
              return {
                userId: child.userId,
                label: `孩子帳號 ${index + 1}`,
                monthlyBudgetMinor: dashboard.monthlyBudgetMinor,
                incomeMinor: dashboard.incomeMinor,
                expenseMinor: dashboard.expenseMinor,
                subscriptionMinor: dashboard.subscriptionMinor,
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
      ...(membership.role === "parent" ? { inviteCode: group.inviteCode } : {}),
      members,
      childSummaries,
    };
  }

  async createFamilyInvite(userId: string): Promise<FamilyOverview> {
    const profile = await this.repository.getProfile(userId);
    if (profile.accountRole !== "parent") {
      throw new DomainError(
        "family_parent_required",
        "只有家長帳號可以建立家庭邀請。",
        403,
      );
    }
    const existing = await this.repository.getFamilyMembership(userId);
    if (!existing) {
      const inviteCode = randomBytes(5).toString("hex").slice(0, 8).toUpperCase();
      await this.repository.createFamilyGroup(
        userId,
        randomUUID(),
        inviteCode,
      );
    }
    const overview = await this.getFamilyOverview(userId);
    if (!overview) {
      throw new DomainError(
        "family_not_ready",
        "家庭邀請尚未準備完成，請稍後再試。",
        503,
        true,
      );
    }
    return overview;
  }

  async joinFamily(
    userId: string,
    input: { inviteCode: string },
  ): Promise<FamilyOverview> {
    const parsed = familyJoinInputSchema.parse(input);
    const profile = await this.repository.getProfile(userId);
    if (profile.accountRole !== "child") {
      throw new DomainError(
        "family_child_required",
        "只有孩子帳號可以使用家長邀請碼加入家庭。",
        403,
      );
    }
    if (await this.repository.getFamilyMembership(userId)) {
      throw new DomainError(
        "family_already_linked",
        "這個孩子帳號已經加入家庭。",
        409,
      );
    }
    const group = await this.repository.findFamilyByInviteCode(
      parsed.inviteCode,
    );
    if (!group) {
      throw new DomainError("family_invite_not_found", "找不到家庭邀請碼。", 404);
    }
    const members = await this.repository.listFamilyMembers(group.familyId);
    if (!members.some((member) => member.role === "parent")) {
      throw new DomainError(
        "family_parent_missing",
        "這個家庭目前沒有可用的家長帳號。",
        409,
      );
    }
    await this.repository.addFamilyMember(group.familyId, userId);
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
    if (membership.role === "parent" && members.length > 1) {
      throw new DomainError(
        "family_parent_has_children",
        "家長帳號仍有孩子關聯，請先由孩子離開家庭或重新安排關聯。",
        409,
      );
    }
    await this.repository.removeFamilyMember(userId);
    if (members.length <= 1) {
      await this.repository.deleteFamilyGroup(membership.familyId);
    }
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
    return this.withInvestmentOrderLock(userId, async () => {
      const parsed = investmentOrderInputSchema.parse(input);
      const [profile, market, existingOrders] = await Promise.all([
        this.repository.getProfile(userId),
        this.marketDataProvider.getSnapshot(),
        this.repository.listInvestmentOrders(userId),
      ]);
      const account = await this.repository.getOrCreateInvestmentAccount(
        userId,
        profile.goalSavedMinor > 0 ? profile.goalSavedMinor : 1000,
      );
      if (
        existingOrders.some(
          (order) => order.idempotencyKey === parsed.idempotencyKey,
        )
      ) {
        return buildInvestmentLab(account, existingOrders, market);
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
      await this.repository.saveInvestmentOrder(userId, {
        ...parsed,
        name: quote.name,
        unitPrice: quote.price,
        totalMinor,
        quoteAsOf: quote.asOf,
        quoteSource: quote.source,
      });
      return buildInvestmentLab(
        account,
        await this.repository.listInvestmentOrders(userId),
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
