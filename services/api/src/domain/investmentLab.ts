import { createHash } from "node:crypto";

import { DomainError } from "../contracts/errors";
import type {
  InvestmentLab,
  MarketSnapshot,
  PracticeDiceEvent,
  VirtualHolding,
  VirtualInvestmentAccount,
  VirtualInvestmentOrder,
} from "../contracts/models";

interface HoldingAccumulator {
  symbol: string;
  name: string;
  quantity: number;
  costMinor: number;
}

const roundedPercent = (value: number): number =>
  Math.round(value * 100) / 100;

export const buildInvestmentLab = (
  account: VirtualInvestmentAccount,
  orders: VirtualInvestmentOrder[],
  market: MarketSnapshot,
): InvestmentLab => {
  const quoteBySymbol = new Map(
    market.quotes.map((quote) => [quote.symbol, quote]),
  );
  const positions = new Map<string, HoldingAccumulator>();
  let cashMinor = account.startingCashMinor;

  for (const order of [...orders].sort((a, b) =>
    a.createdAt.localeCompare(b.createdAt),
  )) {
    const current = positions.get(order.symbol) ?? {
      symbol: order.symbol,
      name: order.name,
      quantity: 0,
      costMinor: 0,
    };
    if (order.side === "buy") {
      current.quantity += order.quantity;
      current.costMinor += order.totalMinor;
      cashMinor -= order.totalMinor;
    } else {
      const averageCost =
        current.quantity === 0 ? 0 : current.costMinor / current.quantity;
      current.costMinor = Math.max(
        0,
        Math.round(current.costMinor - averageCost * order.quantity),
      );
      current.quantity -= order.quantity;
      cashMinor += order.totalMinor;
    }
    positions.set(order.symbol, current);
  }

  const positionValues = [...positions.values()]
    .filter((position) => position.quantity > 0)
    .map((position) => {
      const quote = quoteBySymbol.get(position.symbol);
      const currentPrice = quote?.price ?? position.costMinor / position.quantity;
      const marketValueMinor = Math.round(currentPrice * position.quantity);
      return { position, currentPrice, marketValueMinor };
    });
  const marketValueMinor = positionValues.reduce(
    (sum, item) => sum + item.marketValueMinor,
    0,
  );
  const holdings: VirtualHolding[] = positionValues.map(
    ({ position, currentPrice, marketValueMinor }) => ({
      symbol: position.symbol,
      name: position.name,
      quantity: position.quantity,
      averageCost: roundedPercent(position.costMinor / position.quantity),
      currentPrice,
      costMinor: position.costMinor,
      marketValueMinor,
      gainLossMinor: marketValueMinor - position.costMinor,
      allocationPercent: 0,
    }),
  );
  for (const holding of holdings) {
    holding.allocationPercent =
      marketValueMinor === 0
        ? 0
        : roundedPercent((holding.marketValueMinor / marketValueMinor) * 100);
  }

  const totalAssetMinor = cashMinor + marketValueMinor;
  const gainLossMinor = totalAssetMinor - account.startingCashMinor;
  const largestAllocation = holdings.reduce(
    (largest, holding) => Math.max(largest, holding.allocationPercent),
    0,
  );
  const diversificationScore =
    holdings.length === 0
      ? 0
      : holdings.length === 1
        ? 25
        : holdings.length === 2
          ? largestAllocation <= 65
            ? 60
            : 45
          : largestAllocation <= 50
            ? 90
            : 70;
  const learningSummary =
    holdings.length === 0
      ? "先選一個標的觀察，再決定是否用少量虛擬資金開始練習。"
      : largestAllocation > 70
        ? "目前資產集中在單一標的，先觀察集中風險，不需要為了分數頻繁交易。"
        : holdings.length < 3
          ? "你已開始配置資產；下一步可以比較不同產業或 ETF 的波動差異。"
          : "目前配置較分散，接下來請觀察分散是否降低整體波動，而不是只看單日漲跌。";

  return {
    startingCashMinor: account.startingCashMinor,
    cashMinor,
    marketValueMinor,
    totalAssetMinor,
    gainLossMinor,
    returnPercent:
      account.startingCashMinor === 0
        ? 0
        : roundedPercent((gainLossMinor / account.startingCashMinor) * 100),
    diversificationScore,
    learningSummary,
    holdings,
    orders: [...orders].sort((a, b) =>
      b.createdAt.localeCompare(a.createdAt),
    ),
    market,
    disclaimer:
      "這是教育用虛擬帳戶，不會送出真實委託，也不是投資建議。價格可能延遲，未計入手續費、稅與股利。",
  };
};

export const validateInvestmentOrder = (
  lab: InvestmentLab,
  symbol: string,
  side: "buy" | "sell",
  quantity: number,
  totalMinor: number,
): void => {
  if (side === "buy" && totalMinor > lab.cashMinor) {
    throw new DomainError(
      "insufficient_virtual_cash",
      "虛擬現金不足，請減少數量後再試。",
      422,
      false,
      { quantity: "這筆練習買入超過目前虛擬現金。" },
    );
  }
  const owned =
    lab.holdings.find((holding) => holding.symbol === symbol)?.quantity ?? 0;
  if (side === "sell" && quantity > owned) {
    throw new DomainError(
      "insufficient_virtual_holding",
      "持有數量不足，不能賣出超過目前的虛擬持股。",
      422,
      false,
      { quantity: "賣出數量超過虛擬持股。" },
    );
  }
};

const eventDeck = [
  {
    id: "market-drop",
    title: "市場突然回檔",
    situation: "整體市場短期下跌，新聞標題變得很緊張。",
    practicePrompt: "先比較整體配置與單一標的跌幅，再決定是否需要任何動作。",
    coachQuestion: "市場突然下跌時，為什麼不一定要立刻賣出？",
    learningFocus: "risk" as const,
  },
  {
    id: "allowance-gap",
    title: "這個月暫停投入",
    situation: "臨時支出增加，這個月沒有多餘的錢可以投入。",
    practicePrompt: "保留生活預備金，觀察少投入一個月與長期紀律的關係。",
    coachQuestion: "暫停投入一個月，為什麼不等於長期計畫失敗？",
    learningFocus: "discipline" as const,
  },
  {
    id: "hot-topic",
    title: "熱門話題快速上漲",
    situation: "同學都在討論某個快速上漲的標的，你開始擔心錯過。",
    practicePrompt: "先檢查資訊來源、持有比例與能承受的損失，不因熱度直接追價。",
    coachQuestion: "為什麼只因為大家都在談，就買進可能有風險？",
    learningFocus: "risk" as const,
  },
  {
    id: "concentration-check",
    title: "集中度檢查",
    situation: "你的多數虛擬資產都集中在同一家公司或產業。",
    practicePrompt: "比較單一股票與分散型 ETF 的配置差異，記錄波動感受。",
    coachQuestion: "什麼是集中風險？分散為什麼仍不能保證不會虧損？",
    learningFocus: "diversification" as const,
  },
  {
    id: "fee-drag",
    title: "交易成本出現",
    situation: "你發現頻繁買賣即使方向猜對，也可能累積手續費與稅。",
    practicePrompt: "本回合不交易，先計算如果每次都收費，長期會少多少。",
    coachQuestion: "為什麼頻繁交易的成本會拖累長期成果？",
    learningFocus: "fees" as const,
  },
] as const;

export const rollPracticeEvent = (
  userId: string,
  rollIndex: number,
  dateKey = new Date().toISOString().slice(0, 10),
): PracticeDiceEvent => {
  const digest = createHash("sha256")
    .update(`investment-lab-events-v1:${userId}:${dateKey}:${rollIndex}`)
    .digest();
  const event = eventDeck[digest.readUInt32BE(0) % eventDeck.length];
  return {
    ...event,
    rollIndex,
    deckVersion: "investment-lab-events-v1",
    disclaimer: "事件卡是教育情境，不是市場預測或買賣訊號。",
  };
};
