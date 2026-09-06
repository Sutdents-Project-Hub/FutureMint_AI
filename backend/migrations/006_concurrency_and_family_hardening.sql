ALTER TABLE family_groups
  ADD COLUMN IF NOT EXISTS invite_code_hash text,
  ADD COLUMN IF NOT EXISTS invite_code_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS invite_active boolean NOT NULL DEFAULT false;

ALTER TABLE family_groups
  ALTER COLUMN invite_code DROP NOT NULL;

ALTER TABLE family_groups
  DROP CONSTRAINT IF EXISTS family_groups_invite_code_key;

-- Legacy short plaintext invitations cannot be upgraded safely. Existing family
-- membership is preserved, while parents must rotate a new invitation.
UPDATE family_groups
SET invite_code = NULL,
    invite_code_hash = NULL,
    invite_code_expires_at = NULL,
    invite_active = false;

CREATE UNIQUE INDEX IF NOT EXISTS family_groups_active_invite_hash_idx
  ON family_groups(invite_code_hash)
  WHERE invite_code_hash IS NOT NULL;

ALTER TABLE family_members
  ADD COLUMN IF NOT EXISTS role text;

UPDATE family_members AS fm
SET role = CASE WHEN fg.created_by = fm.user_id THEN 'parent' ELSE 'child' END
FROM family_groups AS fg
WHERE fg.id = fm.family_id AND fm.role IS NULL;

-- The creator is the only parent admitted by the family API. Derive legacy
-- membership roles from that relationship, not the formerly mutable profile.
UPDATE profiles AS p
SET account_role = fm.role
FROM family_members AS fm
WHERE fm.user_id = p.user_id AND p.account_role <> fm.role;

ALTER TABLE family_members
  ALTER COLUMN role SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'family_members_role_check'
  ) THEN
    ALTER TABLE family_members
      ADD CONSTRAINT family_members_role_check
      CHECK (role IN ('child', 'parent'));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION enforce_profile_family_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM 1 FROM accounts WHERE user_id = NEW.user_id FOR UPDATE;
  IF EXISTS (
    SELECT 1 FROM family_members
    WHERE user_id = NEW.user_id AND role <> NEW.account_role
  ) THEN
    RAISE EXCEPTION 'family_role_locked' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_family_role_guard ON profiles;
CREATE TRIGGER profiles_family_role_guard
BEFORE INSERT OR UPDATE OF account_role ON profiles
FOR EACH ROW EXECUTE FUNCTION enforce_profile_family_role();

CREATE OR REPLACE FUNCTION enforce_family_member_profile_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  profile_role text;
BEGIN
  PERFORM 1 FROM accounts WHERE user_id = NEW.user_id FOR UPDATE;
  SELECT account_role INTO profile_role
  FROM profiles
  WHERE user_id = NEW.user_id;
  IF profile_role IS NULL OR profile_role <> NEW.role THEN
    RAISE EXCEPTION 'family_role_locked' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS family_members_profile_role_guard ON family_members;
CREATE TRIGGER family_members_profile_role_guard
BEFORE INSERT OR UPDATE OF role ON family_members
FOR EACH ROW EXECUTE FUNCTION enforce_family_member_profile_role();

CREATE TABLE IF NOT EXISTS rate_limit_counters (
  key_hash text PRIMARY KEY,
  current_count integer NOT NULL CHECK (current_count > 0),
  expires_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS rate_limit_counters_expires_at_idx
  ON rate_limit_counters(expires_at);
