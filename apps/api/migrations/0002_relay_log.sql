CREATE TABLE relay_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sender_id TEXT NOT NULL,
  key_id TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX relay_log_sender ON relay_log (sender_id, created_at);
CREATE INDEX relay_log_key ON relay_log (key_id, created_at);
