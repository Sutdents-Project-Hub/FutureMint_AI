import { randomUUID } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { PostgresRepository } from "../../src/adapters/postgresRepository";
import { FutureMintService } from "../../src/application/futureMintService";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { demoCatalog } from "../../src/adapters/demoCatalog";
import { EducationalMarketDataProvider } from "../../src/adapters/twseMarketDataProvider";
import { AuthService } from "../../src/auth/authService";
import type { UserProfile } from "../../src/contracts/models";

// Explicit synthetic test endpoint only. Never load dotenv or DATABASE_URL.
const connectionString = process.env.FUTUREMINT_TEST_DATABASE_URL;
if (connectionString) {
  const url = new URL(connectionString);
  if (!["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) || url.pathname !== "/futuremint_test") {
    throw new Error("Integration tests require a localhost database named futuremint_test");
  }
}
const schema = `test_${randomUUID().replaceAll("-", "")}`;
let admin: Pool;
let pool: Pool;
let secondPool: Pool;
let repository: PostgresRepository;
let otherRepository: PostgresRepository;
const makeService = (repo: PostgresRepository) => new FutureMintService(repo, new DemoAiProvider(), demoCatalog, new EducationalMarketDataProvider());
const profile = (userId: string, role: "parent" | "child" = "child"): UserProfile => ({
  userId, monthlyBudgetMinor: 6000, goalName: "合成測試", goalTargetMinor: 12000,
  goalSavedMinor: 1000, goalDate: "2027-12-31", preferredTone: "supportive", accountRole: role,
});
async function addUser(role: "parent" | "child" = "child") {
  const { account } = await new AuthService(repository).register({ email: `${randomUUID()}@example.com`, password: "synthetic-test-2026" });
  await repository.saveProfile(profile(account.id, role));
  return account.id;
}

describe.skipIf(!connectionString)("isolated PostgreSQL integration", () => {
  beforeAll(async () => {
    admin = new Pool({ connectionString });
    await admin.query(`CREATE SCHEMA ${schema}`);
    pool = new Pool({ connectionString, options: `-c search_path=${schema}`, max: 8 });
    secondPool = new Pool({ connectionString, options: `-c search_path=${schema}`, max: 8 });
    repository = new PostgresRepository(pool);
    otherRepository = new PostgresRepository(secondPool);
    const directory = path.resolve("migrations");
    for (const file of (await readdir(directory)).filter((name) => /^\d+.*\.sql$/.test(name)).sort()) {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        if (file.startsWith("006_")) {
          await client.query(`INSERT INTO accounts (id,user_id,email,password_hash,password_salt,password_algorithm)
            VALUES ('legacy-parent','legacy-parent','legacy-parent@example.com','hash','salt','scrypt-v1'),
                   ('legacy-child','legacy-child','legacy-child@example.com','hash','salt','scrypt-v1')`);
          await client.query(`INSERT INTO profiles (user_id,monthly_budget_minor,goal_name,goal_target_minor,goal_saved_minor,goal_date,preferred_tone,account_role)
            VALUES ('legacy-parent',6000,'synthetic',12000,0,'2027-01-01','supportive','parent'),
                   ('legacy-child',6000,'synthetic',12000,0,'2027-01-01','supportive','parent')`);
          await client.query(`INSERT INTO family_groups (id,invite_code,created_by) VALUES ('legacy-family','OLDCODE1','legacy-parent')`);
          await client.query(`INSERT INTO family_members (family_id,user_id) VALUES ('legacy-family','legacy-parent'),('legacy-family','legacy-child')`);
        }
        await client.query(await readFile(path.join(directory, file), "utf8"));
        await client.query("COMMIT");
      } catch (error) { await client.query("ROLLBACK"); throw error; }
      finally { client.release(); }
    }
  }, 30_000);

  afterAll(async () => {
    await Promise.all([pool?.end(), secondPool?.end()]);
    if (admin) {
      await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
      await admin.end();
    }
  });

  it("migrates legacy roles from the family relationship and retires plaintext invites", async () => {
    expect((await repository.getProfile("legacy-child")).accountRole).toBe("child");
    expect((await repository.getFamilyMembership("legacy-child"))?.role).toBe("child");
    const legacy = (await pool.query("SELECT invite_code,invite_code_hash,invite_active FROM family_groups WHERE id='legacy-family'")).rows[0];
    expect(legacy).toEqual({ invite_code: null, invite_code_hash: null, invite_active: false });
    await expect(repository.saveProfile({ ...profile("legacy-child"), accountRole: "parent" })).rejects.toMatchObject({ code: "family_role_locked" });
    await expect(pool.query("UPDATE family_members SET role='parent' WHERE user_id='legacy-child'")).rejects.toMatchObject({ message: "family_role_locked" });
  });

  it("keeps family creation atomic even when called directly and membership insertion fails", async () => {
    const userId = await addUser("parent");
    const service = makeService(repository);
    await service.createFamilyInvite(userId);
    const before = await pool.query("SELECT count(*)::int AS count FROM family_groups");
    await expect(repository.createFamilyGroup(userId, randomUUID(), randomUUID(), "2099-01-01T00:00:00Z")).rejects.toMatchObject({ status: 409 });
    const child = await addUser();
    await expect(repository.createFamilyGroup(child, randomUUID(), randomUUID(), "2099-01-01T00:00:00Z")).rejects.toMatchObject({ code: "family_parent_required" });
    expect((await pool.query("SELECT count(*)::int AS count FROM family_groups")).rows).toEqual(before.rows);
  });

  it("pins BEGIN, changes and ROLLBACK to one connection and leaves no transaction open", async () => {
    const userId = await addUser();
    await expect(repository.withUsersTransaction([userId], async (scoped) => {
      await scoped.saveProfile({ ...profile(userId), goalName: "must roll back" });
      throw new Error("synthetic failure");
    })).rejects.toThrow("synthetic failure");
    expect((await repository.getProfile(userId)).goalName).toBe("合成測試");
    await expect(otherRepository.withUsersTransaction([userId], async (scoped) => scoped.getProfile(userId))).resolves.toHaveProperty("userId", userId);
  });

  it("serializes join versus role change across independent pools", async () => {
    const parent = await addUser("parent");
    const service = makeService(repository);
    const otherService = makeService(otherRepository);
    const invite = await service.createFamilyInvite(parent);
    for (let i = 0; i < 8; i++) {
      const child = await addUser();
      const results = await Promise.allSettled([
        service.joinFamily(child, { inviteCode: invite.inviteCode! }),
        otherService.updateProfile(child, { ...profile(child), accountRole: "parent" }),
      ]);
      expect(results.filter((result) => result.status === "rejected")).toHaveLength(1);
      const membership = await repository.getFamilyMembership(child);
      const savedProfile = await repository.getProfile(child);
      if (membership) {
        expect(membership.role).toBe("child");
        expect(savedProfile.accountRole).toBe("child");
        expect((await service.getFamilyOverview(child))?.childSummaries).toEqual([]);
      } else expect(savedProfile.accountRole).toBe("parent");
    }
  });

  it("hashes invitations and rejects rotated, revoked and expired codes", async () => {
    const parent = await addUser("parent");
    const child = await addUser();
    const service = makeService(repository);
    const first = await service.createFamilyInvite(parent);
    const row = (await pool.query("SELECT invite_code, invite_code_hash FROM family_groups WHERE created_by=$1", [parent])).rows[0];
    expect(row.invite_code).toBeNull();
    expect(row.invite_code_hash).toMatch(/^[a-f0-9]{64}$/);
    expect(row.invite_code_hash).not.toBe(first.inviteCode);
    expect((await service.getFamilyOverview(parent))?.inviteCode).toBeUndefined();
    const second = await service.rotateFamilyInvite(parent);
    await expect(service.joinFamily(child, { inviteCode: first.inviteCode! })).rejects.toMatchObject({ code: "family_invite_not_found" });
    await service.revokeFamilyInvite(parent);
    await expect(service.joinFamily(child, { inviteCode: second.inviteCode! })).rejects.toMatchObject({ code: "family_invite_not_found" });
    const third = await service.rotateFamilyInvite(parent);
    await pool.query("UPDATE family_groups SET invite_code_expires_at=now()-interval '1 second' WHERE created_by=$1", [parent]);
    await expect(service.joinFamily(child, { inviteCode: third.inviteCode! })).rejects.toMatchObject({ code: "family_invite_not_found" });
    expect((await service.getFamilyOverview(parent))?.inviteActive).toBe(false);
  });

  it("prevents overspending and duplicate orders across independent instances", async () => {
    const userId = await addUser();
    const service = makeService(repository);
    const otherService = makeService(otherRepository);
    await service.getInvestmentLab(userId);
    const quote = (await service.getMarketSnapshot()).quotes[0];
    const quantity = Math.floor(1000 / quote.price);
    const results = await Promise.allSettled([
      service.placeInvestmentOrder(userId, { symbol: quote.symbol, side: "buy", quantity, idempotencyKey: "parallel-order-a" }),
      otherService.placeInvestmentOrder(userId, { symbol: quote.symbol, side: "buy", quantity, idempotencyKey: "parallel-order-b" }),
    ]);
    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    expect((await service.getInvestmentLab(userId)).cashMinor).toBeGreaterThanOrEqual(0);
    const [saved] = await repository.listInvestmentOrders(userId);
    await Promise.all([service.placeInvestmentOrder(userId, { symbol: quote.symbol, side: "buy", quantity, idempotencyKey: saved.idempotencyKey }), otherService.placeInvestmentOrder(userId, { symbol: quote.symbol, side: "buy", quantity, idempotencyKey: saved.idempotencyKey })]);
    expect(await repository.listInvestmentOrders(userId)).toHaveLength(1);
  });

  it("consumes reset tokens once, revokes sessions and rejects stale credential session creation", async () => {
    const mail: string[] = [];
    const auth = new AuthService(repository, undefined, { mailer: { send: async (_to, purpose, token) => { if (purpose === "reset-password") mail.push(token); } } });
    const email = `${randomUUID()}@example.com`;
    const registered = await auth.register({ email, password: "synthetic-test-2026" });
    const old = (await repository.findAccountById(registered.account.id))!;
    await auth.requestPasswordReset({ email });
    const otherAuth = new AuthService(otherRepository);
    const outcomes = await Promise.allSettled([auth.resetPassword(mail[0], "replacement-test2026"), otherAuth.resetPassword(mail[0], "replacement-test2026")]);
    expect(outcomes.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    await expect(auth.authenticate(registered.token)).rejects.toMatchObject({ code: "unauthorized" });
    await expect(otherRepository.createSession({ id: randomUUID(), tokenHash: randomUUID(), userId: old.id, createdAt: new Date().toISOString(), expiresAt: "2099-01-01T00:00:00Z" }, old.passwordHash)).rejects.toMatchObject({ code: "invalid_credentials" });
    expect(await repository.deleteExpiredOrRevokedSessions(new Date().toISOString())).toBeGreaterThan(0);
    await expect(auth.login({ email, password: "replacement-test2026" })).resolves.toHaveProperty("token");
  });

  it("shares bounded rate counters and cleanup across instances without storing raw keys", async () => {
    const key = `synthetic-email-${randomUUID()}@example.com`;
    const counts = await Promise.all(Array.from({ length: 20 }, (_, i) => (i % 2 ? repository : otherRepository).consumeRateLimit(key, 60_000)));
    expect(counts.map((value) => value.current).sort((a, b) => a - b)).toEqual(Array.from({ length: 20 }, (_, i) => i + 1));
    const rows = (await pool.query("SELECT key_hash FROM rate_limit_counters")).rows;
    expect(rows.every((row) => /^[a-f0-9]{64}$/.test(row.key_hash))).toBe(true);
    expect(await repository.deleteExpiredRateLimits(new Date().toISOString())).toBe(0);
    await otherRepository.clearRateLimit(key);
    expect((await repository.consumeRateLimit(key, 60_000)).current).toBe(1);
  });
});
