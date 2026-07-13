import { describe, expect, it } from "vitest";

import { DemoAiProvider } from "../../src/adapters/demoAiProvider";

const provider = new DemoAiProvider();
const referenceTime = "2026-07-13T12:00:00+08:00";

describe("DemoAiProvider competition cases", () => {
  it("returns one editable draft for each clearly separated purchase", async () => {
    const result = await provider.parseCapture({
      text: "早餐 65，飲料 40",
      locale: "zh-TW",
      referenceTime,
    });

    expect(result.drafts).toHaveLength(2);
    expect(result.drafts.map((draft) => draft.amountMinor)).toEqual([65, 40]);
  });

  it("uses the explicitly stated paid price instead of the list price", async () => {
    const result = await provider.parseCapture({
      text: "文具原價 200，折扣後實付 150",
      locale: "zh-TW",
      referenceTime,
    });

    expect(result.drafts).toHaveLength(1);
    expect(result.drafts[0].amountMinor).toBe(150);
  });

  it("resolves yesterday from the supplied zoned reference time", async () => {
    const result = await provider.parseCapture({
      text: "昨天晚餐 180",
      locale: "zh-TW",
      referenceTime,
    });

    expect(result.drafts[0].occurredAt.startsWith("2026-07-12")).toBe(true);
  });

  it("rejects ordinary non-financial conversation", async () => {
    const result = await provider.parseCapture({
      text: "今天心情很好",
      locale: "zh-TW",
      referenceTime,
    });

    expect(result.drafts).toEqual([]);
    expect(result.rejectedReason).toContain("不像");
  });
});
