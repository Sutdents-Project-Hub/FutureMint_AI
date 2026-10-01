import { createHash, randomUUID } from "node:crypto";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { AuthService } from "../../src/auth/authService";
import { PostgresRepository } from "../../src/adapters/postgresRepository";
import { runMigrations } from "../../scripts/migrate";
import { exportDeletionJournal, reconcileRestoredAccounts, validateRestoreTarget } from "../../scripts/reconcileRestoredAccounts";

describe("restore target guards", () => {
  const source = "postgresql://operator:synthetic@localhost:5432/futuremint";
  it("requires both explicit database URLs and a separately named database", () => {
    expect(() => validateRestoreTarget(undefined, source)).toThrow();
    expect(() => validateRestoreTarget(source, source)).toThrow();
    expect(() => validateRestoreTarget(source, "postgres://different:synthetic@127.0.0.1/futuremint?sslmode=require")).toThrow();
    expect(() => validateRestoreTarget(source, "postgresql://operator:synthetic@other-host/futuremint")).toThrow();
    const restored = "postgresql://operator:synthetic@localhost:5432/futuremint_restore";
    expect(validateRestoreTarget(source, restored)).toBe(restored);
  });
  it("rejects query routing overrides and same-target string variations", () => {
    for (const suffix of ["?application_name=restore", "?host=elsewhere", "?dbname=futuremint", "#restore"]) {
      expect(() => validateRestoreTarget(source, source + suffix)).toThrow();
    }
    expect(() => validateRestoreTarget(source, source + "_restore?database=futuremint")).toThrow();
    expect(() => validateRestoreTarget(source + "?host=elsewhere", source + "_restore")).toThrow();
  });
});

const connectionString = process.env.FUTUREMINT_TEST_DATABASE_URL;
if (connectionString) {
  const url = new URL(connectionString);
  if (!["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) || url.pathname !== "/futuremint_test") throw new Error("Restore tests require isolated localhost futuremint_test database");
}
const sourceSchema = "journal_source_" + randomUUID().replaceAll("-", "");
const restoreSchema = "journal_restore_" + randomUUID().replaceAll("-", "");
let admin: Pool; let source: Pool; let restored: Pool;
describe.skipIf(!connectionString)("isolated deletion reconciliation", () => {
  beforeAll(async () => {
    admin = new Pool({ connectionString });
    await admin.query(`CREATE SCHEMA ${sourceSchema}`); await admin.query(`CREATE SCHEMA ${restoreSchema}`);
    source = new Pool({ connectionString, options: `-c search_path=${sourceSchema}` });
    restored = new Pool({ connectionString, options: `-c search_path=${restoreSchema}` });
    await runMigrations(source); await runMigrations(restored);
  }, 30000);
  afterAll(async () => {
    await Promise.all([source?.end(), restored?.end()]);
    if (admin) { await admin.query(`DROP SCHEMA IF EXISTS ${sourceSchema}, ${restoreSchema} CASCADE`); await admin.end(); }
  });
  it("previews without changes, then removes restored deleted accounts while preserving other users", async () => {
    const liveRepo = new PostgresRepository(source); const restoreRepo = new PostgresRepository(restored);
    const liveAuth = new AuthService(liveRepo); const restoreAuth = new AuthService(restoreRepo);
    const deleted = await liveAuth.register({ email: "deleted@example.com", password: "synthetic-local-2026" });
    const survivor = await liveAuth.register({ email: "survivor@example.com", password: "synthetic-local-2026" });
    for (const userId of [deleted.account.id, survivor.account.id]) {
      const account = await liveRepo.findAccountById(userId); expect(account).not.toBeNull();
      await restoreRepo.createAccount(account!);
      await restoreRepo.saveProfile({ userId, monthlyBudgetMinor: 6000, goalName: "synthetic", goalTargetMinor: 10000, goalSavedMinor: 0, goalDate: "2027-01-01", preferredTone: "supportive", accountRole: "child" });
      await restoreAuth.login({ email: account!.email, password: "synthetic-local-2026" });
    }
    await liveAuth.deleteAccount(deleted.account.id, { password: "synthetic-local-2026" });
    const journal = await exportDeletionJournal(source);
    expect(journal.entries).toHaveLength(1);
    expect(journal.entries[0].accountHash).toBe(createHash("sha256").update(deleted.account.id).digest("hex"));
    expect(JSON.stringify(journal)).not.toContain("deleted@example.com");
    expect(await reconcileRestoredAccounts(restored, journal)).toBe(1);
    expect(await restoreRepo.findAccountById(deleted.account.id)).not.toBeNull();
    expect(await reconcileRestoredAccounts(restored, journal, true)).toBe(1);
    expect(await restoreRepo.findAccountById(deleted.account.id)).toBeNull();
    expect((await restored.query("SELECT count(*)::int AS count FROM profiles WHERE user_id=$1", [deleted.account.id])).rows[0].count).toBe(0);
    expect((await restored.query("SELECT count(*)::int AS count FROM sessions WHERE user_id=$1", [deleted.account.id])).rows[0].count).toBe(0);
    await expect(restoreAuth.login({ email: "deleted@example.com", password: "synthetic-local-2026" })).rejects.toMatchObject({ code: "invalid_credentials" });
    await expect(restoreAuth.login({ email: "survivor@example.com", password: "synthetic-local-2026" })).resolves.toHaveProperty("token");
    expect(await exportDeletionJournal(restored)).toEqual(journal);
    expect(await reconcileRestoredAccounts(restored, journal, true)).toBe(0);
  });
  it("rejects malformed journals before deleting anything", async () => {
    const before = (await restored.query("SELECT count(*)::int AS count FROM accounts")).rows[0].count;
    await expect(reconcileRestoredAccounts(restored, { version: 1, entries: [{ accountHash: "invalid", deletedAt: "2026-10-01T00:00:00Z" }] }, true)).rejects.toThrow();
    expect((await restored.query("SELECT count(*)::int AS count FROM accounts")).rows[0].count).toBe(before);
  });
});
