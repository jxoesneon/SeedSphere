-- 0001_initial.sql
-- Schema for users/sessions/ai_keys and Greenhouse tables (§5A)

BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  email TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  sid TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS ai_keys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,
  enc_key BLOB NOT NULL,
  nonce BLOB NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(user_id, provider),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ai_keys_user ON ai_keys(user_id);

-- Gardener / Greenhouse
CREATE TABLE IF NOT EXISTS devices (
  device_id TEXT PRIMARY KEY,
  user_id TEXT,
  agent TEXT,
  last_seen INTEGER,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS devices_user ON devices(user_id);

CREATE TABLE IF NOT EXISTS installations (
  install_id TEXT PRIMARY KEY,
  user_id TEXT,
  platform TEXT,
  created_at INTEGER NOT NULL,
  last_seen INTEGER
);
CREATE INDEX IF NOT EXISTS installations_user ON installations(user_id);

CREATE TABLE IF NOT EXISTS pairings (
  pair_code TEXT PRIMARY KEY,
  install_id TEXT NOT NULL,
  device_id TEXT,
  expires_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS pairings_install ON pairings(install_id);
CREATE INDEX IF NOT EXISTS pairings_status ON pairings(status);

CREATE TABLE IF NOT EXISTS rooms (
  room_id TEXT PRIMARY KEY,
  last_activity INTEGER
);

CREATE TABLE IF NOT EXISTS cache (
  cache_key TEXT PRIMARY KEY,
  payload_json BLOB,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  hits INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS cache_expires ON cache(expires_at);

CREATE TABLE IF NOT EXISTS audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event TEXT NOT NULL,
  at INTEGER NOT NULL,
  meta_json BLOB
);

COMMIT;
