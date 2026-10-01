import { describe, expect, it } from "vitest";
import { AiRequestGate, readAiLimits } from "../../src/application/aiRequestGate";
describe("AI request admission", () => {
  it("limits globally, releases concurrency, and does not charge rejected busy requests", async () => {
    const gate = new AiRequestGate({ dailyUser: 2, dailyGlobal: 3, concurrency: 1, leaseMs: 10000 });
    const release = await gate.acquire("one");
    await expect(gate.acquire("two")).rejects.toMatchObject({ code: "ai_busy" });
    await release(); await (await gate.acquire("two"))(); await (await gate.acquire("one"))();
    await expect(gate.acquire("three")).rejects.toMatchObject({ code: "ai_daily_limit_reached", retryable: false });
  });
  it("uses Taipei calendar day and recovers expired leases", async () => {
    let now = Date.parse("2026-10-01T15:59:59Z");
    const gate = new AiRequestGate({ dailyUser: 1, dailyGlobal: 1, concurrency: 1, leaseMs: 500 }, undefined, () => now);
    await gate.acquire("one"); await expect(gate.acquire("one")).rejects.toMatchObject({ code: "ai_daily_limit_reached" });
    now += 1000; await expect(gate.acquire("one")).resolves.toBeTypeOf("function");
  });
  it("validates all configurable bounds", () => {
    expect(readAiLimits()).toMatchObject({ dailyUser: 30, dailyGlobal: 300, concurrency: 5, leaseMs: 17000 });
    for (const env of [{AI_DAILY_USER_LIMIT:"0"},{AI_MAX_CONCURRENCY:"101"},{AI_DAILY_GLOBAL_LIMIT:"NaN"}]) expect(() => readAiLimits(env)).toThrow();
  });
});
