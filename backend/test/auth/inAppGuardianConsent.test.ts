import { describe, expect, it } from "vitest";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { InMemoryEligibilityStore } from "../../src/adapters/eligibilityStore";
import { AuthService, aiConsentPolicyVersion } from "../../src/auth/authService";
import { servicePolicyVersion } from "../../src/contracts/servicePolicy";
const input = { policyVersion: servicePolicyVersion, adult: true, legalGuardian: true, accepted: true };
const declaration = (ageBand: "15-17" | "18-plus") => ({ ageBand, policyVersion: servicePolicyVersion, accepted: true as const });
async function fixture(ageBand: "15-17" | "18-plus" = "15-17") {
  const repository = new InMemoryRepository(), store = new InMemoryEligibilityStore();
  const service = new AuthService(repository, undefined, { eligibilityStore: store, requireEligibility: true });
  const registered = await service.register({ email: "in-app@example.invalid", password: "synthetic2026", ageDeclaration: declaration(ageBand) });
  return { repository, store, service, ...registered };
}
describe("guardian declaration on the child's device without email", () => {
  it("records the method and permits eligible use without verifying email, sharing or granting AI", async () => {
    const f = await fixture(), before = (await f.store.get(f.account.id))!;
    await f.store.saveToken({ userId: f.account.id, tokenHash: "synthetic-token-hash", purpose: "guardian-approve", policyVersion: servicePolicyVersion, guardianEmail: "guardian@example.invalid", revision: before.revision, expiresAt: "2027-01-01T00:00:00Z" });
    expect(await f.service.confirmGuardianInApp(f.account.id, input)).toMatchObject({ canWrite: true, guardianStatus: "approved", guardianConsentMethod: "in-app" });
    expect(await f.store.get(f.account.id)).toMatchObject({ ageBand: "15-17", policyVersion: before.policyVersion, declaredAt: before.declaredAt, guardianEmail: null, guardianConsentMethod: "in-app", revision: before.revision + 1, aiConsentRevision: null });
    expect(await f.store.findToken("synthetic-token-hash")).toBeNull();
    expect(await f.service.authenticate(f.token)).toMatchObject({ emailVerified: false, verificationRequired: false });
    expect((await f.repository.findAccountById(f.account.id))?.emailVerifiedAt).toBeUndefined();
    expect(await f.repository.getFamilyMembership(f.account.id)).toBeNull();
    expect(await f.service.getAiConsent(f.account.id)).toMatchObject({ granted: false });
  });
  it("rejects every missing/false declaration, stale policy, adult and missing account without state changes", async () => {
    const f = await fixture(), before = await f.store.get(f.account.id);
    for (const field of ["adult", "legalGuardian", "accepted"] as const) {
      await expect(f.service.confirmGuardianInApp(f.account.id, { ...input, [field]: false })).rejects.toHaveProperty("issues");
      const missing: Record<string, unknown> = { ...input }; delete missing[field];
      await expect(f.service.confirmGuardianInApp(f.account.id, missing)).rejects.toHaveProperty("issues");
    }
    await expect(f.service.confirmGuardianInApp(f.account.id, { ...input, policyVersion: "old" })).rejects.toMatchObject({ code: "service_policy_changed" });
    await expect(f.service.confirmGuardianInApp("missing", input)).rejects.toMatchObject({ code: "unauthorized" });
    const adult = await fixture("18-plus");
    await expect(adult.service.confirmGuardianInApp(adult.account.id, input)).rejects.toMatchObject({ code: "guardian_not_applicable" });
    await expect(f.service.confirmGuardianInApp(f.account.id, { ...input, userId: adult.account.id })).rejects.toHaveProperty("issues");
    expect(await f.store.get(f.account.id)).toEqual(before);
  });
  it("rejects old saved policy and cannot rewrite the child's age", async () => {
    const f = await fixture(); const before = (await f.store.get(f.account.id))!;
    await f.store.save({ ...before, policyVersion: "tw-service-age-15-v1" });
    await expect(f.service.confirmGuardianInApp(f.account.id, input)).rejects.toMatchObject({ code: "guardian_not_applicable" });
    await expect(f.service.declareAge(f.account.id, declaration("18-plus"))).rejects.toMatchObject({ code: "age_declaration_locked" });
    expect((await f.store.get(f.account.id))?.ageBand).toBe("15-17");
    await f.service.declareAge(f.account.id, declaration("15-17"));
    expect(await f.service.confirmGuardianInApp(f.account.id, input)).toMatchObject({ canWrite: true });
  });
  it("is idempotent including concurrent approval and preserves active AI until explicit withdrawal", async () => {
    const f = await fixture(); const before = (await f.store.get(f.account.id))!;
    await Promise.all([f.service.confirmGuardianInApp(f.account.id, input), f.service.confirmGuardianInApp(f.account.id, input)]);
    expect((await f.store.get(f.account.id))?.revision).toBe(before.revision + 1);
    await f.service.setAiConsent(f.account.id, { granted: true, policyVersion: aiConsentPolicyVersion });
    const approved = await f.store.get(f.account.id);
    await f.service.confirmGuardianInApp(f.account.id, input);
    expect(await f.store.get(f.account.id)).toEqual(approved);
    expect(await f.service.getAiConsent(f.account.id)).toMatchObject({ granted: true });
    await f.service.withdrawGuardianByAccount(f.account.id);
    await expect(f.service.requireServiceEligibility(f.account.id)).rejects.toMatchObject({ code: "guardian_consent_required" });
    expect(await f.service.getAiConsent(f.account.id)).toMatchObject({ granted: false });
    await f.service.confirmGuardianInApp(f.account.id, input);
    expect(await f.service.getAiConsent(f.account.id)).toMatchObject({ granted: false });
    await f.service.setAiConsent(f.account.id, { granted: true, policyVersion: aiConsentPolicyVersion });
    expect(await f.service.getAiConsent(f.account.id)).toMatchObject({ granted: true });
  });
  it("serializes approval and withdrawal without reusing an AI grant", async () => {
    const f = await fixture(); await f.service.confirmGuardianInApp(f.account.id, input);
    await f.service.setAiConsent(f.account.id, { granted: true, policyVersion: aiConsentPolicyVersion });
    await Promise.all([f.service.withdrawGuardianByAccount(f.account.id), f.service.confirmGuardianInApp(f.account.id, input)]);
    expect(await f.service.getEligibility(f.account.id)).toMatchObject({ canWrite: true, guardianConsentMethod: "in-app" });
    expect(await f.service.getAiConsent(f.account.id)).toMatchObject({ granted: false });
  });
});
