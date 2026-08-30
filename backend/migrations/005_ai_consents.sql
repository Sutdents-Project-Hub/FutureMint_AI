CREATE TABLE IF NOT EXISTS ai_consents (
  user_id text PRIMARY KEY REFERENCES accounts(user_id) ON DELETE CASCADE,
  policy_version text NOT NULL,
  granted boolean NOT NULL,
  granted_at timestamptz,
  withdrawn_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (granted AND granted_at IS NOT NULL AND withdrawn_at IS NULL)
    OR (NOT granted AND withdrawn_at IS NOT NULL)
  )
);
