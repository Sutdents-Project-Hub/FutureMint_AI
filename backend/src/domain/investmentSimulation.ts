import type {
  InvestmentScenario,
  InvestmentScenarioId,
  InvestmentSimulation,
  InvestmentSimulationInput,
} from "../contracts/models";

interface ScenarioDefinition {
  id: InvestmentScenarioId;
  title: string;
  description: string;
  assumedAnnualRatePercent: number;
  riskLabel: string;
  returns: number[];
  eventLabels: Record<number, string>;
}

const definitions: ScenarioDefinition[] = [
  {
    id: "steady",
    title: "穩穩存",
    description: "用儲蓄與定存概念觀察時間和紀律，波動較小。",
    assumedAnnualRatePercent: 1.5,
    riskLabel: "低波動示意",
    returns: [1.4, 1.6, 1.5, 1.7, 1.3],
    eventLabels: {},
  },
  {
    id: "balanced",
    title: "慢慢長",
    description: "用長期分散概念體驗上漲、回落與持續投入。",
    assumedAnnualRatePercent: 5,
    riskLabel: "中度波動示意",
    returns: [8, -4, 10, 3, 6, -12, 9, 5, 8, 2],
    eventLabels: {
      2: "市場回落，但每月投入仍持續",
      6: "較明顯的回檔，分散不代表不會下跌",
    },
  },
  {
    id: "high-risk",
    title: "高風險資產",
    description: "用更大的漲跌體驗報酬不確定性與承受風險。",
    assumedAnnualRatePercent: 8,
    riskLabel: "高度波動示意",
    returns: [18, -12, 26, -35, 22, 9, 14, -18, 30, 7],
    eventLabels: {
      2: "快速回落，高風險資產可能短期虧損",
      4: "大幅下跌，較高假設報酬不代表每年都上漲",
      8: "再次回檔，紀律也不能消除風險",
    },
  },
];

const monthlyRateFromAnnual = (annualPercent: number): number =>
  Math.pow(1 + annualPercent / 100, 1 / 12) - 1;

const normalizedReturnPath = (
  returns: number[],
  targetAnnualPercent: number,
): number[] => {
  const geometricFactor = Math.pow(
    returns.reduce((product, value) => product * (1 + value / 100), 1),
    1 / returns.length,
  );
  const normalizationFactor =
    (1 + targetAnnualPercent / 100) / geometricFactor;
  return returns.map(
    (value) => ((1 + value / 100) * normalizationFactor - 1) * 100,
  );
};

const simulateScenario = (
  input: InvestmentSimulationInput,
  definition: ScenarioDefinition,
): InvestmentScenario => {
  let balance = input.initialAmountMinor;
  let principal = input.initialAmountMinor;
  let returnIndex = 1;
  let peakReturnIndex = 1;
  let maxDrawdown = 0;
  const returnPath = normalizedReturnPath(
    definition.returns,
    definition.assumedAnnualRatePercent,
  );
  const yearlyPoints = [
    {
      year: 0,
      principalMinor: principal,
      balanceMinor: balance,
      annualReturnPercent: 0,
    },
  ];

  for (let year = 1; year <= input.years; year += 1) {
    const annualReturn = returnPath[(year - 1) % returnPath.length];
    const monthlyRate = monthlyRateFromAnnual(annualReturn);
    for (let month = 0; month < 12; month += 1) {
      balance += input.monthlyContributionMinor;
      principal += input.monthlyContributionMinor;
      balance = Math.max(0, Math.round(balance * (1 + monthlyRate)));
      returnIndex *= 1 + monthlyRate;
      peakReturnIndex = Math.max(peakReturnIndex, returnIndex);
      const drawdown =
        ((peakReturnIndex - returnIndex) / peakReturnIndex) * 100;
      maxDrawdown = Math.max(maxDrawdown, drawdown);
    }
    yearlyPoints.push({
      year,
      principalMinor: principal,
      balanceMinor: balance,
      annualReturnPercent: Number(annualReturn.toFixed(2)),
      ...(definition.eventLabels[year]
        ? { eventLabel: definition.eventLabels[year] }
        : {}),
    });
  }

  return {
    id: definition.id,
    title: definition.title,
    description: definition.description,
    assumedAnnualRatePercent: definition.assumedAnnualRatePercent,
    riskLabel: definition.riskLabel,
    principalMinor: principal,
    growthMinor: balance - principal,
    endingBalanceMinor: balance,
    maxDrawdownPercent: Number(maxDrawdown.toFixed(1)),
    yearlyPoints,
  };
};

export const simulateInvestmentScenarios = (
  input: InvestmentSimulationInput,
): InvestmentSimulation => {
  if (!Number.isInteger(input.initialAmountMinor) || input.initialAmountMinor < 0) {
    throw new RangeError("initialAmountMinor must be a non-negative integer");
  }
  if (
    !Number.isInteger(input.monthlyContributionMinor) ||
    input.monthlyContributionMinor <= 0
  ) {
    throw new RangeError("monthlyContributionMinor must be a positive integer");
  }
  if (!Number.isInteger(input.years) || input.years < 1 || input.years > 30) {
    throw new RangeError("years must be an integer from 1 to 30");
  }

  return {
    ...input,
    scenarios: definitions.map((definition) =>
      simulateScenario(input, definition),
    ),
    assumptionVersion: "education-scenarios-2026-07-v1",
    disclaimer:
      "三條曲線使用版本化合成報酬路徑，僅供理解時間、紀律與風險；不是即時行情、投資建議或報酬保證。",
  };
};
