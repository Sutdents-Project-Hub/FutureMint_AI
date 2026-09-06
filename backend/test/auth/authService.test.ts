import { describe, expect, it } from "vitest";

import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import {
  aiConsentPolicyVersion,
  AuthService,
} from "../../src/auth/authService";

const createService = () => new AuthService(new InMemoryRepository());

describe("AuthService", () => {
  it("creates a session without exposing password fields", async () => {
    const service = createService();

    const result = await service.register({
      email: "Student@Example.com",
      password: "futuremint2026",
    });

    expect(result.account).toMatchObject({
      email: "student@example.com",
      profileComplete: false,
    });
    expect(result.account).not.toHaveProperty("passwordHash");
    expect(result.account).not.toHaveProperty("passwordSalt");
    await expect(service.authenticate(result.token)).resolves.toMatchObject({
      email: "student@example.com",
      profileComplete: false,
    });
  });

  it("rejects a session after logout", async () => {
    const service = createService();
    const { token } = await service.register({
      email: "student@example.com",
      password: "futuremint2026",
    });

    await service.logout(token);

    await expect(service.authenticate(token)).rejects.toMatchObject({
      code: "unauthorized",
      status: 401,
    });
  });

  it("uses one generic error for an unknown email and a wrong password", async () => {
    const service = createService();
    await service.register({
      email: "student@example.com",
      password: "futuremint2026",
    });

    const unknown = service.login({
      email: "missing@example.com",
      password: "futuremint2026",
    });
    const wrongPassword = service.login({
      email: "student@example.com",
      password: "not-the-password2026",
    });

    await expect(unknown).rejects.toMatchObject({ code: "invalid_credentials" });
    await expect(wrongPassword).rejects.toMatchObject({
      code: "invalid_credentials",
    });
  });

  it("allows only one account when identical registrations race", async () => {
    const service = createService();
    const attempts = await Promise.allSettled([
      service.register({
        email: "student@example.com",
        password: "futuremint2026",
      }),
      service.register({
        email: "student@example.com",
        password: "futuremint2026",
      }),
    ]);

    expect(attempts.filter((attempt) => attempt.status === "fulfilled")).toHaveLength(1);
    const rejected = attempts.find(
      (attempt): attempt is PromiseRejectedResult => attempt.status === "rejected",
    );
    expect(rejected?.reason).toMatchObject({ code: "account_unavailable", status: 409 });
  });

  it("records the current third-party AI consent and withdrawal timestamps", async () => {
    const repository = new InMemoryRepository();
    let now = new Date("2026-08-30T01:00:00.000Z");
    const service = new AuthService(repository, () => now);
    const { account } = await service.register({
      email: "student@example.com",
      password: "futuremint2026",
    });

    await expect(service.getAiConsent(account.id)).resolves.toEqual({
      granted: false,
      policyVersion: aiConsentPolicyVersion,
      grantedAt: null,
      withdrawnAt: null,
    });
    await expect(service.setAiConsent(account.id, { granted: true })).resolves.toEqual({
      granted: true,
      policyVersion: aiConsentPolicyVersion,
      grantedAt: "2026-08-30T01:00:00.000Z",
      withdrawnAt: null,
    });

    now = new Date("2026-08-30T02:00:00.000Z");
    await expect(service.setAiConsent(account.id, { granted: false })).resolves.toEqual({
      granted: false,
      policyVersion: aiConsentPolicyVersion,
      grantedAt: "2026-08-30T01:00:00.000Z",
      withdrawnAt: "2026-08-30T02:00:00.000Z",
    });
    await expect(service.requireAiConsent(account.id)).rejects.toMatchObject({
      code: "ai_consent_required",
      status: 403,
    });
  });

  it("requires renewed consent when the stored policy version is stale", async () => {
    const repository = new InMemoryRepository();
    const service = new AuthService(repository);
    const { account } = await service.register({
      email: "student@example.com",
      password: "futuremint2026",
    });
    await repository.saveAiConsent(account.id, {
      granted: true,
      policyVersion: "third-party-ai-v0",
      grantedAt: "2026-08-01T00:00:00.000Z",
      withdrawnAt: null,
    });

    await expect(service.getAiConsent(account.id)).resolves.toEqual({
      granted: false,
      policyVersion: aiConsentPolicyVersion,
      grantedAt: null,
      withdrawnAt: null,
    });
    await expect(service.requireAiConsent(account.id)).rejects.toMatchObject({
      code: "ai_consent_required",
      status: 403,
    });
  });

  it("requires the current password and fully deletes only the requesting account", async () => {
    const repository = new InMemoryRepository();
    const service = new AuthService(repository);
    const first = await service.register({
      email: "first@example.com",
      password: "futuremint2026",
    });
    const second = await service.register({
      email: "second@example.com",
      password: "futuremint2026",
    });
    await service.setAiConsent(first.account.id, { granted: true });

    await expect(
      service.deleteAccount(first.account.id, { password: "wrong-password2026" }),
    ).rejects.toMatchObject({ code: "invalid_credentials", status: 401 });
    await expect(service.authenticate(first.token)).resolves.toMatchObject({
      id: first.account.id,
    });

    await service.deleteAccount(first.account.id, { password: "futuremint2026" });
    await expect(service.authenticate(first.token)).rejects.toMatchObject({
      code: "unauthorized",
      status: 401,
    });
    await expect(service.getAiConsent(first.account.id)).resolves.toMatchObject({
      granted: false,
      grantedAt: null,
      withdrawnAt: null,
    });
    await expect(service.authenticate(second.token)).resolves.toMatchObject({
      id: second.account.id,
    });
    await expect(
      service.register({
        email: "first@example.com",
        password: "futuremint2026",
      }),
    ).resolves.toMatchObject({ account: { email: "first@example.com" } });
  });

  it("mimics account-delete cascade semantics for family creators and members", async () => {
    const repository = new InMemoryRepository();
    const service = new AuthService(repository);
    const creator = await service.register({
      email: "creator@example.com",
      password: "futuremint2026",
    });
    const child = await service.register({
      email: "child@example.com",
      password: "futuremint2026",
    });
    await repository.saveProfile({
      userId: creator.account.id,
      monthlyBudgetMinor: 6000,
      goalName: "目標",
      goalTargetMinor: 12000,
      goalSavedMinor: 0,
      goalDate: "2026-12-31",
      preferredTone: "supportive",
      accountRole: "parent",
    });
    await repository.saveProfile({
      userId: child.account.id,
      monthlyBudgetMinor: 6000,
      goalName: "目標",
      goalTargetMinor: 12000,
      goalSavedMinor: 0,
      goalDate: "2026-12-31",
      preferredTone: "supportive",
      accountRole: "child",
    });
    await repository.createFamilyGroup(creator.account.id, "family-a", "hash-a", "2099-01-01T00:00:00Z");
    await repository.addFamilyMember("family-a", child.account.id);

    await service.deleteAccount(creator.account.id, {
      password: "futuremint2026",
    });
    await expect(repository.getFamilyGroup("family-a")).resolves.toBeNull();
    await expect(repository.getFamilyMembership(child.account.id)).resolves.toBeNull();
    await expect(service.authenticate(child.token)).resolves.toMatchObject({
      id: child.account.id,
    });

    const secondCreator = await service.register({
      email: "creator-two@example.com",
      password: "futuremint2026",
    });
    const member = await service.register({
      email: "member@example.com",
      password: "futuremint2026",
    });
    const parentProfile = await repository.getProfile(creator.account.id).catch(() => ({
      monthlyBudgetMinor: 6000, goalName: "目標", goalTargetMinor: 12000,
      goalSavedMinor: 0, goalDate: "2026-12-31", preferredTone: "supportive" as const,
    }));
    await repository.saveProfile({ ...parentProfile, userId: secondCreator.account.id, accountRole: "parent" });
    await repository.saveProfile({ ...parentProfile, userId: member.account.id, accountRole: "child" });
    await repository.createFamilyGroup(
      secondCreator.account.id,
      "family-b",
      "hash-b", "2099-01-01T00:00:00Z",
    );
    await repository.addFamilyMember("family-b", member.account.id);
    await service.deleteAccount(member.account.id, {
      password: "futuremint2026",
    });
    await expect(repository.getFamilyGroup("family-b")).resolves.toMatchObject({
      createdBy: secondCreator.account.id,
    });
    await expect(
      repository.getFamilyMembership(secondCreator.account.id),
    ).resolves.toMatchObject({ familyId: "family-b" });
  });
});
