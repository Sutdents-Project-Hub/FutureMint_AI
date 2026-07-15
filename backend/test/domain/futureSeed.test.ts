import { describe, expect, it } from "vitest";

import { calculateFutureSeed } from "../../src/domain/futureSeed";

describe("calculateFutureSeed", () => {
  it("uses principal only when the assumed annual rate is zero", () => {
    const preview = calculateFutureSeed({
      monthlyContributionMinor: 1000,
      years: 1,
      annualRatePercent: 0,
    });

    expect(preview.principalMinor).toBe(12000);
    expect(preview.growthMinor).toBe(0);
    expect(preview.endingBalanceMinor).toBe(12000);
  });

  it("uses an end-of-month ordinary annuity for non-zero rates", () => {
    const preview = calculateFutureSeed({
      monthlyContributionMinor: 1000,
      years: 1,
      annualRatePercent: 6,
    });

    expect(preview.principalMinor).toBe(12000);
    expect(preview.endingBalanceMinor).toBe(12336);
    expect(preview.growthMinor).toBe(336);
    expect(preview.yearlyPoints).toEqual([
      { year: 1, principalMinor: 12000, balanceMinor: 12336 },
    ]);
  });

  it("rejects non-positive contributions and unsupported durations", () => {
    expect(() =>
      calculateFutureSeed({
        monthlyContributionMinor: 0,
        years: 1,
        annualRatePercent: 3,
      }),
    ).toThrow("monthlyContributionMinor");

    expect(() =>
      calculateFutureSeed({
        monthlyContributionMinor: 1000,
        years: 0,
        annualRatePercent: 3,
      }),
    ).toThrow("years");
  });
});
