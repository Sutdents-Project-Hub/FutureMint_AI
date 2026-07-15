CREATE TABLE IF NOT EXISTS virtual_investment_accounts (
  user_id text PRIMARY KEY REFERENCES accounts(user_id) ON DELETE CASCADE,
  starting_cash_minor integer NOT NULL CHECK (starting_cash_minor > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS virtual_investment_orders (
  id text PRIMARY KEY,
  user_id text NOT NULL REFERENCES virtual_investment_accounts(user_id)
    ON DELETE CASCADE,
  symbol text NOT NULL,
  name text NOT NULL,
  side text NOT NULL CHECK (side IN ('buy', 'sell')),
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric(14, 2) NOT NULL CHECK (unit_price > 0),
  total_minor integer NOT NULL CHECK (total_minor > 0),
  quote_as_of date NOT NULL,
  quote_source text NOT NULL CHECK (
    quote_source IN ('twse-openapi', 'educational-snapshot')
  ),
  idempotency_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS virtual_investment_orders_user_created_idx
  ON virtual_investment_orders(user_id, created_at DESC);
