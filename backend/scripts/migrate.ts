import "dotenv/config";

import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

import type { Pool } from "pg";

import { createPostgresPoolFromEnvironment } from "../src/adapters/postgresRepository";

export const runMigrations = async (
  pool: Pool,
  migrationsDirectory = path.resolve(process.cwd(), "migrations"),
): Promise<string[]> => {
  const client = await pool.connect();
  const applied: string[] = [];
  try {
    await client.query(
      "SELECT pg_advisory_lock(hashtext('futuremint-schema-migrations'))",
    );
    await client.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      name text PRIMARY KEY,
      checksum text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now()
    )`);
    await client.query(
      "ALTER TABLE schema_migrations ADD COLUMN IF NOT EXISTS checksum text",
    );
    const files = (await readdir(migrationsDirectory))
      .filter((file) => /^\d+_[a-z0-9_-]+\.sql$/u.test(file))
      .sort();
    const existing = await client.query<{ name: string; checksum: string | null }>(
      "SELECT name, checksum FROM schema_migrations",
    );
    const existingChecksums = new Map(
      existing.rows.map((row) => [row.name, row.checksum]),
    );

    for (const file of files) {
      const sql = await readFile(path.join(migrationsDirectory, file), "utf8");
      const checksum = createHash("sha256").update(sql).digest("hex");
      if (existingChecksums.has(file)) {
        const storedChecksum = existingChecksums.get(file);
        if (storedChecksum && storedChecksum !== checksum) {
          throw new Error(`Migration checksum mismatch: ${file}`);
        }
        if (!storedChecksum) {
          await client.query(
            "UPDATE schema_migrations SET checksum = $2 WHERE name = $1",
            [file, checksum],
          );
        }
        continue;
      }
      await client.query("BEGIN");
      try {
        await client.query(sql);
        await client.query(
          "INSERT INTO schema_migrations (name, checksum) VALUES ($1, $2)",
          [file, checksum],
        );
        await client.query("COMMIT");
        applied.push(file);
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    }
    return applied;
  } finally {
    await client
      .query("SELECT pg_advisory_unlock(hashtext('futuremint-schema-migrations'))")
      .catch(() => undefined);
    client.release();
  }
};

const main = async (): Promise<void> => {
  const pool = createPostgresPoolFromEnvironment();
  try {
    const applied = await runMigrations(pool);
    console.info("futuremint_postgres_migrations_complete", {
      appliedCount: applied.length,
      migrations: applied,
    });
  } finally {
    await pool.end();
  }
};

const summarizeMigrationError = (error: unknown): Record<string, string> => {
  const record = error !== null && typeof error === "object"
    ? error as { code?: unknown }
    : undefined;
  const message = error instanceof Error ? error.message : "Unknown migration error";

  return {
    errorType: error instanceof Error ? error.name : typeof error,
    ...(typeof record?.code === "string" ? { code: record.code } : {}),
    message: message
      .replace(/\bpostgres(?:ql)?:\/\/[^\s@]+@[^\s]+/giu, "postgres://[redacted]")
      .slice(0, 300),
  };
};

if (require.main === module) {
  void main().catch((error: unknown) => {
    console.error("futuremint_postgres_migrations_failed", summarizeMigrationError(error));
    process.exitCode = 1;
  });
}
