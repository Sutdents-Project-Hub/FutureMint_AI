import { createHash } from "node:crypto";
import { describe, expect, it, vi } from "vitest";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { InMemoryEligibilityStore } from "../../src/adapters/eligibilityStore";
import { AuthService, aiConsentPolicyVersion } from "../../src/auth/authService";
import type { GuardianMailContext, MailPurpose } from "../../src/auth/accountMailer";
import { servicePolicyVersion } from "../../src/contracts/servicePolicy";
const credentials = { email: "minor@example.invalid", password: "synthetic2026" };
const declaration = (ageBand: "under-15" | "15-17" | "18-plus") => ({ ageBand, policyVersion: servicePolicyVersion, accepted: true as const });
const hash = (token: string) => createHash("sha256").update(token).digest("base64url");
function fixture() {
  const repository = new InMemoryRepository(), store = new InMemoryEligibilityStore();
  let now = new Date("2026-10-01T00:00:00Z");
  const mail: { to: string; purpose: MailPurpose; token: string; context?: GuardianMailContext }[] = [];
  const options = { requireEligibility: true, eligibilityStore: store, mailer: { send: async (to: string, purpose: MailPurpose, token: string, context?: GuardianMailContext) => { mail.push({ to, purpose, token, context }); } } };
  const service = new AuthService(repository, () => now, options);
  const register = () => service.register({ ...credentials, ageDeclaration: declaration("15-17") });
  const approve = async (token: string) => service.confirmGuardian({ token, policyVersion: servicePolicyVersion, adult: true, legalGuardian: true, accepted: true });
  return { service, repository, store, mail, register, approve, options, advance: () => { now = new Date(now.getTime() + 31 * 60_000); } };
}
describe("age and guardian service eligibility", () => {
  it("rejects missing, underage and stale declarations before creating accounts or sending mail", async () => {
    const f = fixture();
    await expect(f.service.register(credentials)).rejects.toMatchObject({ code: "age_declaration_required" });
    await expect(f.service.register({ ...credentials, ageDeclaration: declaration("under-15") })).rejects.toMatchObject({ code: "age_not_supported" });
    await expect(f.service.register({ ...credentials, ageDeclaration: { ...declaration("18-plus"), policyVersion: "old" } })).rejects.toMatchObject({ code: "service_policy_changed" });
    expect(await f.repository.findAccountByEmail(credentials.email)).toBeNull(); expect(f.mail).toHaveLength(0);
  });
  it("keeps existing users pending until current adult declaration", async () => {
    const f = fixture(), legacy = new AuthService(f.repository, undefined, { eligibilityStore: f.store });
    const { account } = await legacy.register(credentials);
    expect(await f.service.getEligibility(account.id)).toMatchObject({ status: "declaration-required", canWrite: false });
    await expect(f.service.requireServiceEligibility(account.id)).rejects.toMatchObject({ code: "age_declaration_required" });
    expect(await f.service.declareAge(account.id, declaration("18-plus"))).toMatchObject({ status: "eligible", guardianStatus: "not-required" });
    await expect(f.service.requireServiceEligibility(account.id)).resolves.toBeUndefined();
  });
  it("requires a distinct guardian email and locks minor age declarations", async () => {
    const f = fixture(); const { account } = await f.register();
    expect(await f.service.getEligibility(account.id)).toMatchObject({ status: "guardian-required", canWrite: false });
    await expect(f.service.requestGuardian(account.id, { email: " MINOR@example.invalid " })).rejects.toMatchObject({ code: "guardian_email_invalid" });
    await expect(f.service.declareAge(account.id, declaration("18-plus"))).rejects.toMatchObject({ code: "age_declaration_locked" });
  });
  it("hashes one-use tokens and binds guardian, policy and explicit adult/guardian attestations", async () => {
    const f = fixture(); const { account } = await f.register(); await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" });
    const token = f.mail.at(-1)!.token;
    expect(f.mail.at(-1)!.context).toEqual({ requesterEmail: credentials.email });
    expect(await f.store.findToken(token)).toBeNull();
    expect(await f.store.findToken(hash(token))).toMatchObject({ userId: account.id, guardianEmail: "guardian@example.invalid", policyVersion: servicePolicyVersion, purpose: "guardian-approve" });
    await expect(f.service.confirmGuardian({ token, policyVersion: servicePolicyVersion, adult: false, legalGuardian: true, accepted: true } as never)).rejects.toHaveProperty("issues");
    await expect(f.approve(token)).resolves.toEqual({ approved: true });
    await expect(f.approve(token)).rejects.toMatchObject({ code: "invalid_action_token" });
    const publicStatus = await f.service.getEligibility(account.id); expect(publicStatus).toMatchObject({ status: "eligible", canWrite: true }); expect(publicStatus).not.toHaveProperty("guardianEmail");
    expect(await f.repository.getFamilyMembership(account.id)).toBeNull(); expect(await f.service.getAiConsent(account.id)).toMatchObject({ granted: false });
  });
  it("rejects rotated, expired, wrong-purpose and policy-stale tokens", async () => {
    const f = fixture(); const { account } = await f.register(); await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); const old = f.mail.at(-1)!.token;
    await f.service.requestGuardian(account.id, { email: "newguardian@example.invalid" }); const token = f.mail.at(-1)!.token;
    await expect(f.approve(old)).rejects.toMatchObject({ code: "invalid_action_token" });
    await expect(f.service.withdrawGuardian({ token })).rejects.toMatchObject({ code: "invalid_action_token" });
    const changed = new AuthService(f.repository, undefined, { ...f.options, servicePolicyVersion: "next" });
    await expect(changed.confirmGuardian({ token, policyVersion: "next", adult: true, legalGuardian: true, accepted: true })).rejects.toMatchObject({ code: "invalid_action_token" });
    f.advance(); await expect(f.approve(token)).rejects.toMatchObject({ code: "invalid_action_token" });
  });
  it("allows only one successful concurrent approval", async () => {
    const f = fixture(); const { account } = await f.register(); await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); const token = f.mail.at(-1)!.token;
    const results = await Promise.allSettled([f.approve(token), f.approve(token)]); expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
  });
  it("withdrawal stops writes/AI but preserves authentication/deletion and invalidates old AI after reapproval", async () => {
    const f = fixture(); const { account, token: session } = await f.register(); await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); await f.approve(f.mail.at(-1)!.token);
    await f.service.setAiConsent(account.id, { granted: true, policyVersion: aiConsentPolicyVersion }); const token = f.mail.at(-1)!.token;
    await expect(f.service.withdrawGuardian({ token })).resolves.toEqual({ withdrawn: true });
    await expect(f.service.withdrawGuardian({ token })).rejects.toMatchObject({ code: "invalid_action_token" });
    await expect(f.service.requireServiceEligibility(account.id)).rejects.toMatchObject({ code: "guardian_consent_required" });
    await expect(f.service.requireAiConsent(account.id)).rejects.toMatchObject({ code: "guardian_consent_required" });
    expect(await f.service.authenticate(session)).toHaveProperty("id", account.id);
    f.advance(); await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); await f.approve(f.mail.at(-1)!.token);
    expect(await f.service.getAiConsent(account.id)).toMatchObject({ granted: false });
    await f.service.deleteAccount(account.id, { password: credentials.password }); expect(await f.store.get(account.id)).toBeNull(); expect(await f.store.findToken(hash(f.mail.at(-1)!.token))).toBeNull();
  });
  it("renews expired guardian withdrawal links and hides unknown accounts/address mismatches", async () => {
    const f = fixture(); const { account } = await f.register(); await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); await f.approve(f.mail.at(-1)!.token);
    const token = f.mail.at(-1)!.token; f.advance(); await expect(f.service.withdrawGuardian({ token })).rejects.toMatchObject({ code: "invalid_action_token" }); const count = f.mail.length;
    expect(await f.service.requestGuardianWithdrawal({ accountEmail: "missing@example.invalid", guardianEmail: "guardian@example.invalid" })).toEqual({ accepted: true });
    expect(await f.service.requestGuardianWithdrawal({ accountEmail: credentials.email, guardianEmail: "wrong@example.invalid" })).toEqual({ accepted: true }); expect(f.mail).toHaveLength(count);
    await f.service.requestGuardianWithdrawal({ accountEmail: credentials.email, guardianEmail: "guardian@example.invalid" }); await expect(f.service.withdrawGuardian({ token: f.mail.at(-1)!.token })).resolves.toEqual({ withdrawn: true });
  });
  it("serializes account withdrawal against approval and rejects stale tokens", async () => {
    const f = fixture(); const { account } = await f.register(); await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); const token = f.mail.at(-1)!.token;
    await Promise.allSettled([f.approve(token), f.service.withdrawGuardianByAccount(account.id)]);
    expect(await f.service.getEligibility(account.id)).toMatchObject({ status: "guardian-withdrawn", canWrite: false }); await expect(f.approve(token)).rejects.toMatchObject({ code: "invalid_action_token" });
  });
  it("cannot grant AI across a concurrent guardian withdrawal, independent of clock ordering", async () => {
    const f = fixture(); const { account } = await f.register();
    await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); await f.approve(f.mail.at(-1)!.token);
    let entered!: () => void, release!: () => void;
    const saving = new Promise<void>((resolve) => { entered = resolve; });
    const waiting = new Promise<void>((resolve) => { release = resolve; });
    const original = f.repository.saveAiConsent.bind(f.repository);
    const stub = vi.spyOn(f.repository, "saveAiConsent").mockImplementationOnce(async (...args) => { entered(); await waiting; return original(...args); });
    const grant = f.service.setAiConsent(account.id, { granted: true, policyVersion: aiConsentPolicyVersion });
    await saving; await f.service.withdrawGuardianByAccount(account.id); release();
    expect(await grant).toMatchObject({ granted: false }); stub.mockRestore();
    await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); await f.approve(f.mail.at(-1)!.token);
    expect(await f.service.getAiConsent(account.id)).toMatchObject({ granted: false });
    await expect(f.service.setAiConsent(account.id, { granted: true, policyVersion: aiConsentPolicyVersion })).resolves.toMatchObject({ granted: true });
  });
  it("preserves earlier pending approval after failed mail rotation", async () => {
    const f = fixture(); const { account } = await f.register();
    await f.service.requestGuardian(account.id, { email: "guardian@example.invalid" }); const token = f.mail.at(-1)!.token;
    const before = await f.store.get(account.id);
    const failing = new AuthService(f.repository, undefined, { ...f.options, mailer: { send: async () => { throw new Error("synthetic failure"); } } });
    await expect(failing.requestGuardian(account.id, { email: "failed@example.invalid" })).rejects.toMatchObject({ code: "mail_unavailable" });
    expect(await f.store.get(account.id)).toEqual(before); await expect(f.approve(token)).resolves.toEqual({ approved: true });
  });
  it("requires current provider policy on every AI grant and allows unversioned withdrawal", async () => {
    const f = fixture(); const { account } = await f.service.register({ ...credentials, ageDeclaration: declaration("18-plus") });
    await expect(f.service.setAiConsent(account.id, { granted: true })).rejects.toMatchObject({ code: "ai_policy_changed" });
    await expect(f.service.setAiConsent(account.id, { granted: true, policyVersion: "third-party-ai-v1" })).rejects.toMatchObject({ code: "ai_policy_changed" });
    await f.service.setAiConsent(account.id, { granted: true, policyVersion: aiConsentPolicyVersion });
    const changed = new AuthService(f.repository, undefined, { ...f.options, aiPolicyVersion: "openai-new-model" }); expect(await changed.getAiConsent(account.id)).toMatchObject({ granted: false, policyVersion: "openai-new-model" });
    await expect(changed.setAiConsent(account.id, { granted: false })).resolves.toMatchObject({ granted: false });
  });
});
