-- Minimal journal preserved separately before any backup restore.
-- No email, password or financial data; random account IDs are SHA-256 hashed.
CREATE TABLE IF NOT EXISTS deleted_account_journal (
  account_hash text PRIMARY KEY CHECK (account_hash ~ '^[0-9a-f]{64}$'),
  deleted_at timestamptz NOT NULL DEFAULT NOW()
);
