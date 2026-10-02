import type { Pool, PoolClient } from "pg";
import type { EligibilityRecord, GuardianActionToken } from "../contracts/servicePolicy";
import type { SqlClient } from "./postgresRepository";

export interface EligibilityStore {
  withUserTransaction<T>(userId: string, operation: (store: EligibilityStore) => Promise<T>): Promise<T>;
  get(userId: string): Promise<EligibilityRecord | null>;
  save(record: EligibilityRecord): Promise<void>;
  findToken(hash: string): Promise<GuardianActionToken | null>;
  saveToken(token: GuardianActionToken): Promise<void>;
  deleteToken(hash: string): Promise<void>;
  clearTokens(userId: string): Promise<void>;
  deleteUser(userId: string): Promise<void>;
}
export class InMemoryEligibilityStore implements EligibilityStore {
  private records = new Map<string, EligibilityRecord>();
  private tokens = new Map<string, GuardianActionToken>();
  private locks = new Map<string, Promise<void>>();
  async withUserTransaction<T>(userId: string, operation: (store: EligibilityStore) => Promise<T>): Promise<T> {
    const previous = this.locks.get(userId) ?? Promise.resolve();
    let release!: () => void;
    const lock = new Promise<void>((resolve) => { release = resolve; });
    const queued = previous.then(() => lock);
    this.locks.set(userId, queued);
    await previous;
    const previousRecord = this.records.get(userId);
    const previousTokens = [...this.tokens.values()].filter((token) => token.userId === userId);
    try { return await operation(this); }
    catch (error) {
      if (previousRecord) this.records.set(userId, previousRecord); else this.records.delete(userId);
      await this.clearTokens(userId);
      for (const token of previousTokens) this.tokens.set(token.tokenHash, token);
      throw error;
    }
    finally { release(); if (this.locks.get(userId) === queued) this.locks.delete(userId); }
  }
  async get(userId: string) { const record = this.records.get(userId); return record ? { ...record } : null; }
  async save(record: EligibilityRecord) { this.records.set(record.userId, { ...record }); }
  async findToken(hash: string) { const token = this.tokens.get(hash); return token ? { ...token } : null; }
  async saveToken(token: GuardianActionToken) {
    for (const [hash, current] of this.tokens) if (current.userId === token.userId && current.purpose === token.purpose) this.tokens.delete(hash);
    this.tokens.set(token.tokenHash, { ...token });
  }
  async deleteToken(hash: string) { this.tokens.delete(hash); }
  async clearTokens(userId: string) { for (const [hash, token] of this.tokens) if (token.userId === userId) this.tokens.delete(hash); }
  async deleteUser(userId: string) { this.records.delete(userId); await this.clearTokens(userId); }
}
const timestamp = (value: unknown): string | null => value ? new Date(value as string | Date).toISOString() : null;
export class PostgresEligibilityStore implements EligibilityStore {
  constructor(private readonly pool: Pool, private readonly client: SqlClient = pool, private readonly transaction = false) {}
  async withUserTransaction<T>(userId: string, operation: (store: EligibilityStore) => Promise<T>): Promise<T> {
    if (this.transaction) return operation(this);
    const client: PoolClient = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // Serialize declaration, token rotation, approval, withdrawal and account deletion across replicas.
      await client.query("SELECT user_id FROM accounts WHERE user_id = $1 FOR UPDATE", [userId]);
      const result = await operation(new PostgresEligibilityStore(this.pool, client, true));
      await client.query("COMMIT");
      return result;
    } catch (error) { await client.query("ROLLBACK"); throw error; }
    finally { client.release(); }
  }
  async get(userId: string): Promise<EligibilityRecord | null> {
    const { rows } = await this.client.query("SELECT * FROM service_eligibilities WHERE user_id = $1", [userId]);
    const r = rows[0];
    return r ? { userId: r.user_id as string, ageBand: r.age_band as EligibilityRecord["ageBand"], policyVersion: r.policy_version as string,
      declaredAt: timestamp(r.declared_at)!, guardianStatus: r.guardian_status as EligibilityRecord["guardianStatus"],
      guardianEmail: r.guardian_email as string | null, guardianConsentMethod: (r.guardian_consent_method as EligibilityRecord["guardianConsentMethod"]) ?? null, guardianApprovedAt: timestamp(r.guardian_approved_at), guardianWithdrawnAt: timestamp(r.guardian_withdrawn_at), revision: Number(r.revision), aiConsentRevision: r.ai_consent_revision == null ? null : Number(r.ai_consent_revision) } : null;
  }
  async save(r: EligibilityRecord): Promise<void> {
    await this.client.query(`INSERT INTO service_eligibilities (user_id,age_band,policy_version,declared_at,guardian_status,guardian_email,guardian_approved_at,guardian_withdrawn_at,revision,ai_consent_revision,guardian_consent_method)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) ON CONFLICT (user_id) DO UPDATE SET age_band=EXCLUDED.age_band,policy_version=EXCLUDED.policy_version,declared_at=EXCLUDED.declared_at,guardian_status=EXCLUDED.guardian_status,guardian_email=EXCLUDED.guardian_email,guardian_approved_at=EXCLUDED.guardian_approved_at,guardian_withdrawn_at=EXCLUDED.guardian_withdrawn_at,revision=EXCLUDED.revision,ai_consent_revision=EXCLUDED.ai_consent_revision,guardian_consent_method=EXCLUDED.guardian_consent_method`,
      [r.userId,r.ageBand,r.policyVersion,r.declaredAt,r.guardianStatus,r.guardianEmail,r.guardianApprovedAt,r.guardianWithdrawnAt,r.revision,r.aiConsentRevision,r.guardianConsentMethod ?? null]);
  }
  async findToken(hash: string): Promise<GuardianActionToken | null> {
    const { rows } = await this.client.query("SELECT * FROM guardian_action_tokens WHERE token_hash = $1", [hash]);
    const r = rows[0];
    return r ? { tokenHash: r.token_hash as string, userId: r.user_id as string, purpose: r.purpose as GuardianActionToken["purpose"], policyVersion: r.policy_version as string,
      guardianEmail: r.guardian_email as string, revision: Number(r.revision), expiresAt: timestamp(r.expires_at)! } : null;
  }
  async saveToken(t: GuardianActionToken): Promise<void> {
    await this.client.query(`INSERT INTO guardian_action_tokens (token_hash,user_id,purpose,policy_version,guardian_email,revision,expires_at) VALUES ($1,$2,$3,$4,$5,$6,$7)
      ON CONFLICT (user_id,purpose) DO UPDATE SET token_hash=EXCLUDED.token_hash,policy_version=EXCLUDED.policy_version,guardian_email=EXCLUDED.guardian_email,revision=EXCLUDED.revision,expires_at=EXCLUDED.expires_at`,
      [t.tokenHash,t.userId,t.purpose,t.policyVersion,t.guardianEmail,t.revision,t.expiresAt]);
  }
  async deleteToken(hash: string) { await this.client.query("DELETE FROM guardian_action_tokens WHERE token_hash = $1", [hash]); }
  async clearTokens(userId: string) { await this.client.query("DELETE FROM guardian_action_tokens WHERE user_id = $1", [userId]); }
  async deleteUser(userId: string) { await this.client.query("DELETE FROM service_eligibilities WHERE user_id = $1", [userId]); }
}
