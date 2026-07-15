import { describe, expect, it } from "vitest";

import type {
  MarketSnapshot,
  VirtualInvestmentAccount,
  VirtualInvestmentOrder,
} from "../../src/contracts/models";
import {
  buildInvestmentLab,
  rollPracticeEvent,
  validateInvestmentOrder,
} from "../../src/domain/investmentLab";

const account: VirtualInvestmentAccount = {
  userId: "student-1",
  startingCashMinor: 10_000,
  createdAt: "2026-07-15T00:00:00.000Z",
};

const market: MarketSnapshot = {
  quotes: [
    {
      symbol: "0050",
      name: "元大台灣50",
      kind: "etf",
      sector: "大型股分散 ETF",
      price: 200,
      change: 2,
      changePercent: 1.01,
      asOf: "2026-07-14",
      source: "twse-openapi",
    },
  ],
  fetchedAt: "2026-07-15T00:00:00.000Z",
  source: "twse-openapi",
  sourceLabel: "臺灣證券交易所 OpenAPI 盤後資料",
  sourceUrl: "https://openapi.twse.com.tw/",
  isFallback: false,
  disclaimer: "盤後資料",
};

const order = (
  overrides: Partial<VirtualInvestmentOrder>,
): VirtualInvestmentOrder => ({
  id: "order-1",
  userId: "student-1",
  symbol: "0050",
  name: "元大台灣50",
  side: "buy",
  quantity: 10,
  unitPrice: 180,
  totalMinor: 1800,
  quoteAsOf: "2026-07-14",
  quoteSource: "twse-openapi",
  idempotencyKey: "order-key-1",
  createdAt: "2026-07-15T01:00:00.000Z",
  ...overrides,
});

describe("investment lab", () => {
  it("derives cash, holdings, allocation, and return from virtual orders", () => {
    const lab = buildInvestmentLab(account, [order({})], market);

    expect(lab).toMatchObject({
      cashMinor: 8200,
      marketValueMinor: 2000,
      totalAssetMinor: 10200,
      gainLossMinor: 200,
      returnPercent: 2,
      diversificationScore: 25,
      holdings: [
        {
          symbol: "0050",
          quantity: 10,
          averageCost: 180,
          currentPrice: 200,
          allocationPercent: 100,
        },
      ],
    });
  });

  it("reduces cost basis when part of a holding is sold", () => {
    const lab = buildInvestmentLab(
      account,
      [
        order({}),
        order({
          id: "order-2",
          side: "sell",
          quantity: 4,
          unitPrice: 210,
          totalMinor: 840,
          idempotencyKey: "order-key-2",
          createdAt: "2026-07-15T02:00:00.000Z",
        }),
      ],
      market,
    );

    expect(lab.cashMinor).toBe(9040);
    expect(lab.holdings[0]).toMatchObject({ quantity: 6, costMinor: 1080 });
  });

  it("rejects orders that exceed virtual cash or holdings", () => {
    const empty = buildInvestmentLab(account, [], market);

    expect(() =>
      validateInvestmentOrder(empty, "0050", "buy", 100, 20_000),
    ).toThrow(/虛擬現金不足/);
    expect(() =>
      validateInvestmentOrder(empty, "0050", "sell", 1, 200),
    ).toThrow(/持有數量不足/);
  });

  it("replays the same event for the same user, date, and roll", () => {
    const first = rollPracticeEvent("student-1", 2, "2026-07-15");
    const repeated = rollPracticeEvent("student-1", 2, "2026-07-15");

    expect(repeated).toEqual(first);
    expect(first.deckVersion).toBe("investment-lab-events-v1");
  });
});
