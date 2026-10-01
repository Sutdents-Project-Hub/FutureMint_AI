CREATE TABLE subscriptions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES accounts(user_id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 80),
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0 AND amount_minor <= 100000000),
  currency TEXT NOT NULL DEFAULT 'TWD' CHECK (currency = 'TWD'),
  billing_cycle TEXT NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
  anchor_date DATE NOT NULL,
  original_billing_day INTEGER NOT NULL CHECK (original_billing_day BETWEEN 1 AND 31),
  original_billing_month INTEGER NOT NULL CHECK (original_billing_month BETWEEN 1 AND 12),
  idempotency_key TEXT NOT NULL,
  request_fingerprint TEXT NOT NULL,
  UNIQUE(user_id,idempotency_key),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(user_id,id)
);
CREATE INDEX subscriptions_owner_active ON subscriptions(user_id,active);
ALTER TABLE money_events ADD COLUMN subscription_id TEXT;
ALTER TABLE money_events ADD COLUMN request_fingerprint TEXT;
ALTER TABLE money_events ADD COLUMN source TEXT CHECK (source IN ('manual','liangjie-ai','openai-ai','deterministic-demo'));
ALTER TABLE money_events ADD CONSTRAINT money_event_subscription_owner
  FOREIGN KEY (user_id,subscription_id) REFERENCES subscriptions(user_id,id);
CREATE INDEX money_events_owner_page ON money_events(user_id,occurred_at DESC,id DESC);
ALTER TABLE virtual_investment_orders ADD COLUMN execution_sequence BIGINT;
WITH ordered AS (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at,id) AS sequence
  FROM virtual_investment_orders
) UPDATE virtual_investment_orders orders SET execution_sequence=ordered.sequence FROM ordered WHERE orders.id=ordered.id;
ALTER TABLE virtual_investment_orders ALTER COLUMN execution_sequence SET NOT NULL;
ALTER TABLE virtual_investment_orders ADD CONSTRAINT virtual_order_sequence_positive CHECK (execution_sequence > 0);
CREATE UNIQUE INDEX virtual_order_owner_sequence ON virtual_investment_orders(user_id,execution_sequence);
ALTER TABLE lessons DROP CONSTRAINT lessons_source_check;
ALTER TABLE lessons ADD CONSTRAINT lessons_source_check CHECK (source IN ('liangjie-ai','openai-ai','deterministic-demo','manual'));
ALTER TABLE lessons ADD COLUMN metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
