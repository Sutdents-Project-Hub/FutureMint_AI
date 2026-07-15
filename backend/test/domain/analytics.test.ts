import { describe, expect, it } from "vitest";

import type { MoneyEvent, UserProfile } from "../../src/contracts/models";
import { calculateFinancialInsights } from "../../src/domain/analytics";

const profile: UserProfile = {
  userId: "student",
  monthlyBudgetMinor: 6000,
  goalName: "活動基金",
  goalTargetMinor: 12000,
  goalSavedMinor: 4200,
  goalDate: "2026-10-31",
  preferredTone: "supportive",
  accountRole: "child",
};

const event = (
  id: string,
  type: MoneyEvent["type"],
  amountMinor: number,
  occurredAt: string,
  spendingIntent?: MoneyEvent["spendingIntent"],
): MoneyEvent => ({
  id,
  userId: "student",
  type,
  amountMinor,
  currency: "TWD",
  category: type === "income" ? "income" : type === "subscription" ? "subscription" : "entertainment",
  occurredAt,
  spendingIntent,
  createdAt: occurredAt,
  updatedAt: occurredAt,
});

describe("calculateFinancialInsights", () => {
  it("builds six deterministic monthly cashflow points and intent totals", () => {
    const insights = calculateFinancialInsights(
      profile,
      [
        event("june-income", "income", 1500, "2026-06-10T12:00:00+08:00"),
        event("june-expense", "expense", 1000, "2026-06-12T12:00:00+08:00", "need"),
        event("july-want", "expense", 450, "2026-07-10T12:00:00+08:00", "want"),
      ],
      new Date("2026-07-15T12:00:00+08:00"),
    );

    expect(insights.monthlyCashflow).toHaveLength(6);
    expect(insights.monthlyCashflow.at(-2)).toMatchObject({
      month: "2026-06",
      netMinor: 500,
    });
    expect(insights.wantMinor).toBe(450);
    expect(insights.notices).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ kind: "spending", level: "info" }),
        expect.objectContaining({ kind: "saving", level: "positive" }),
      ]),
    );
  });

  it("only calls a subscription a review reminder when renewal data exists", () => {
    const subscription = {
      ...event(
        "subscription",
        "subscription",
        390,
        "2026-07-01T08:00:00+08:00",
        "uncertain",
      ),
      merchant: "影音訂閱",
      recurrence: {
        billingCycle: "monthly" as const,
        nextBillingAt: "2026-07-20T08:00:00+08:00",
      },
    };
    const insights = calculateFinancialInsights(
      profile,
      [subscription],
      new Date("2026-07-15T12:00:00+08:00"),
    );

    expect(insights.notices[0]).toMatchObject({
      kind: "subscription",
      title: expect.stringContaining("續訂前"),
    });
    expect(insights.notices[0].message).toContain("不代表它一定浪費");
  });
});
