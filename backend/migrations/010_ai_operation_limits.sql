-- Atomic per-day admission and expiring concurrency leases shared by API replicas.
CREATE TABLE IF NOT EXISTS ai_usage_daily (
  usage_day date NOT NULL,
  subject text NOT NULL,
  user_id text REFERENCES accounts(user_id) ON DELETE CASCADE,
  request_count integer NOT NULL CHECK (request_count >= 0),
  PRIMARY KEY (usage_day, subject)
);
CREATE TABLE IF NOT EXISTS ai_operation_leases (
  id text PRIMARY KEY,
  user_id text NOT NULL REFERENCES accounts(user_id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS ai_operation_leases_expiry_idx ON ai_operation_leases(expires_at);
