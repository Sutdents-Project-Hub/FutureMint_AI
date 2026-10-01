import { createHash, randomUUID } from "node:crypto";
import type { Pool } from "pg";
import { DomainError } from "../contracts/errors";

export interface AiLimits { dailyUser: number; dailyGlobal: number; concurrency: number; leaseMs: number; }
export const readAiLimits = (env: NodeJS.ProcessEnv = process.env): AiLimits => {
  const number = (name: string, fallback: number, max: number): number => {
    const value = env[name] ? Number(env[name]) : fallback;
    if (!Number.isInteger(value) || value < 1 || value > max) throw new Error(`${name} must be a bounded positive integer`);
    return value;
  };
  return { dailyUser: number("AI_DAILY_USER_LIMIT", 30, 10000), dailyGlobal: number("AI_DAILY_GLOBAL_LIMIT", 300, 1000000),
    concurrency: number("AI_MAX_CONCURRENCY", 5, 100), leaseMs: number("AI_OPERATION_TIMEOUT_MS", 12000, 15000) + 5000 };
};
const taipeiDay = (time: number): string => {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(time);
  return ["year", "month", "day"].map((type) => parts.find((part) => part.type === type)!.value).join("-");
};
const subject = (userId: string) => createHash("sha256").update(userId).digest("hex");
const quotaExceeded = () => new DomainError("ai_daily_limit_reached", "今日 AI 使用額度已用完，請明日再試；仍可使用手動功能。", 429, false);
const busy = () => new DomainError("ai_busy", "AI 目前忙碌，請稍後再試。", 429, true);

export class AiRequestGate {
  private daily = new Map<string, number>();
  private leases = new Map<string, number>();
  constructor(private readonly limits: AiLimits, private readonly pool?: Pool, private readonly now: () => number = Date.now) {}
  async acquire(userId: string): Promise<() => Promise<void>> {
    const now = this.now(); const day = taipeiDay(now); const user = subject(userId); const lease = randomUUID();
    if (!this.pool) {
      for (const [id, expires] of this.leases) if (expires <= now) this.leases.delete(id);
      for (const key of this.daily.keys()) if (!key.startsWith(day + ":")) this.daily.delete(key);
      if ((this.daily.get(day + ":" + user) ?? 0) >= this.limits.dailyUser || (this.daily.get(day + ":global") ?? 0) >= this.limits.dailyGlobal) throw quotaExceeded();
      if (this.leases.size >= this.limits.concurrency) throw busy();
      for (const key of [day + ":" + user, day + ":global"]) this.daily.set(key, (this.daily.get(key) ?? 0) + 1);
      this.leases.set(lease, now + this.limits.leaseMs);
      return async () => { this.leases.delete(lease); };
    }
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("SET LOCAL lock_timeout = '5s'");
      await client.query("SELECT pg_advisory_xact_lock(hashtext('futuremint-ai-admission'))");
      await client.query("DELETE FROM ai_operation_leases WHERE expires_at <= $1", [new Date(now).toISOString()]);
      const counts = await client.query<{ subject: string; request_count: number }>("SELECT subject, request_count FROM ai_usage_daily WHERE usage_day = $1 AND subject IN ($2, 'global')", [day, user]);
      if ((counts.rows.find((row) => row.subject === user)?.request_count ?? 0) >= this.limits.dailyUser || (counts.rows.find((row) => row.subject === "global")?.request_count ?? 0) >= this.limits.dailyGlobal) throw quotaExceeded();
      const pending = await client.query<{ count: number }>("SELECT count(*)::int AS count FROM ai_operation_leases");
      if (pending.rows[0].count >= this.limits.concurrency) throw busy();
      await client.query(`INSERT INTO ai_usage_daily (usage_day,subject,user_id,request_count) VALUES ($1,$2,$3,1),($1,'global',NULL,1)
        ON CONFLICT (usage_day,subject) DO UPDATE SET request_count=ai_usage_daily.request_count+1`, [day, user, userId]);
      await client.query("INSERT INTO ai_operation_leases (id,user_id,expires_at) VALUES ($1,$2,$3)", [lease, userId, new Date(now + this.limits.leaseMs).toISOString()]);
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      if (error instanceof DomainError) throw error;
      throw new DomainError("ai_admission_unavailable", "目前無法確認 AI 使用額度，請稍後再試。", 503, true);
    } finally { client.release(); }
    return async () => { await this.pool!.query("DELETE FROM ai_operation_leases WHERE id = $1", [lease]); };
  }
  async maintain(): Promise<void> {
    if (this.pool) {
      await this.pool.query("DELETE FROM ai_operation_leases WHERE expires_at <= NOW()");
      await this.pool.query("DELETE FROM ai_usage_daily WHERE usage_day < $1::date - 7", [taipeiDay(this.now())]);
    }
  }
}
