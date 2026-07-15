CREATE TABLE IF NOT EXISTS accounts (
  id text PRIMARY KEY,
  user_id text NOT NULL UNIQUE,
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  password_salt text NOT NULL,
  password_algorithm text NOT NULL CHECK (password_algorithm = 'scrypt-v1'),
  profile_complete boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sessions (
  id text PRIMARY KEY,
  user_id text NOT NULL REFERENCES accounts(user_id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);

CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_expires_at_idx ON sessions(expires_at);

CREATE TABLE IF NOT EXISTS profiles (
  user_id text PRIMARY KEY REFERENCES accounts(user_id) ON DELETE CASCADE,
  monthly_budget_minor integer NOT NULL CHECK (monthly_budget_minor > 0),
  weekly_budget_minor integer CHECK (weekly_budget_minor > 0),
  goal_name text NOT NULL,
  goal_target_minor integer NOT NULL CHECK (goal_target_minor > 0),
  goal_saved_minor integer NOT NULL CHECK (goal_saved_minor >= 0),
  goal_date date NOT NULL,
  preferred_tone text NOT NULL CHECK (preferred_tone IN ('supportive', 'direct'))
);

CREATE TABLE IF NOT EXISTS money_events (
  id text PRIMARY KEY,
  user_id text NOT NULL REFERENCES accounts(user_id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('income', 'expense', 'subscription')),
  amount_minor integer NOT NULL CHECK (amount_minor > 0),
  currency text NOT NULL CHECK (currency = 'TWD'),
  category text NOT NULL CHECK (
    category IN (
      'food', 'transport', 'entertainment', 'education', 'shopping',
      'income', 'subscription', 'other'
    )
  ),
  merchant text,
  occurred_at timestamptz NOT NULL,
  recurrence jsonb,
  split jsonb,
  idempotency_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS money_events_user_occurred_idx
  ON money_events(user_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS lessons (
  id text PRIMARY KEY,
  user_id text NOT NULL REFERENCES accounts(user_id) ON DELETE CASCADE,
  title text NOT NULL,
  concept text NOT NULL,
  example text NOT NULL,
  question text NOT NULL,
  options jsonb NOT NULL,
  action text NOT NULL,
  disclaimer text NOT NULL,
  source_event_ids jsonb NOT NULL,
  source text NOT NULL CHECK (source IN ('liangjie-ai', 'deterministic-demo')),
  selected_option text,
  completed_at timestamptz,
  created_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS lessons_user_created_idx
  ON lessons(user_id, created_at DESC);
