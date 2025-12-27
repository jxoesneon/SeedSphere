-- 0002_linking.sql
-- Add linking model and cache.last_write_at for weekly-capped writes

BEGIN;

-- Linking model
CREATE TABLE IF NOT EXISTS gardeners (
  gardener_id TEXT PRIMARY KEY,
  user_id TEXT,
  platform TEXT,
  created_at INTEGER NOT NULL,
  last_seen INTEGER
);

CREATE TABLE IF NOT EXISTS seedlings (
  seedling_id TEXT PRIMARY KEY,
  user_id TEXT,
  created_at INTEGER NOT NULL,
  last_seen INTEGER
);

CREATE TABLE IF NOT EXISTS bindings (
  seedling_id TEXT NOT NULL,
  gardener_id TEXT NOT NULL,
  secret TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (seedling_id, gardener_id)
);
CREATE INDEX IF NOT EXISTS bindings_g ON bindings(gardener_id);
CREATE INDEX IF NOT EXISTS bindings_s ON bindings(seedling_id);

CREATE TABLE IF NOT EXISTS link_tokens (
  token TEXT PRIMARY KEY,
  gardener_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

-- Add last_write_at to cache for weekly cap (safe if missing; will be no-op if already present in fresh dbs)
-- SQLite does not support IF NOT EXISTS for ADD COLUMN; running once on 0001-based DBs.
ALTER TABLE cache ADD COLUMN last_write_at INTEGER;

COMMIT;
