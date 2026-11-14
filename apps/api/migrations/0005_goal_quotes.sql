-- Replace the 0004 goal tables (empty in production when this was written)
-- with one saved quote per goal and one reserved payout per goal.
DROP TABLE goal_transactions;
DROP TABLE goal_funding;
DROP TABLE goals;

-- One row per goal ID (the escrow `funding_id`). `quote` is the saved
-- 1Click response body; NULL while the first request is still upstream.
CREATE TABLE goals (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  origin_asset TEXT NOT NULL,
  return_address TEXT NOT NULL,
  distance_m INTEGER NOT NULL,
  max_seconds INTEGER,
  request TEXT NOT NULL,
  quote TEXT,
  lock_id TEXT UNIQUE,
  locked_amount TEXT,
  locked_at INTEGER,
  created_at INTEGER NOT NULL
);
CREATE INDEX goals_account ON goals(account_id, created_at);

-- Reserved once per goal: the 1Click deposit account the escrow pays into.
CREATE TABLE goal_payouts (
  goal_id TEXT PRIMARY KEY REFERENCES goals(id),
  receiver_id TEXT NOT NULL,
  amount TEXT NOT NULL,
  deadline TEXT NOT NULL,
  withdrawn INTEGER NOT NULL DEFAULT 0
);
