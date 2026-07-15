import { describe, expect, it } from "vitest";

import { TwseMarketDataProvider } from "../../src/adapters/twseMarketDataProvider";

const twseRows = [
  ["0050", "元大台灣50", "200.50", "2.50"],
  ["1301", "台塑", "42.60", "-0.60"],
  ["2330", "台積電", "1125.00", "-15.00"],
  ["2603", "長榮", "187.50", "1.50"],
  ["2886", "兆豐金", "41.15", "-0.15"],
].map(([Code, Name, ClosingPrice, Change]) => ({
  Date: "1150714",
  Code,
  Name,
  ClosingPrice,
  Change,
}));

describe("TwseMarketDataProvider", () => {
  it("normalizes the curated TWSE daily snapshot", async () => {
    const provider = new TwseMarketDataProvider(
      async () =>
        new Response(JSON.stringify(twseRows), {
          status: 200,
          headers: { "content-type": "application/json" },
        }),
      () => new Date("2026-07-15T03:00:00.000Z"),
    );

    const snapshot = await provider.getSnapshot();

    expect(snapshot).toMatchObject({
      source: "twse-openapi",
      isFallback: false,
      fetchedAt: "2026-07-15T03:00:00.000Z",
    });
    expect(snapshot.quotes).toHaveLength(5);
    expect(snapshot.quotes[0]).toMatchObject({
      symbol: "0050",
      price: 200.5,
      asOf: "2026-07-14",
      source: "twse-openapi",
    });
  });

  it("uses a clearly labelled educational snapshot after provider failure", async () => {
    const provider = new TwseMarketDataProvider(
      async () => {
        throw new Error("offline");
      },
      () => new Date("2026-07-15T03:00:00.000Z"),
    );

    const snapshot = await provider.getSnapshot();

    expect(snapshot).toMatchObject({
      source: "educational-snapshot",
      isFallback: true,
    });
    expect(snapshot.disclaimer).toContain("不是即時行情");
  });

  it("shares one in-flight fetch when several requests arrive before the cache", async () => {
    let calls = 0;
    let releaseFetch: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      releaseFetch = resolve;
    });
    const provider = new TwseMarketDataProvider(
      async () => {
        calls += 1;
        await gate;
        return new Response(JSON.stringify(twseRows), { status: 200 });
      },
      () => new Date("2026-07-15T03:00:00.000Z"),
    );

    const snapshots = [provider.getSnapshot(), provider.getSnapshot()];
    expect(calls).toBe(1);
    releaseFetch();

    const [first, second] = await Promise.all(snapshots);
    expect(first).toBe(second);
    expect(first.source).toBe("twse-openapi");
  });
});
