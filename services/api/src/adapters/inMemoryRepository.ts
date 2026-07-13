import { randomUUID } from "node:crypto";

import type { Lesson, MoneyEvent, UserProfile } from "../contracts/models";
import { DomainError } from "../contracts/errors";
import type {
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

export class InMemoryRepository implements FutureMintRepository {
  private profiles = new Map<string, UserProfile>();
  private events = new Map<string, MoneyEvent[]>();
  private lessons = new Map<string, Lesson[]>();

  constructor() {
    this.seed("demo-user");
  }

  private seed(userId: string): void {
    const profile = { ...profileSeed(), userId };
    const events = eventSeed().map((event) => ({ ...event, userId }));
    this.profiles.set(userId, profile);
    this.events.set(userId, events);
    this.lessons.set(userId, []);
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

  async resetDemo(userId: string): Promise<void> {
    this.seed(userId);
  }
}
