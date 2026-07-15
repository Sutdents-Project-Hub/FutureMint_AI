import { describe, expect, it } from "vitest";

import { calculateDashboard } from "../../src/domain/budget";
import type { MoneyEvent, UserProfile } from "../../src/contracts/models";

const profile: UserProfile = {
  userId: "demo-user",
  monthlyBudgetMinor: 6000,
  goalName: "校外活動基金",
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
  occurredAt = "2026-07-10T12:00:00+08:00",
): MoneyEvent => ({
  id,
  userId: "demo-user",
  type,
  amountMinor,
  currency: "TWD",
  category: type === "income" ? "income" : "food",
  occurredAt,
  createdAt: occurredAt,
  updatedAt: occurredAt,
});

describe("calculateDashboard", () => {
  it("subtracts confirmed monthly expenses from the configured budget", () => {
    const summary = calculateDashboard(
      profile,
      [event("one", "expense", 3000), event("two", "expense", 435)],
      new Date("2026-07-13T00:00:00+08:00"),
    );

    expect(summary.monthlyBudgetMinor).toBe(6000);
    expect(summary.expenseMinor).toBe(3435);
    expect(summary.availableMinor).toBe(2565);
  });

  it("excludes events outside the current month", () => {
    const summary = calculateDashboard(
      profile,
      [event("june", "expense", 1000, "2026-06-30T23:00:00+08:00")],
      new Date("2026-07-13T00:00:00+08:00"),
    );

    expect(summary.expenseMinor).toBe(0);
    expect(summary.availableMinor).toBe(6000);
  });

  it("reports income separately without inflating the spending budget", () => {
    const summary = calculateDashboard(
      profile,
      [event("salary", "income", 1500), event("drink", "expense", 75)],
      new Date("2026-07-13T00:00:00+08:00"),
    );

    expect(summary.incomeMinor).toBe(1500);
    expect(summary.availableMinor).toBe(5925);
  });
});
