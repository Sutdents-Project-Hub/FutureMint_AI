import { describe, expect, it } from "vitest";

import { simulateInvestmentScenarios } from "../../src/domain/investmentSimulation";

describe("simulateInvestmentScenarios", () => {
  it("returns the three server-owned education scenarios reproducibly", () => {
    const input = {
      initialAmountMinor: 4200,
      monthlyContributionMinor: 500,
      years: 10,
    };
    const first = simulateInvestmentScenarios(input);
    const second = simulateInvestmentScenarios(input);

    expect(first).toEqual(second);
    expect(first.scenarios.map((scenario) => scenario.id)).toEqual([
      "steady",
      "balanced",
      "high-risk",
    ]);
    expect(first.scenarios.map((scenario) => scenario.assumedAnnualRatePercent)).toEqual([
      1.5,
      5,
      8,
    ]);
    expect(new Set(first.scenarios.map((scenario) => scenario.principalMinor))).toEqual(
      new Set([64200]),
    );
    for (const scenario of first.scenarios) {
      const geometricMean =
        (Math.pow(
          scenario.yearlyPoints
            .slice(1)
            .reduce(
              (product, point) =>
                product * (1 + point.annualReturnPercent / 100),
              1,
            ),
          1 / 10,
        ) -
          1) *
        100;
      expect(geometricMean).toBeCloseTo(
        scenario.assumedAnnualRatePercent,
        1,
      );
    }
  });

  it("includes visible drawdowns for risk education", () => {
    const simulation = simulateInvestmentScenarios({
      initialAmountMinor: 12000,
      monthlyContributionMinor: 500,
      years: 10,
    });
    const highRisk = simulation.scenarios.find(
      (scenario) => scenario.id === "high-risk",
    )!;

    expect(highRisk.maxDrawdownPercent).toBeGreaterThan(0);
    expect(highRisk.maxDrawdownPercent).toBeGreaterThan(30);
    expect(
      highRisk.yearlyPoints.some(
        (point, index, points) =>
          index > 0 && point.balanceMinor < points[index - 1].balanceMinor,
      ),
    ).toBe(true);
    expect(highRisk.yearlyPoints.some((point) => point.eventLabel)).toBe(true);
  });

  it("rejects invalid input boundaries", () => {
    expect(() =>
      simulateInvestmentScenarios({
        initialAmountMinor: -1,
        monthlyContributionMinor: 500,
        years: 5,
      }),
    ).toThrow("initialAmountMinor");
  });
});
