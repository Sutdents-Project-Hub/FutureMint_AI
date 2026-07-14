import { describe, expect, it } from "vitest";

import { parseRuntimeConfig } from "../../src/http/runtime";

describe("parseRuntimeConfig", () => {
  it("selects explicit demo and memory providers", () => {
    expect(
      parseRuntimeConfig({
        AI_PROVIDER: "demo",
        DATA_PROVIDER: "memory",
      }),
    ).toEqual({
      mode: "demo",
      aiProvider: "demo",
      dataProvider: "memory",
    });
  });

  it("selects Azure mode when either cloud adapter is configured", () => {
    expect(
      parseRuntimeConfig({
        AI_PROVIDER: "azure",
        DATA_PROVIDER: "cosmos",
      }).mode,
    ).toBe("azure");
  });

  it("rejects missing provider choices instead of guessing", () => {
    expect(() => parseRuntimeConfig({})).toThrow("AI_PROVIDER");
  });
});
