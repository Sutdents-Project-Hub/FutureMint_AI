import { Pool } from "pg";
import { describe, expect, it } from "vitest";
import { PostgresEligibilityStore } from "../../src/adapters/eligibilityStore";
import type { SqlClient } from "../../src/adapters/postgresRepository";
import type { EligibilityRecord } from "../../src/contracts/servicePolicy";
class Client implements SqlClient {
  queries: { text: string; values?: unknown[] }[] = [];
  rows: Record<string, unknown>[] = [];
  async query<T extends Record<string, unknown>>(text: string, values?: unknown[]) {
    this.queries.push({ text, values });
    return { rows: this.rows as T[] };
  }
}
describe("guardian method SQL persistence contract", () => {
  it("round trips explicit declaration method and preserves null for legacy unclassified records", async () => {
    const client = new Client(), pool = new Pool();
    const store = new PostgresEligibilityStore(pool, client);
    const record: EligibilityRecord = { userId: "synthetic-user", ageBand: "15-17", policyVersion: "synthetic-policy", declaredAt: "2026-10-03T00:00:00.000Z", guardianStatus: "approved", guardianEmail: null, guardianApprovedAt: "2026-10-03T00:00:00.000Z", guardianWithdrawnAt: null, revision: 2, aiConsentRevision: null, guardianConsentMethod: "in-app" };
    await store.save(record);
    expect(client.queries[0].text).toContain("guardian_consent_method=EXCLUDED.guardian_consent_method");
    expect(client.queries[0].values?.at(-1)).toBe("in-app");
    client.rows = [{ user_id: record.userId, age_band: record.ageBand, policy_version: record.policyVersion, declared_at: record.declaredAt, guardian_status: record.guardianStatus, guardian_email: null, guardian_approved_at: record.guardianApprovedAt, guardian_withdrawn_at: null, revision: 2, ai_consent_revision: null, guardian_consent_method: "in-app" }];
    expect(await store.get(record.userId)).toEqual(record);
    client.rows[0].guardian_consent_method = "email";
    expect((await store.get(record.userId))?.guardianConsentMethod).toBe("email");
    client.rows[0].guardian_consent_method = null;
    expect((await store.get(record.userId))?.guardianConsentMethod).toBeNull();
    await store.save({ ...record, guardianConsentMethod: undefined });
    expect(client.queries.at(-1)?.values?.at(-1)).toBeNull();
    await pool.end();
  });
});
