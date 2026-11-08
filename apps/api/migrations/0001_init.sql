CREATE TABLE challenges (
  id TEXT PRIMARY KEY,
  expires_at INTEGER NOT NULL
);

CREATE TABLE devices (
  key_id TEXT PRIMARY KEY,
  public_key TEXT NOT NULL,
  counter INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE attested_activities (
  activity_hash TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  key_id TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX attested_activities_account ON attested_activities (account_id, ended_at);
CREATE INDEX attested_activities_key ON attested_activities (key_id, ended_at);

CREATE TABLE merchants (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  is_admin INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE TABLE login_tokens (
  token_hash TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX login_tokens_email ON login_tokens (email, created_at);

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  merchant_id TEXT NOT NULL REFERENCES merchants (id),
  expires_at INTEGER NOT NULL
);

CREATE TABLE locations (
  id TEXT PRIMARY KEY,
  merchant_id TEXT NOT NULL REFERENCES merchants (id),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  geohash5 TEXT NOT NULL,
  categories TEXT NOT NULL,
  near_account TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX locations_cell ON locations (geohash5, status);
CREATE INDEX locations_merchant ON locations (merchant_id);
CREATE INDEX locations_status ON locations (status, created_at);
