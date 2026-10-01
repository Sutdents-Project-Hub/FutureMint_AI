import type { Subscription, SubscriptionInput } from "../contracts/models";

export const taipeiDate = (now: Date): string => {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now);
  return ["year", "month", "day"].map((key) => parts.find((part) => part.type === key)!.value).join("-");
};

const billingDate = (year: number, month: number, day: number): string => {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return `${year}-${String(month).padStart(2,"0")}-${String(Math.min(day,lastDay)).padStart(2,"0")}`;
};

// Derive from the original anchor each time: February clamping never changes
// a January 31 / February 29 billing anniversary.
export const nextSubscriptionBillingDate = (
  subscription: Pick<Subscription, "anchorDate" | "billingCycle" | "originalBillingDay" | "originalBillingMonth">,
  now = new Date(),
): string => {
  const today = taipeiDate(now);
  if (subscription.anchorDate >= today) return subscription.anchorDate;
  const [year, month] = today.split("-").map(Number);
  if (subscription.billingCycle === "yearly") {
    const current = billingDate(year, subscription.originalBillingMonth, subscription.originalBillingDay);
    return current >= today ? current : billingDate(year + 1, subscription.originalBillingMonth, subscription.originalBillingDay);
  }
  const current = billingDate(year, month, subscription.originalBillingDay);
  const nextMonth = new Date(Date.UTC(year, month, 1));
  return current >= today ? current : billingDate(nextMonth.getUTCFullYear(), nextMonth.getUTCMonth()+1, subscription.originalBillingDay);
};

export const subscriptionAnchor = (input: SubscriptionInput) => {
  const [, originalBillingMonth, originalBillingDay] = input.anchorDate.split("-").map(Number);
  return { originalBillingDay, originalBillingMonth };
};

export const monthlySubscriptionCommitment = (subscriptions: Subscription[]): number =>
  subscriptions.filter((item) => item.active).reduce((sum,item) => sum + (item.billingCycle === "yearly" ? Math.round(item.amountMinor/12) : item.amountMinor),0);

export const withNextBillingDate = (item: Subscription, now = new Date()): Subscription => ({...item, nextBillingDate: nextSubscriptionBillingDate(item, now)});
