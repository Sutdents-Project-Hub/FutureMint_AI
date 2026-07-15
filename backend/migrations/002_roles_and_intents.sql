ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS account_role text NOT NULL DEFAULT 'child';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_account_role_check'
  ) THEN
    ALTER TABLE profiles
      ADD CONSTRAINT profiles_account_role_check
      CHECK (account_role IN ('child', 'parent'));
  END IF;
END $$;

ALTER TABLE money_events
  ADD COLUMN IF NOT EXISTS spending_intent text,
  ADD COLUMN IF NOT EXISTS intent_reason text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'money_events_spending_intent_check'
  ) THEN
    ALTER TABLE money_events
      ADD CONSTRAINT money_events_spending_intent_check
      CHECK (spending_intent IN ('need', 'want', 'uncertain'));
  END IF;
END $$;
