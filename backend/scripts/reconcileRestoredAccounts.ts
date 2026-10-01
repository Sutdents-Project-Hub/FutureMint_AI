import { readFile, writeFile } from "node:fs/promises";
import { Pool } from "pg";
import { z } from "zod";
import { createPostgresPoolFromEnvironment } from "../src/adapters/postgresRepository";
const journalSchema = z.object({ version: z.literal(1), entries: z.array(z.object({ accountHash: z.string().regex(/^[0-9a-f]{64}$/), deletedAt: z.string().datetime() })).max(1000000) });
export type DeletionJournal = z.infer<typeof journalSchema>;
export const validateRestoreTarget = (sourceUrl: string | undefined, restoredUrl: string | undefined): string => {
  if (!sourceUrl || !restoredUrl) throw new Error("Both DATABASE_URL and RESTORE_DATABASE_URL are required");
  const source = new URL(sourceUrl); const target = new URL(restoredUrl);
  for (const url of [source, target]) {
    if (!["postgres:", "postgresql:"].includes(url.protocol) || !url.hostname || !url.pathname || url.pathname === "/" || url.hash) throw new Error("Explicit PostgreSQL host and database are required");
    // pg permits connection targets to be overridden through URL query options.
    // SSL mode is the only supported query option for this maintenance utility.
    if ([...url.searchParams.keys()].some((key) => key !== "sslmode")) throw new Error("Maintenance URLs cannot contain connection routing or other query overrides");
  }
  const sourceDatabase = decodeURIComponent(source.pathname.slice(1));
  const restoredDatabase = decodeURIComponent(target.pathname.slice(1));
  // Require a distinct database name even on another server. This also rejects
  // production aliases, different credentials, default ports and SSL options.
  if (sourceDatabase === restoredDatabase) throw new Error("Restore must use a separately named isolated database");
  return restoredUrl;
};
export const exportDeletionJournal = async (pool: Pool): Promise<DeletionJournal> => {
  const { rows } = await pool.query<{ account_hash: string; deleted_at: Date }>("SELECT account_hash, deleted_at FROM deleted_account_journal ORDER BY account_hash");
  return { version: 1, entries: rows.map((row) => ({ accountHash: row.account_hash, deletedAt: new Date(row.deleted_at).toISOString() })) };
};
export const reconcileRestoredAccounts = async (pool: Pool, input: unknown, apply = false): Promise<number> => {
  const journal = journalSchema.parse(input); const hashes = journal.entries.map((entry) => entry.accountHash);
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(hashtext('futuremint-restore-reconciliation'))");
    const match = "encode(sha256(convert_to(user_id, 'UTF8')), 'hex') = ANY($1::text[])";
    const count = (await client.query<{ count: number }>("SELECT count(*)::int AS count FROM accounts WHERE " + match, [hashes])).rows[0].count;
    if (apply) {
      await client.query("DELETE FROM accounts WHERE " + match, [hashes]);
      await client.query(`INSERT INTO deleted_account_journal (account_hash,deleted_at)
        SELECT account_hash, max(deleted_at) FROM unnest($1::text[], $2::timestamptz[]) AS journal(account_hash,deleted_at) GROUP BY account_hash
        ON CONFLICT (account_hash) DO UPDATE SET deleted_at=GREATEST(deleted_account_journal.deleted_at,EXCLUDED.deleted_at)`, [hashes, journal.entries.map((entry) => entry.deletedAt)]);
    }
    await client.query("COMMIT"); return count;
  } catch (error) { await client.query("ROLLBACK"); throw error; }
  finally { client.release(); }
};
const main = async (): Promise<void> => {
  const [action, file, option] = process.argv.slice(2);
  if (!file || !["export", "preview", "apply"].includes(action) || option) throw new Error("Use export|preview|apply with a protected journal file path");
  if (action === "export") {
    const pool = createPostgresPoolFromEnvironment();
    try { const journal = await exportDeletionJournal(pool); await writeFile(file, JSON.stringify(journal), { mode: 0o600, flag: "wx" }); console.info("deletion_journal_exported", { count: journal.entries.length }); }
    finally { await pool.end(); }
    return;
  }
  const restoredUrl = validateRestoreTarget(process.env.DATABASE_URL, process.env.RESTORE_DATABASE_URL);
  if (action === "apply" && process.env.RESTORE_RECONCILIATION_MAINTENANCE !== "true") throw new Error("Apply requires RESTORE_RECONCILIATION_MAINTENANCE=true and disabled application traffic");
  const pool = new Pool({ connectionString: restoredUrl, ssl: process.env.DATABASE_SSL === "true" ? { rejectUnauthorized: true } : false, max: 2, connectionTimeoutMillis: 5000 });
  try { const count = await reconcileRestoredAccounts(pool, JSON.parse(await readFile(file, "utf8")), action === "apply"); console.info("restored_account_reconciliation", { applied: action === "apply", matchedCount: count }); }
  finally { await pool.end(); }
};
if (require.main === module) {
  require("dotenv").config();
  void main().catch(() => { console.error("deletion_journal_operation_failed", { action: "check_protected_journal_and_isolated_restore_settings" }); process.exitCode = 1; });
}
