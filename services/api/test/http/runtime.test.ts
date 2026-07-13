import { describe, expect, it } from "vitest";

import { parseRuntimeConfig } from "../../src/http/runtime";

describe("parseRuntimeConfig", () => {
  it("selects explicit demo and memory providers", () => {
    expect(
      parseRuntimeConfig({
        AI_PROVIDER: "demo",
        DATA_PROVIDER: "memory",
        DEMO_RESET_ENABLED: "true",
      }),
    ).toEqual({
      mode: "demo",
      aiProvider: "demo",
      dataProvider: "memory",
      demoResetEnabled: true,
    });
  });

  it("selects Azure mode when either cloud adapter is configured", () => {
    expect(
      parseRuntimeConfig({
        AI_PROVIDER: "azure",
        DATA_PROVIDER: "cosmos",
        DEMO_RESET_ENABLED: "false",
      }).mode,
    ).toBe("azure");
  });

  it("rejects missing provider choices instead of guessing", () => {
    expect(() => parseRuntimeConfig({})).toThrow("AI_PROVIDER");
  });
});
