CREATE TABLE IF NOT EXISTS family_groups (
  id text PRIMARY KEY,
  invite_code text NOT NULL UNIQUE,
  created_by text NOT NULL REFERENCES accounts(user_id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS family_members (
  family_id text NOT NULL REFERENCES family_groups(id) ON DELETE CASCADE,
  user_id text NOT NULL UNIQUE REFERENCES accounts(user_id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (family_id, user_id)
);

CREATE INDEX IF NOT EXISTS family_members_family_id_idx
  ON family_members(family_id);
