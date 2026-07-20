import { describe, expect, it } from "vitest";

import { FutureMintService } from "../../src/application/futureMintService";
import { demoCatalog } from "../../src/adapters/demoCatalog";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { EducationalMarketDataProvider } from "../../src/adapters/twseMarketDataProvider";

const createService = () => {
  const repository = new InMemoryRepository();
  const aiProvider = new DemoAiProvider();
  return {
    repository,
    service: new FutureMintService(
      repository,
      aiProvider,
      demoCatalog,
      new EducationalMarketDataProvider(),
    ),
  };
};

describe("FutureMintService capture lifecycle", () => {
  it("does not persist a parsed capture before confirmation", async () => {
    const { repository, service } = createService();
    const before = await repository.listMoneyEvents("demo-user");

    const parsed = await service.parseCapture("demo-user", {
      text: "今天買珍奶 75",
      locale: "zh-TW",
      referenceTime: "2026-07-13T12:00:00+08:00",
    });

    const after = await repository.listMoneyEvents("demo-user");
    expect(parsed.drafts).toHaveLength(1);
    expect(parsed.drafts[0]).toMatchObject({
      type: "expense",
      amountMinor: 75,
      category: "food",
      source: "deterministic-demo",
      needsConfirmation: true,
    });
    expect(after).toEqual(before);
  });

  it("persists a confirmed event exactly once for an idempotency key", async () => {
    const { service } = createService();
    const input = {
      type: "expense" as const,
      amountMinor: 75,
      currency: "TWD" as const,
      category: "food" as const,
      merchant: "珍奶",
      occurredAt: "2026-07-13T12:00:00+08:00",
      confirmed: true as const,
      idempotencyKey: "capture-20260713-drink",
    };

    const first = await service.saveMoneyEvent("demo-user", input);
    const second = await service.saveMoneyEvent("demo-user", input);
    const events = await service.listMoneyEvents("demo-user");

    expect(second.id).toBe(first.id);
    expect(
      events.filter((event) => event.idempotencyKey === input.idempotencyKey),
    ).toHaveLength(1);
  });

  it("sorts the event timeline consistently by newest occurrence", async () => {
    const { service } = createService();

    const events = await service.listMoneyEvents("demo-user");

    expect(events.map((event) => event.merchant)).toEqual([
      "遊戲點數",
      "珍奶",
      "打工收入",
      "影音訂閱",
    ]);
  });

  it("recomputes split share instead of trusting client or AI arithmetic", async () => {
    const { service } = createService();
    const event = await service.saveMoneyEvent("demo-user", {
      type: "subscription",
      amountMinor: 400,
      currency: "TWD",
      category: "subscription",
      occurredAt: "2026-07-13T12:00:00+08:00",
      recurrence: { billingCycle: "monthly" },
      split: { participants: 4, userShareMinor: 1 },
      confirmed: true,
      idempotencyKey: "capture-split-correction",
    });

    expect(event.split).toEqual({ participants: 4, userShareMinor: 100 });
  });

  it("rejects a sentence that explicitly says the purchase did not happen", async () => {
    const { service } = createService();
    const result = await service.parseCapture("demo-user", {
      text: "本來想買耳機 3000，但沒有買",
      locale: "zh-TW",
      referenceTime: "2026-07-13T12:00:00+08:00",
    });

    expect(result.drafts).toEqual([]);
    expect(result.rejectedReason).toBe(
      "文字表示交易沒有發生，因此不會建立草稿。",
    );
  });

  it("returns one clarification question when the amount is missing", async () => {
    const { service } = createService();
    const result = await service.parseCapture("demo-user", {
      text: "剛剛買飲料",
      locale: "zh-TW",
      referenceTime: "2026-07-13T12:00:00+08:00",
    });

    expect(result.drafts[0].missingFields).toEqual(["amountMinor"]);
    expect(result.clarificationQuestion).toBe("這筆飲料花了多少元？");
  });
});

describe("FutureMintService decisions", () => {
  it("recalculates the dashboard from confirmed events", async () => {
    const { service } = createService();
    const dashboard = await service.getDashboard(
      "demo-user",
      new Date("2026-07-13T12:00:00+08:00"),
    );

    expect(dashboard.monthlyBudgetMinor).toBe(6000);
    expect(dashboard.recentEvents.length).toBeGreaterThan(0);
    expect(dashboard.availableMinor).toBeLessThan(6000);
  });

  it("serializes concurrent virtual orders so cash cannot be overspent", async () => {
    const { service } = createService();
    const results = await Promise.allSettled([
      service.placeInvestmentOrder("demo-user", {
        symbol: "0050",
        side: "buy",
        quantity: 30,
        idempotencyKey: "concurrent-buy-one",
      }),
      service.placeInvestmentOrder("demo-user", {
        symbol: "0050",
        side: "buy",
        quantity: 30,
        idempotencyKey: "concurrent-buy-two",
      }),
    ]);

    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    const rejected = results.find(
      (result): result is PromiseRejectedResult => result.status === "rejected",
    );
    expect(rejected?.reason).toMatchObject({
      code: "insufficient_virtual_cash",
      status: 422,
    });
    const lab = await service.getInvestmentLab("demo-user");
    expect(lab.cashMinor).toBeGreaterThanOrEqual(0);
    expect(lab.orders).toHaveLength(1);
  });

  it("generates a bounded micro lesson from confirmed data", async () => {
    const { service } = createService();
    const lesson = await service.generateLesson("demo-user");

    expect(lesson.concept.length).toBeLessThanOrEqual(100);
    expect(lesson.options.length).toBeGreaterThanOrEqual(2);
    expect(lesson.source).toBe("deterministic-demo");
    expect(lesson.disclaimer).toContain("教育");
  });

  it("rejects a lesson choice that is not one of the presented options", async () => {
    const { service } = createService();
    const lesson = await service.generateLesson("demo-user");

    await expect(
      service.completeLesson("demo-user", lesson.id, "任意未呈現的選項"),
    ).rejects.toMatchObject({
      code: "invalid_lesson_option",
      status: 422,
      retryable: false,
    });
  });

  it("returns a not-found domain error for an unknown lesson", async () => {
    const { service } = createService();

    await expect(
      service.completeLesson("demo-user", "missing-lesson", "選項"),
    ).rejects.toMatchObject({
      code: "lesson_not_found",
      status: 404,
      retryable: false,
    });
  });

  it("returns the latest saved lesson including its completed choice", async () => {
    const { service } = createService();
    const lesson = await service.generateLesson("demo-user");
    await service.completeLesson("demo-user", lesson.id, lesson.options[0]);

    const current = await service.getCurrentLesson("demo-user");

    expect(current.id).toBe(lesson.id);
    expect(current.selectedOption).toBe(lesson.options[0]);
  });

  it("links a parent and child while sharing only child summaries", async () => {
    const { repository, service } = createService();
    await repository.resetDemo("parent-user");
    await repository.resetDemo("child-user");
    const parent = await repository.getProfile("parent-user");
    const child = await repository.getProfile("child-user");
    await repository.saveProfile({ ...parent, accountRole: "parent" });
    await repository.saveProfile({ ...child, accountRole: "child" });

    const invited = await service.createFamilyInvite("parent-user");
    expect(invited.inviteCode).toMatch(/^[A-Z0-9]{8}$/u);
    expect(invited.members).toHaveLength(1);

    const childView = await service.joinFamily("child-user", {
      inviteCode: invited.inviteCode!,
    });
    expect(childView.inviteCode).toBeUndefined();
    expect(childView.childSummaries).toEqual([]);
    expect(childView.members.map((member) => member.label)).toEqual([
      "家長帳號",
      "孩子帳號 1（你）",
    ]);

    const parentView = await service.getFamilyOverview("parent-user");
    expect(parentView?.childSummaries).toMatchObject([
      {
        userId: "child-user",
        label: "孩子帳號 1",
        summary: expect.any(String),
      },
    ]);
    expect(JSON.stringify(parentView)).not.toContain("@demo.local");
    await expect(service.leaveFamily("parent-user")).rejects.toMatchObject({
      code: "family_parent_has_children",
      status: 409,
    });
    await expect(
      service.updateProfile("child-user", {
        ...child,
        accountRole: "parent",
      }),
    ).rejects.toMatchObject({
      code: "family_role_locked",
      status: 409,
    });
  });

  it("treats a saved lesson as stale after a newer money event", async () => {
    const { service } = createService();
    await service.generateLesson("demo-user");
    await service.saveMoneyEvent("demo-user", {
      type: "expense",
      amountMinor: 60,
      currency: "TWD",
      category: "food",
      occurredAt: "2026-07-13T20:00:00+08:00",
      confirmed: true,
      idempotencyKey: "event-after-lesson",
    });

    await expect(service.getCurrentLesson("demo-user")).rejects.toMatchObject({
      code: "lesson_not_found",
      status: 404,
    });
  });

  it("personalizes from the five most recent events by occurrence time", async () => {
    const { service } = createService();
    await service.saveMoneyEvent("demo-user", {
      type: "expense",
      amountMinor: 10,
      currency: "TWD",
      category: "other",
      occurredAt: "2025-01-01T12:00:00+08:00",
      confirmed: true,
      idempotencyKey: "very-old-event",
    });
    await service.saveMoneyEvent("demo-user", {
      type: "expense",
      amountMinor: 20,
      currency: "TWD",
      category: "other",
      occurredAt: "2026-07-12T12:00:00+08:00",
      confirmed: true,
      idempotencyKey: "newest-event",
    });

    const lesson = await service.generateLesson("demo-user");

    expect(lesson.sourceEventIds).toHaveLength(5);
    expect(lesson.sourceEventIds).not.toContain(
      expect.stringContaining("very-old"),
    );
    const events = await service.listMoneyEvents("demo-user");
    const oldEvent = events.find(
      (event) => event.idempotencyKey === "very-old-event",
    );
    expect(lesson.sourceEventIds).not.toContain(oldEvent?.id);
  });
});
