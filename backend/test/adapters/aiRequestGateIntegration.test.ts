import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { AiRequestGate } from "../../src/application/aiRequestGate";
import { AuthService } from "../../src/auth/authService";
import { PostgresRepository } from "../../src/adapters/postgresRepository";
import { runMigrations } from "../../scripts/migrate";
const connectionString = process.env.FUTUREMINT_TEST_DATABASE_URL;
if (connectionString) {
  const url = new URL(connectionString);
  if (!["postgres:", "postgresql:"].includes(url.protocol) || !["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) || url.pathname !== "/futuremint_test") throw new Error("AI gate tests require isolated localhost futuremint_test database");
}
const schema = "ai_test_" + randomUUID().replaceAll("-", "");
let admin: Pool; let pool: Pool; let secondPool: Pool;
const addUser = async () => (await new AuthService(new PostgresRepository(pool)).register({ email: randomUUID() + "@example.com", password: "synthetic-test-2026" })).account.id;
describe.skipIf(!connectionString)("PostgreSQL AI admission across replicas", () => {
  beforeAll(async () => {
    admin = new Pool({ connectionString }); await admin.query(`CREATE SCHEMA ${schema}`);
    pool = new Pool({ connectionString, options: `-c search_path=${schema}` }); secondPool = new Pool({ connectionString, options: `-c search_path=${schema}` });
    await runMigrations(pool); expect(await runMigrations(secondPool)).toEqual([]);
  }, 30000);
  beforeEach(async () => { await pool.query("TRUNCATE ai_operation_leases, ai_usage_daily"); });
  afterAll(async () => { await Promise.all([pool?.end(), secondPool?.end()]); if (admin) { await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); await admin.end(); } });
  it("atomically admits only one concurrent operation and preserves quota after busy rejection", async () => {
    const first = await addUser(); const second = await addUser(); const limits = { dailyUser: 2, dailyGlobal: 3, concurrency: 1, leaseMs: 17000 };
    const a = new AiRequestGate(limits, pool); const b = new AiRequestGate(limits, secondPool);
    const results = await Promise.allSettled([a.acquire(first), b.acquire(second)]);
    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    expect((results.find((result) => result.status === "rejected") as PromiseRejectedResult).reason).toMatchObject({ code: "ai_busy" });
    expect((await pool.query("SELECT request_count FROM ai_usage_daily WHERE subject='global'")).rows[0].request_count).toBe(1);
    for (const result of results) if (result.status === "fulfilled") await result.value();
    await (await b.acquire(second))(); await (await a.acquire(first))();
    await expect(a.acquire(first)).rejects.toMatchObject({ code: "ai_daily_limit_reached" });
  });
  it("expires crashed replicas' leases and clears deleted user's private counters", async () => {
    const user = await addUser(); const limits = { dailyUser: 10, dailyGlobal: 10, concurrency: 1, leaseMs: 1000 };
    let now = Date.parse("2026-10-01T00:00:00Z"); const a = new AiRequestGate(limits, pool, () => now); const b = new AiRequestGate(limits, secondPool, () => now);
    await a.acquire(user); now += 1001; await b.acquire(user);
    await pool.query("DELETE FROM accounts WHERE user_id=$1", [user]);
    expect((await pool.query("SELECT count(*)::int AS count FROM ai_operation_leases")).rows[0].count).toBe(0);
    expect((await pool.query("SELECT count(*)::int AS count FROM ai_usage_daily WHERE user_id IS NOT NULL")).rows[0].count).toBe(0);
    expect((await pool.query("SELECT request_count FROM ai_usage_daily WHERE subject='global'")).rows[0].request_count).toBe(2);
  });
});
