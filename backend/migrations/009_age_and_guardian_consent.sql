-- Missing rows deliberately leave existing accounts pending age declaration.
CREATE TABLE IF NOT EXISTS service_eligibilities (
  user_id text PRIMARY KEY REFERENCES accounts(user_id) ON DELETE CASCADE,
  age_band text NOT NULL CHECK (age_band IN ('under-15', '15-17', '18-plus')),
  policy_version text NOT NULL,
  declared_at timestamptz NOT NULL,
  guardian_status text NOT NULL CHECK (guardian_status IN ('not-required', 'pending', 'approved', 'withdrawn')),
  guardian_email text,
  guardian_approved_at timestamptz,
  guardian_withdrawn_at timestamptz,
  revision integer NOT NULL CHECK (revision > 0),
  ai_consent_revision integer,
  CHECK ((age_band = '18-plus' AND guardian_status = 'not-required') OR
         (age_band <> '18-plus' AND guardian_status <> 'not-required'))
);
CREATE TABLE IF NOT EXISTS guardian_action_tokens (
  token_hash text PRIMARY KEY,
  user_id text NOT NULL REFERENCES service_eligibilities(user_id) ON DELETE CASCADE,
  purpose text NOT NULL CHECK (purpose IN ('guardian-approve', 'guardian-withdraw')),
  policy_version text NOT NULL,
  guardian_email text NOT NULL,
  revision integer NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, purpose)
);
CREATE INDEX IF NOT EXISTS guardian_action_tokens_expires_at_idx ON guardian_action_tokens(expires_at);
