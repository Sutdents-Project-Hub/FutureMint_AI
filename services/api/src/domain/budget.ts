import type {
  CategoryTotal,
  DashboardSummary,
  MoneyCategory,
  MoneyEvent,
  UserProfile,
} from "../contracts/models";

const taipeiMonth = (value: Date): string => {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
  }).formatToParts(value);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  return `${year}-${month}`;
};

export const calculateDashboard = (
  profile: UserProfile,
  events: MoneyEvent[],
  now: Date,
): DashboardSummary => {
  const currentMonth = taipeiMonth(now);
  const monthlyEvents = events.filter(
    (event) => taipeiMonth(new Date(event.occurredAt)) === currentMonth,
  );

  let incomeMinor = 0;
  let expenseMinor = 0;
  let subscriptionMinor = 0;
  const totals = new Map<MoneyCategory, number>();

  for (const event of monthlyEvents) {
    if (event.type === "income") {
      incomeMinor += event.amountMinor;
      continue;
    }

    const effectiveAmount = event.split?.userShareMinor ?? event.amountMinor;
    if (event.type === "subscription") {
      subscriptionMinor += effectiveAmount;
    } else {
      expenseMinor += effectiveAmount;
    }
    totals.set(
      event.category,
      (totals.get(event.category) ?? 0) + effectiveAmount,
    );
  }

  const categoryTotals: CategoryTotal[] = [...totals.entries()]
    .map(([category, amountMinor]) => ({ category, amountMinor }))
    .sort((a, b) => b.amountMinor - a.amountMinor);
  const goalTarget = Math.max(profile.goalTargetMinor, 1);

  return {
    monthlyBudgetMinor: profile.monthlyBudgetMinor,
    incomeMinor,
    expenseMinor,
    subscriptionMinor,
    availableMinor:
      profile.monthlyBudgetMinor - expenseMinor - subscriptionMinor,
    goalRemainingMinor: Math.max(
      0,
      profile.goalTargetMinor - profile.goalSavedMinor,
    ),
    goalProgress: Math.min(1, profile.goalSavedMinor / goalTarget),
    categoryTotals,
    recentEvents: [...events]
      .sort(
        (a, b) =>
          new Date(b.occurredAt).getTime() - new Date(a.occurredAt).getTime(),
      )
      .slice(0, 5),
  };
};
