import { randomUUID } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { PostgresRepository } from "../../src/adapters/postgresRepository";
import { PostgresEligibilityStore } from "../../src/adapters/eligibilityStore";
import { AuthService, aiConsentPolicyVersion } from "../../src/auth/authService";
import { servicePolicyVersion } from "../../src/contracts/servicePolicy";
import type { MailPurpose } from "../../src/auth/accountMailer";
const connectionString = process.env.FUTUREMINT_TEST_DATABASE_URL;
if (connectionString) {
  const url = new URL(connectionString);
  if (!["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) || url.pathname !== "/futuremint_test") throw new Error("Eligibility integration requires localhost futuremint_test database");
}
const schema = `eligibility_${randomUUID().replaceAll("-", "")}`;
let admin: Pool, pool: Pool, otherPool: Pool;
let repository: PostgresRepository, store: PostgresEligibilityStore;
const mail: { purpose: MailPurpose; token: string }[] = [];
let service: AuthService, second: AuthService;
const approveInput = (token: string) => ({ token, policyVersion: servicePolicyVersion, adult: true as const, legalGuardian: true as const, accepted: true as const });
async function minor() {
  const result = await service.register({ email: `${randomUUID()}@example.invalid`, password: "synthetic-test2026", ageDeclaration: { ageBand: "15-17", policyVersion: servicePolicyVersion, accepted: true } });
  await service.requestGuardian(result.account.id, { email: `${randomUUID()}@example.invalid` });
  return { ...result, approval: mail.at(-1)!.token };
}
describe.skipIf(!connectionString)("isolated PostgreSQL guardian eligibility", () => {
  beforeAll(async () => {
    admin = new Pool({ connectionString }); await admin.query(`CREATE SCHEMA ${schema}`);
    pool = new Pool({ connectionString, options: `-c search_path=${schema}`, max: 6 }); otherPool = new Pool({ connectionString, options: `-c search_path=${schema}`, max: 6 });
    for (const file of (await readdir(path.resolve("migrations"))).filter((f) => /^\d+.*\.sql$/.test(f)).sort()) await pool.query(await readFile(path.resolve("migrations", file), "utf8"));
    repository = new PostgresRepository(pool); store = new PostgresEligibilityStore(pool);
    const mailer = { send: async (_to: string, purpose: MailPurpose, token: string) => { mail.push({ purpose, token }); } };
    service = new AuthService(repository, undefined, { eligibilityStore: store, requireEligibility: true, mailer });
    second = new AuthService(new PostgresRepository(otherPool), undefined, { eligibilityStore: new PostgresEligibilityStore(otherPool), requireEligibility: true, mailer });
  }, 30000);
  afterAll(async () => { await Promise.all([pool?.end(), otherPool?.end()]); if (admin) { await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`); await admin.end(); } });
  it("persists in-app declarations without SMTP across independent PostgreSQL pools", async () => {
    const noMail = new AuthService(repository, undefined, { eligibilityStore: store, requireEligibility: true });
    const another = new AuthService(new PostgresRepository(otherPool), undefined, { eligibilityStore: new PostgresEligibilityStore(otherPool), requireEligibility: true });
    const { account } = await noMail.register({ email: `${randomUUID()}@example.invalid`, password: "synthetic-test2026", ageDeclaration: { ageBand: "15-17", policyVersion: servicePolicyVersion, accepted: true } });
    const input = { policyVersion: servicePolicyVersion, adult: true, legalGuardian: true, accepted: true };
    await Promise.all([noMail.confirmGuardianInApp(account.id, input), another.confirmGuardianInApp(account.id, input)]);
    const approved = (await pool.query("SELECT * FROM service_eligibilities WHERE user_id=$1", [account.id])).rows[0];
    expect(approved).toMatchObject({ guardian_status: "approved", guardian_email: null, guardian_consent_method: "in-app", revision: 2, ai_consent_revision: null });
    expect(await another.getEligibility(account.id)).toMatchObject({ guardianConsentMethod: "in-app", canWrite: true });
    await noMail.setAiConsent(account.id, { granted: true, policyVersion: aiConsentPolicyVersion });
    await another.withdrawGuardianByAccount(account.id); await noMail.confirmGuardianInApp(account.id, input);
    expect(await another.getAiConsent(account.id)).toMatchObject({ granted: false });
    expect((await store.get(account.id))?.revision).toBe(4);
    expect((await repository.findAccountById(account.id))?.emailVerifiedAt).toBeFalsy();
  });
  it("atomically approves across independent pools, grants without FK lock deadlocks, revokes and cascades deletion", async () => {
    const account = await minor();
    const results = await Promise.allSettled([service.confirmGuardian(approveInput(account.approval)), second.confirmGuardian(approveInput(account.approval))]);
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    await expect(service.setAiConsent(account.account.id, { granted: true, policyVersion: aiConsentPolicyVersion })).resolves.toMatchObject({ granted: true });
    const row = (await pool.query("SELECT * FROM service_eligibilities WHERE user_id=$1", [account.account.id])).rows[0]; expect(row.ai_consent_revision).toBe(row.revision);
    await second.withdrawGuardian({ token: mail.at(-1)!.token });
    expect(await service.getAiConsent(account.account.id)).toMatchObject({ granted: false });
    await expect(service.requireServiceEligibility(account.account.id)).rejects.toMatchObject({ code: "guardian_consent_required" });
    await service.deleteAccount(account.account.id, { password: "synthetic-test2026" }); expect(await store.get(account.account.id)).toBeNull();
    expect((await pool.query("SELECT count(*)::int AS count FROM guardian_action_tokens WHERE user_id=$1", [account.account.id])).rows[0].count).toBe(0);
  }, 15000);
  it("serializes approval against account withdrawal and ignores stale tokens across replicas", async () => {
    const account = await minor();
    await Promise.allSettled([service.confirmGuardian(approveInput(account.approval)), second.withdrawGuardianByAccount(account.account.id)]);
    expect(await service.getEligibility(account.account.id)).toMatchObject({ status: "guardian-withdrawn", canWrite: false });
    await expect(second.confirmGuardian(approveInput(account.approval))).rejects.toMatchObject({ code: "invalid_action_token" });
  });
  it("fails closed when an AI grant races guardian withdrawal across pools", async () => {
    const account = await minor(); await service.confirmGuardian(approveInput(account.approval));
    let entered!: () => void, release!: () => void;
    const saving = new Promise<void>((resolve) => { entered = resolve; });
    const waiting = new Promise<void>((resolve) => { release = resolve; });
    const original = repository.saveAiConsent.bind(repository);
    const stub = vi.spyOn(repository, "saveAiConsent").mockImplementationOnce(async (...args) => { entered(); await waiting; return original(...args); });
    try {
      const grant = service.setAiConsent(account.account.id, { granted: true, policyVersion: aiConsentPolicyVersion });
      await saving; await second.withdrawGuardianByAccount(account.account.id); release();
      expect(await grant).toMatchObject({ granted: false });
      expect(await service.getAiConsent(account.account.id)).toMatchObject({ granted: false });
    } finally { release(); stub.mockRestore(); }
  });
  it("leaves failed-mail requests pending and rolls back hash/state rotation without plaintext persistence", async () => {
    const account = await minor(); const record = (await store.get(account.account.id))!;
    const failing = new AuthService(repository, undefined, { eligibilityStore: store, requireEligibility: true, mailer: { send: async () => { throw new Error("synthetic transport failure"); } } });
    await expect(failing.requestGuardian(account.account.id, { email: "failed@example.invalid" })).rejects.toMatchObject({ code: "mail_unavailable" });
    expect(await store.get(account.account.id)).toEqual(record);
    expect((await pool.query("SELECT token_hash FROM guardian_action_tokens WHERE user_id=$1 AND purpose='guardian-approve'", [account.account.id])).rows[0].token_hash).not.toBe(account.approval);
    await expect(service.confirmGuardian(approveInput(account.approval))).resolves.toMatchObject({ approved: true });
  });
});
