import type {
  AiProvider,
  CaptureInput,
  ConfirmedMoneyEventInput,
  FutureMintRepository,
} from "./ports";
import type {
  DashboardSummary,
  FutureSeedInput,
  Lesson,
  MoneyEvent,
  SubscriptionCompareInput,
  SubscriptionComparison,
  SubscriptionPlan,
  UserProfile,
} from "../contracts/models";
import {
  captureParseInputSchema,
  futureSeedInputSchema,
  moneyEventInputSchema,
  moneyEventListQuerySchema,
  profileInputSchema,
  subscriptionCompareInputSchema,
} from "../contracts/schemas";
import { calculateDashboard } from "../domain/budget";
import { calculateFutureSeed } from "../domain/futureSeed";
import { compareSubscription } from "../domain/subscriptions";
import { DomainError } from "../contracts/errors";

export class FutureMintService {
  constructor(
    private readonly repository: FutureMintRepository,
    private readonly aiProvider: AiProvider,
    private readonly subscriptionCatalog: SubscriptionPlan[],
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

  resetDemo(userId: string): Promise<void> {
    return this.repository.resetDemo(userId);
  }
}
