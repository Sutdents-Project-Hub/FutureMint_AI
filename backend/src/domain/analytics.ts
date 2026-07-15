import type {
  FinancialInsights,
  InsightNotice,
  MoneyEvent,
  SpendingIntent,
  UserProfile,
} from "../contracts/models";

const taipeiYearMonth = (value: Date): string => {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
  }).formatToParts(value);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  return `${year}-${month}`;
};

const recentMonthKeys = (now: Date, count: number): string[] => {
  const current = taipeiYearMonth(now);
  const [year, month] = current.split("-").map(Number);
  return Array.from({ length: count }, (_, index) => {
    const date = new Date(Date.UTC(year, month - count + index, 1, 12));
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
  });
};

const effectiveAmount = (event: MoneyEvent): number =>
  event.split?.userShareMinor ?? event.amountMinor;

const monthlySubscriptionAmount = (event: MoneyEvent): number => {
  const amount = effectiveAmount(event);
  return event.recurrence?.billingCycle === "yearly"
    ? Math.round(amount / 12)
    : amount;
};

const intentOf = (event: MoneyEvent): SpendingIntent =>
  event.spendingIntent ?? "uncertain";

export const calculateFinancialInsights = (
  profile: UserProfile,
  events: MoneyEvent[],
  now = new Date(),
): FinancialInsights => {
  const monthKeys = recentMonthKeys(now, 6);
  const currentMonth = monthKeys[monthKeys.length - 1];
  const byMonth = new Map(
    monthKeys.map((month) => [
      month,
      {
        month,
        incomeMinor: 0,
        expenseMinor: 0,
        subscriptionMinor: 0,
        netMinor: 0,
      },
    ]),
  );

  for (const event of events) {
    const point = byMonth.get(taipeiYearMonth(new Date(event.occurredAt)));
    if (!point) continue;
    const amount = effectiveAmount(event);
    if (event.type === "income") point.incomeMinor += amount;
    else if (event.type === "subscription") point.subscriptionMinor += amount;
    else point.expenseMinor += amount;
  }

  const monthlyCashflow = monthKeys.map((month) => {
    const point = byMonth.get(month)!;
    return {
      ...point,
      netMinor:
        point.incomeMinor - point.expenseMinor - point.subscriptionMinor,
    };
  });
  const currentEvents = events.filter(
    (event) => taipeiYearMonth(new Date(event.occurredAt)) === currentMonth,
  );
  const intentTotals: Record<SpendingIntent, number> = {
    need: 0,
    want: 0,
    uncertain: 0,
  };
  for (const event of currentEvents) {
    if (event.type === "income") continue;
    intentTotals[intentOf(event)] += effectiveAmount(event);
  }

  const subscriptions = events.filter(
    (event) => event.type === "subscription",
  );
  const subscriptionMinor = subscriptions.reduce(
    (sum, event) => sum + monthlySubscriptionAmount(event),
    0,
  );
  const notices: InsightNotice[] = [];
  const upcoming = subscriptions
    .map((event) => ({ event, next: event.recurrence?.nextBillingAt }))
    .filter(
      (item): item is { event: MoneyEvent; next: string } =>
        typeof item.next === "string",
    )
    .map((item) => ({
      ...item,
      days: Math.ceil(
        (new Date(item.next).getTime() - now.getTime()) / 86_400_000,
      ),
    }))
    .filter((item) => item.days >= 0 && item.days <= 30)
    .sort((a, b) => a.days - b.days)[0];
  if (upcoming) {
    notices.push({
      id: `subscription-renewal-${upcoming.event.id}`,
      kind: "subscription",
      level: "attention",
      title: "續訂前先問一次：最近真的有在用嗎？",
      message: `${upcoming.event.merchant ?? "這項訂閱"}預計在 ${upcoming.days} 天內續訂；這是檢查提醒，不代表它一定浪費。`,
      actionPath: "/subscriptions",
      amountMinor: monthlySubscriptionAmount(upcoming.event),
    });
  }
  if (subscriptionMinor > profile.monthlyBudgetMinor * 0.15) {
    notices.push({
      id: `subscription-share-${currentMonth}`,
      kind: "subscription",
      level: "attention",
      title: "訂閱占預算的比例值得檢查",
      message: "先確認使用頻率、是否重複，再決定保留或調整，不用急著取消。",
      actionPath: "/subscriptions",
      amountMinor: subscriptionMinor,
    });
  }
  if (intentTotals.want > intentTotals.need && intentTotals.want > 0) {
    notices.push({
      id: `want-balance-${currentMonth}`,
      kind: "spending",
      level: "info",
      title: "本月的想要支出比需要支出高",
      message: "這不是對錯判斷；挑一筆延後 24 小時，再看它是否仍值得。",
      actionPath: "/records",
      amountMinor: intentTotals.want,
    });
  }
  if (intentTotals.uncertain > 0) {
    notices.push({
      id: `intent-review-${currentMonth}`,
      kind: "learning",
      level: "info",
      title: "還有一些支出需要你自己判斷",
      message: "AI 只能提供建議；是否必要仍要看當時情境與你的選擇。",
      actionPath: "/records",
      amountMinor: intentTotals.uncertain,
    });
  }
  if (profile.goalSavedMinor > 0) {
    notices.push({
      id: "saving-simulation",
      kind: "saving",
      level: "positive",
      title: "把已存下來的金額放進時間模擬",
      message: "比較紀律投入與不同風險路徑，不代表未來一定會得到相同結果。",
      actionPath: "/future-seed",
      amountMinor: profile.goalSavedMinor,
    });
  }

  const classified = intentTotals.need + intentTotals.want;
  const summary = classified === 0
    ? "先完成幾筆需要／想要判斷，這裡就會開始形成你的金錢模式。"
    : `本月已分類支出中，想要約占 ${Math.round((intentTotals.want / classified) * 100)}%；先看趨勢，再決定下一個小行動。`;

  return {
    generatedAt: now.toISOString(),
    monthlyCashflow,
    needMinor: intentTotals.need,
    wantMinor: intentTotals.want,
    uncertainMinor: intentTotals.uncertain,
    subscriptionMinor,
    summary,
    notices,
  };
};
