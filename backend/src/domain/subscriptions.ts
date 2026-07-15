import type {
  SubscriptionCompareInput,
  SubscriptionComparison,
  SubscriptionPlan,
} from "../contracts/models";

const monthlyCost = (plan: SubscriptionPlan): number =>
  plan.billingCycle === "yearly"
    ? Math.round(plan.priceMinor / 12)
    : plan.priceMinor;

const requiredSharedMembers = (plan: SubscriptionPlan): number | null => {
  if (!plan.eligibility.startsWith("shared-")) return null;
  const count = Number(plan.eligibility.replace("shared-", ""));
  return Number.isInteger(count) && count > 0 ? count : null;
};

const isEligible = (
  input: SubscriptionCompareInput,
  plan: SubscriptionPlan,
): boolean => {
  if (plan.eligibility === "any") return true;
  if (plan.eligibility === "student") return input.isStudent;
  const requiredMembers = requiredSharedMembers(plan);
  return requiredMembers !== null && input.members >= requiredMembers;
};

export const compareSubscription = (
  input: SubscriptionCompareInput,
  catalog: SubscriptionPlan[],
): SubscriptionComparison => {
  const currentMonthlyCostMinor =
    input.currentBillingCycle === "yearly"
      ? Math.round(input.currentPriceMinor / 12)
      : input.currentPriceMinor;

  const options = catalog
    .map((plan) => {
      const planMonthlyCost = monthlyCost(plan);
      const sharedMembers = requiredSharedMembers(plan);
      const userMonthlyCostMinor = sharedMembers
        ? Math.round(planMonthlyCost / sharedMembers)
        : planMonthlyCost;
      const eligible = isEligible(input, plan);
      return {
        ...plan,
        monthlyCostMinor: planMonthlyCost,
        userMonthlyCostMinor,
        monthlySavingsMinor: eligible
          ? currentMonthlyCostMinor - userMonthlyCostMinor
          : null,
        eligible,
        eligibilityMessage: eligible
          ? "依目前輸入條件可比較；採用前仍需確認服務條款。"
          : "目前輸入條件不符合此方案資格。",
      };
    })
    .sort((a, b) => a.userMonthlyCostMinor - b.userMonthlyCostMinor);

  return {
    currentName: input.currentName,
    currentMonthlyCostMinor,
    options,
    disclaimer:
      "方案價格與資格為合成展示資料，並非即時市場資訊；採用前請查閱官方條款。",
  };
};
