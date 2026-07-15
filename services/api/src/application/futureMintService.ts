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
    return events.filter(
      (event) =>
        (!parsed.type || event.type === parsed.type) &&
        (!parsed.from || new Date(event.occurredAt) >= new Date(parsed.from)) &&
        (!parsed.to || new Date(event.occurredAt) <= new Date(parsed.to)),
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
  }

  rollInvestmentPracticeEvent(userId: string, input: { rollIndex: number }) {
    const parsed = practiceDiceInputSchema.parse(input);
    return rollPracticeEvent(userId, parsed.rollIndex);
  }

  resetDemo(userId: string): Promise<void> {
    return this.repository.resetDemo(userId);
  }
}
