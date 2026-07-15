import { z } from "zod";

import type {
  MarketQuote,
  MarketSnapshot,
} from "../contracts/models";
import type { MarketDataProvider } from "../application/ports";

const twseEndpoint =
  "https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL";

const instrumentMetadata = [
  { symbol: "0050", kind: "etf" as const, sector: "大型股分散 ETF" },
  { symbol: "1301", kind: "stock" as const, sector: "塑膠工業" },
  { symbol: "2330", kind: "stock" as const, sector: "半導體" },
  { symbol: "2603", kind: "stock" as const, sector: "航運業" },
  { symbol: "2886", kind: "stock" as const, sector: "金融業" },
] as const;

const rowSchema = z.object({
  Date: z.string().regex(/^\d{7}$/),
  Code: z.string(),
  Name: z.string().min(1),
  ClosingPrice: z.string(),
  Change: z.string(),
});
const responseSchema = z.array(rowSchema);

const rocDateToIso = (value: string): string => {
  const year = Number(value.slice(0, 3)) + 1911;
  return `${year}-${value.slice(3, 5)}-${value.slice(5, 7)}`;
};

const finiteNumber = (value: string): number | null => {
  const parsed = Number(value.replaceAll(",", ""));
  return Number.isFinite(parsed) ? parsed : null;
};

const fallbackQuotes: MarketQuote[] = [
  ["0050", "元大台灣50", "大型股分散 ETF", 104.4, -1.6],
  ["1301", "台塑", "塑膠工業", 63.6, 3.4],
  ["2330", "台積電", "半導體", 2420, -20],
  ["2603", "長榮", "航運業", 194.5, -0.5],
  ["2886", "兆豐金", "金融業", 47, 0],
].map(([symbol, name, sector, price, change]) => {
  const numericPrice = price as number;
  const numericChange = change as number;
  return {
    symbol: symbol as string,
    name: name as string,
    kind: symbol === "0050" ? "etf" : "stock",
    sector: sector as string,
    price: numericPrice,
    change: numericChange,
    changePercent: Math.round(
      (numericChange / (numericPrice - numericChange)) * 10_000,
    ) / 100,
    asOf: "2026-07-14",
    source: "educational-snapshot",
  };
});

export const educationalMarketSnapshot = (
  fetchedAt = new Date().toISOString(),
): MarketSnapshot => ({
  quotes: fallbackQuotes.map((quote) => ({ ...quote })),
  fetchedAt,
  source: "educational-snapshot",
  sourceLabel: "內建教育快照（證交所盤後格式）",
  sourceUrl: "https://openapi.twse.com.tw/",
  isFallback: true,
  disclaimer:
    "目前顯示明確標示的教育快照，不是即時行情；只供虛擬練習，不代表推薦。",
});

export class EducationalMarketDataProvider implements MarketDataProvider {
  getSnapshot(): Promise<MarketSnapshot> {
    return Promise.resolve(educationalMarketSnapshot());
  }
}

export class TwseMarketDataProvider implements MarketDataProvider {
  private cached?: { expiresAt: number; snapshot: MarketSnapshot };
  private inFlight?: Promise<MarketSnapshot>;

  constructor(
    private readonly fetcher: typeof fetch = fetch,
    private readonly now: () => Date = () => new Date(),
  ) {}

  getSnapshot(): Promise<MarketSnapshot> {
    const now = this.now();
    if (this.cached && this.cached.expiresAt > now.getTime()) {
      return Promise.resolve(this.cached.snapshot);
    }
    if (this.inFlight) return this.inFlight;
    let pending: Promise<MarketSnapshot>;
    pending = this.fetchSnapshot(now).finally(() => {
      if (this.inFlight === pending) this.inFlight = undefined;
    });
    this.inFlight = pending;
    return pending;
  }

  private async fetchSnapshot(now: Date): Promise<MarketSnapshot> {
    try {
      const response = await this.fetcher(twseEndpoint, {
        headers: { accept: "application/json" },
        signal: AbortSignal.timeout(5_000),
      });
      if (!response.ok) throw new Error(`TWSE returned ${response.status}`);
      const rows = responseSchema.parse(await response.json());
      const rowByCode = new Map(rows.map((row) => [row.Code, row]));
      const quotes = instrumentMetadata.flatMap(
        ({ symbol, kind, sector }) => {
          const row = rowByCode.get(symbol);
          if (!row) return [];
          const price = finiteNumber(row.ClosingPrice);
          const change = finiteNumber(row.Change);
          if (price == null || change == null || price <= 0) return [];
          const previous = price - change;
          return [
            {
              symbol,
              name: row.Name,
              kind,
              sector,
              price,
              change,
              changePercent:
                previous === 0
                  ? 0
                  : Math.round((change / previous) * 10_000) / 100,
              asOf: rocDateToIso(row.Date),
              source: "twse-openapi" as const,
            },
          ];
        },
      );
      if (quotes.length !== instrumentMetadata.length) {
        throw new Error("TWSE response is missing curated instruments");
      }
      const snapshot: MarketSnapshot = {
        quotes,
        fetchedAt: now.toISOString(),
        source: "twse-openapi",
        sourceLabel: "臺灣證券交易所 OpenAPI 盤後資料",
        sourceUrl: "https://openapi.twse.com.tw/",
        isFallback: false,
        disclaimer:
          "盤後價格可能延遲，標的只為產業與分散概念示例，不是推薦或報酬預測。",
      };
      this.cached = {
        expiresAt: now.getTime() + 15 * 60 * 1000,
        snapshot,
      };
      return snapshot;
    } catch {
      const snapshot = educationalMarketSnapshot(now.toISOString());
      this.cached = {
        expiresAt: now.getTime() + 2 * 60 * 1000,
        snapshot,
      };
      return snapshot;
    }
  }
}
