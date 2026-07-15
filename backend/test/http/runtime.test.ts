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

  it("selects hosted mode when either hosted adapter is configured", () => {
    expect(
      parseRuntimeConfig({
        AI_PROVIDER: "liangjie",
        DATA_PROVIDER: "postgres",
      }).mode,
    ).toBe("hosted");
  });

  it("rejects missing provider choices instead of guessing", () => {
    expect(() => parseRuntimeConfig({})).toThrow("AI_PROVIDER");
  });
});
