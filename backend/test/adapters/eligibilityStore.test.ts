import { describe, expect, it } from "vitest";
import { InMemoryEligibilityStore } from "../../src/adapters/eligibilityStore";
import type { EligibilityRecord, GuardianActionToken } from "../../src/contracts/servicePolicy";
const record = (userId: string): EligibilityRecord => ({ userId, ageBand: "15-17", policyVersion: "synthetic-policy", declaredAt: "2026-10-01T00:00:00Z", guardianStatus: "pending", guardianEmail: "guardian@example.invalid", guardianApprovedAt: null, guardianWithdrawnAt: null, revision: 1, aiConsentRevision: null });
const token = (userId: string): GuardianActionToken => ({ userId, tokenHash: `synthetic-hash-${userId}`, purpose: "guardian-approve", policyVersion: "synthetic-policy", guardianEmail: "guardian@example.invalid", revision: 1, expiresAt: "2026-10-01T01:00:00Z" });
describe("memory eligibility transaction rollback", () => {
  it("restores only the failed user's record/tokens and preserves another user's concurrent commit", async () => {
    const store = new InMemoryEligibilityStore();
    await store.save(record("failed")); await store.saveToken(token("failed"));
    await store.save(record("other")); await store.saveToken(token("other"));
    let entered!: () => void, release!: () => void;
    const enteredPromise = new Promise<void>((resolve) => { entered = resolve; });
    const waiting = new Promise<void>((resolve) => { release = resolve; });
    const failure = store.withUserTransaction("failed", async (transaction) => {
      await transaction.save({ ...record("failed"), revision: 2 }); await transaction.clearTokens("failed"); entered(); await waiting; throw new Error("synthetic mail failure");
    });
    const rejected = expect(failure).rejects.toThrow("synthetic mail failure");
    await enteredPromise;
    await store.withUserTransaction("other", async (transaction) => {
      await transaction.save({ ...record("other"), revision: 3 }); await transaction.saveToken({ ...token("other"), tokenHash: "new-other-hash", revision: 3 });
    });
    release(); await rejected;
    expect(await store.get("failed")).toEqual(record("failed")); expect(await store.findToken(token("failed").tokenHash)).toEqual(token("failed"));
    expect(await store.get("other")).toMatchObject({ revision: 3 }); expect(await store.findToken("new-other-hash")).toMatchObject({ revision: 3 });
    expect(await store.findToken(token("other").tokenHash)).toBeNull();
  });
});
