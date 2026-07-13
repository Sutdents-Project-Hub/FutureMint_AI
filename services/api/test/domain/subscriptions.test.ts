import { describe, expect, it } from "vitest";

import { compareSubscription } from "../../src/domain/subscriptions";

describe("compareSubscription", () => {
  it("normalizes billing cycles and sorts eligible options by monthly cost", () => {
    const result = compareSubscription(
      {
        currentName: "影音個人方案",
        currentPriceMinor: 390,
        currentBillingCycle: "monthly",
        members: 4,
        isStudent: true,
      },
      [
        {
          id: "annual",
          name: "學生年繳方案",
          priceMinor: 2400,
          billingCycle: "yearly",
          eligibility: "student",
          sourceType: "synthetic",
          asOf: "2026-07-13",
        },
        {
          id: "shared",
          name: "合法共享月繳方案",
          priceMinor: 520,
          billingCycle: "monthly",
          eligibility: "shared-4",
          sourceType: "synthetic",
          asOf: "2026-07-13",
        },
      ],
    );

    expect(result.currentMonthlyCostMinor).toBe(390);
    expect(result.options.map((option) => option.id)).toEqual([
      "shared",
      "annual",
    ]);
    expect(result.options[0].userMonthlyCostMinor).toBe(130);
    expect(result.options[0].monthlySavingsMinor).toBe(260);
    expect(result.options[1].monthlyCostMinor).toBe(200);
  });

  it("marks ineligible options without presenting savings as actionable", () => {
    const result = compareSubscription(
      {
        currentName: "音樂方案",
        currentPriceMinor: 149,
        currentBillingCycle: "monthly",
        members: 1,
        isStudent: false,
      },
      [
        {
          id: "student",
          name: "學生方案",
          priceMinor: 99,
          billingCycle: "monthly",
          eligibility: "student",
          sourceType: "synthetic",
          asOf: "2026-07-13",
        },
      ],
    );

    expect(result.options[0].eligible).toBe(false);
    expect(result.options[0].monthlySavingsMinor).toBeNull();
  });

  it("uses the plan seat count instead of dividing by extra members", () => {
    const result = compareSubscription(
      {
        currentName: "音樂方案",
        currentPriceMinor: 390,
        currentBillingCycle: "monthly",
        members: 5,
        isStudent: true,
      },
      [
        {
          id: "shared-four",
          name: "四人共享",
          priceMinor: 520,
          billingCycle: "monthly",
          eligibility: "shared-4",
          sourceType: "synthetic",
          asOf: "2026-07-13",
        },
      ],
    );

    expect(result.options[0].userMonthlyCostMinor).toBe(130);
    expect(result.options[0].monthlySavingsMinor).toBe(260);
  });
});
