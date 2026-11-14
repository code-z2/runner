CREATE TABLE goals (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  distance_m INTEGER NOT NULL,
  max_seconds INTEGER,
  amount TEXT NOT NULL,
  source_asset TEXT NOT NULL,
  source_chain TEXT NOT NULL,
  source_symbol TEXT NOT NULL,
  source_decimals INTEGER NOT NULL,
  return_address TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN (
    'awaiting_deposit', 'locked', 'ready_to_withdraw', 'withdrawing',
    'withdrawn', 'funding_refunded', 'withdrawal_refunded'
  )),
  lock_id TEXT UNIQUE,
  locked_at INTEGER,
  created_at INTEGER NOT NULL
);

CREATE UNIQUE INDEX goals_unbeaten ON goals(account_id)
  WHERE state IN ('awaiting_deposit', 'locked');
CREATE INDEX goals_owner ON goals(account_id, created_at);

CREATE TABLE goal_funding (
  goal_id TEXT PRIMARY KEY REFERENCES goals(id),
  refund_address TEXT NOT NULL,
  deposit_address TEXT NOT NULL,
  deposit_memo TEXT,
  amount_in TEXT NOT NULL,
  deadline TEXT NOT NULL,
  settlement_tx TEXT UNIQUE
);
CREATE UNIQUE INDEX goal_funding_route ON goal_funding(deposit_address, COALESCE(deposit_memo, ''));

CREATE TABLE goal_transactions (
  id TEXT PRIMARY KEY,
  goal_id TEXT NOT NULL REFERENCES goals(id),
  kind TEXT NOT NULL CHECK (kind IN ('unlock', 'withdraw')),
  state TEXT NOT NULL CHECK (state IN ('quoted', 'submitted', 'succeeded', 'rejected')),
  amount TEXT NOT NULL,
  receiver_id TEXT,
  correlation_id TEXT,
  deadline TEXT,
  tx_hash TEXT UNIQUE,
  signed_relay TEXT,
  max_block_height TEXT,
  created_at INTEGER NOT NULL
);
CREATE UNIQUE INDEX goal_live_transaction ON goal_transactions(goal_id, kind)
  WHERE state IN ('quoted', 'submitted', 'succeeded');
