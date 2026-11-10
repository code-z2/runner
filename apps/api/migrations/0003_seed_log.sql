CREATE TABLE IF NOT EXISTS seed_log (
  account_id TEXT PRIMARY KEY,
  key_id TEXT,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_seed_log_key_time ON seed_log (key_id, created_at);
