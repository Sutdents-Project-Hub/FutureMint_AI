ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS email_verified_at timestamptz;

CREATE TABLE IF NOT EXISTS account_action_tokens (
  token_hash text PRIMARY KEY,
  user_id text NOT NULL REFERENCES accounts(user_id) ON DELETE CASCADE,
  purpose text NOT NULL CHECK (purpose IN ('verify-email', 'reset-password')),
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, purpose)
);

CREATE INDEX IF NOT EXISTS account_action_tokens_expires_at_idx
  ON account_action_tokens(expires_at);

CREATE INDEX IF NOT EXISTS sessions_revoked_at_idx
  ON sessions(revoked_at)
  WHERE revoked_at IS NOT NULL;
