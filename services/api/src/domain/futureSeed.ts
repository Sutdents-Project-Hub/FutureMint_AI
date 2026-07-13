import type { FutureSeedInput, FutureSeedPreview } from "../contracts/models";

const balanceForMonths = (
  monthlyContributionMinor: number,
  months: number,
  annualRatePercent: number,
): number => {
  if (annualRatePercent === 0) {
    return monthlyContributionMinor * months;
  }
  const monthlyRate = annualRatePercent / 100 / 12;
  return Math.round(
    monthlyContributionMinor *
      ((Math.pow(1 + monthlyRate, months) - 1) / monthlyRate),
  );
};

export const calculateFutureSeed = (
  input: FutureSeedInput,
): FutureSeedPreview => {
  if (
    !Number.isInteger(input.monthlyContributionMinor) ||
    input.monthlyContributionMinor <= 0
  ) {
    throw new RangeError("monthlyContributionMinor must be a positive integer");
  }
  if (!Number.isInteger(input.years) || input.years < 1 || input.years > 50) {
    throw new RangeError("years must be an integer from 1 to 50");
  }
  if (input.annualRatePercent < 0 || input.annualRatePercent > 20) {
    throw new RangeError("annualRatePercent must be from 0 to 20");
  }

  const months = input.years * 12;
  const principalMinor = input.monthlyContributionMinor * months;
  const endingBalanceMinor = balanceForMonths(
    input.monthlyContributionMinor,
    months,
    input.annualRatePercent,
  );

  return {
    principalMinor,
    growthMinor: endingBalanceMinor - principalMinor,
    endingBalanceMinor,
    yearlyPoints: Array.from({ length: input.years }, (_, index) => {
      const year = index + 1;
      const elapsedMonths = year * 12;
      return {
        year,
        principalMinor: input.monthlyContributionMinor * elapsedMonths,
        balanceMinor: balanceForMonths(
          input.monthlyContributionMinor,
          elapsedMonths,
          input.annualRatePercent,
        ),
      };
    }),
    disclaimer:
      "此結果為教育試算，採固定假設報酬率，不代表實際投資成果或報酬保證。",
  };
};
