'use strict'

const path = require('node:path')
const fs = require('node:fs')
const Database = require('better-sqlite3')

let db

function initDb(baseDir) {
  if (db) return db
  const dir = baseDir || path.join(__dirname, '..', 'data')
  try { fs.mkdirSync(dir, { recursive: true }) } catch (_) {}
  const file = path.join(dir, 'seedsphere.db')
  db = new Database(file)
  db.pragma('journal_mode = WAL')
  db.pragma('synchronous = NORMAL')
  migrate()
  return db
}

function migrate() {
  // Migration runner reading SQL files from server/migrations/
  const migDir = path.join(__dirname, '..', 'migrations')
  try { fs.mkdirSync(migDir, { recursive: true }) } catch (_) {}
  // Track applied migrations
  db.exec('CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at INTEGER NOT NULL)')
  const applied = new Set(db.prepare('SELECT version FROM schema_migrations').all().map((r) => r.version))
  // Read .sql files sorted by name
  let files = []
  try {
    files = fs.readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort()
  } catch (_) { files = [] }
  if (!files.length) {
    // Fallback: bootstrap baseline if no migrations present (dev convenience)
    db.exec(`
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
      hits INTEGER DEFAULT 0,
      last_write_at INTEGER
    );
    CREATE INDEX IF NOT EXISTS cache_expires ON cache(expires_at);
    -- Linking model (bootstrap in absence of migrations files)
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
    CREATE TABLE IF NOT EXISTS audit (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event TEXT NOT NULL,
      at INTEGER NOT NULL,
      meta_json BLOB
    );
    `)
    return
  }
  // Apply pending migrations
  for (const f of files) {
    const version = f
    if (applied.has(version)) continue
    const full = path.join(migDir, f)
    let sql = ''
    try { sql = fs.readFileSync(full, 'utf8') } catch (_) { continue }
    const hasTxn = /\bBEGIN\b/i.test(sql) && /\bCOMMIT\b/i.test(sql)
    if (hasTxn) {
      // Migration file manages its own transaction boundaries
      db.exec(sql)
      db.prepare('INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)').run(version, Date.now())
    } else {
      const txn = db.transaction(() => {
        db.exec(sql)
        db.prepare('INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)').run(version, Date.now())
      })
      txn()
    }
  }
}

function upsertUser({ id, provider, email }) {
  const now = Date.now()
  const insert = db.prepare('INSERT OR IGNORE INTO users (id, provider, email, created_at) VALUES (?, ?, ?, ?)')
  insert.run(id, provider, email || null, now)
  const update = db.prepare('UPDATE users SET provider = COALESCE(?, provider), email = COALESCE(?, email) WHERE id = ?')
  update.run(provider || null, email || null, id)
  return getUser(id)
}

function getUser(id) {
  return db.prepare('SELECT id, provider, email, created_at FROM users WHERE id = ?').get(id)
}

function createSession(sid, user_id, ttlMs) {
  const now = Date.now()
  const exp = now + Math.max(5 * 60_000, ttlMs || 30 * 24 * 60 * 60_000)
  db.prepare('INSERT OR REPLACE INTO sessions (sid, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)').run(sid, user_id, now, exp)
}

function getSession(sid) {
  if (!sid) return null
  const row = db.prepare('SELECT sid, user_id, created_at, expires_at FROM sessions WHERE sid = ?').get(sid)
  if (!row) return null
  if (row.expires_at < Date.now()) { try { db.prepare('DELETE FROM sessions WHERE sid = ?').run(sid) } catch (_) {} ; return null }
  return row
}

function deleteSession(sid) {
  try { db.prepare('DELETE FROM sessions WHERE sid = ?').run(sid) } catch (_) {}
}

function upsertAiKey(user_id, provider, enc_key, nonce) {
  const now = Date.now()
  db.prepare(`INSERT INTO ai_keys (user_id, provider, enc_key, nonce, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?)
              ON CONFLICT(user_id, provider) DO UPDATE SET enc_key = excluded.enc_key, nonce = excluded.nonce, updated_at = excluded.updated_at`).run(user_id, provider, enc_key, nonce, now, now)
}

function getAiKey(user_id, provider) {
  return db.prepare('SELECT id, user_id, provider, enc_key, nonce, created_at, updated_at FROM ai_keys WHERE user_id = ? AND provider = ?').get(user_id, provider)
}

function listAiKeys(user_id) {
  return db.prepare('SELECT provider, updated_at FROM ai_keys WHERE user_id = ? ORDER BY provider').all(user_id)
}

function deleteAiKey(user_id, provider) {
  db.prepare('DELETE FROM ai_keys WHERE user_id = ? AND provider = ?').run(user_id, provider)
}

// Devices
function upsertDevice({ device_id, user_id = null, agent = null }) {
  const now = Date.now()
  db.prepare(`INSERT INTO devices (device_id, user_id, agent, last_seen, created_at)
              VALUES (?, ?, ?, ?, ?)
              ON CONFLICT(device_id) DO UPDATE SET user_id = COALESCE(excluded.user_id, devices.user_id), agent = COALESCE(excluded.agent, devices.agent), last_seen = excluded.last_seen`).run(device_id, user_id, agent, now, now)
  return db.prepare('SELECT device_id, user_id, agent, last_seen, created_at FROM devices WHERE device_id = ?').get(device_id)
}

// Installations
function upsertInstallation({ install_id, user_id = null, platform = null }) {
  const now = Date.now()
  db.prepare(`INSERT INTO installations (install_id, user_id, platform, created_at, last_seen)
              VALUES (?, ?, ?, ?, ?)
              ON CONFLICT(install_id) DO UPDATE SET user_id = COALESCE(excluded.user_id, installations.user_id), platform = COALESCE(excluded.platform, installations.platform), last_seen = excluded.last_seen`).run(install_id, user_id, platform, now, now)
  return db.prepare('SELECT install_id, user_id, platform, created_at, last_seen FROM installations WHERE install_id = ?').get(install_id)
}

// Pairings
function createPairing({ pair_code, install_id, expires_at }) {
  const now = Date.now()
  db.prepare('INSERT OR REPLACE INTO pairings (pair_code, install_id, device_id, expires_at, status, created_at) VALUES (?, ?, NULL, ?, ?, ?)')
    .run(pair_code, install_id, expires_at, 'pending', now)
}

function getPairing(pair_code) {
  return db.prepare('SELECT pair_code, install_id, device_id, expires_at, status, created_at FROM pairings WHERE pair_code = ?').get(pair_code)
}

function completePairing(pair_code, device_id) {
  db.prepare('UPDATE pairings SET device_id = ?, status = ? WHERE pair_code = ?').run(device_id, 'linked', pair_code)
}

function expireOldPairings(nowTs = Date.now()) {
  db.prepare('UPDATE pairings SET status = ? WHERE expires_at < ? AND status != ?').run('expired', nowTs, 'expired')
}

// Pairing lookups
function getLatestLinkedPairingByInstall(install_id) {
  if (!install_id) return null
  return db.prepare('SELECT pair_code, install_id, device_id, expires_at, status, created_at FROM pairings WHERE install_id = ? AND status = ? AND device_id IS NOT NULL ORDER BY created_at DESC LIMIT 1')
    .get(install_id, 'linked')
}

// Rooms
function touchRoom(room_id) {
  const now = Date.now()
  db.prepare('INSERT OR REPLACE INTO rooms (room_id, last_activity) VALUES (?, ?)').run(room_id, now)
}

// Cache rows (server-side normalized cache)
function getCacheRow(cache_key) {
  const row = db.prepare('SELECT cache_key, payload_json, created_at, expires_at, hits FROM cache WHERE cache_key = ?').get(cache_key)
  if (!row) return null
  if (row.expires_at < Date.now()) return null
  return row
}

function setCacheRow(cache_key, payloadObj, ttlMs) {
  const now = Date.now()
  const exp = now + Math.max(60_000, Number(ttlMs) || 300_000)
  const payload_json = Buffer.from(JSON.stringify(payloadObj))
  db.prepare('INSERT OR REPLACE INTO cache (cache_key, payload_json, created_at, expires_at, hits) VALUES (?, ?, ?, ?, COALESCE((SELECT hits FROM cache WHERE cache_key = ?), 0))')
    .run(cache_key, payload_json, now, exp, cache_key)
}

// Enforce weekly write cap: at most one write per (key) per 7 days
function setCacheRowWeeklyCapped(cache_key, payloadObj, ttlMs) {
  const now = Date.now()
  const row = db.prepare('SELECT last_write_at FROM cache WHERE cache_key = ?').get(cache_key)
  const weekMs = 7 * 24 * 60 * 60_000
  if (row && row.last_write_at && (now - row.last_write_at) < weekMs) return false
  const exp = now + Math.max(60_000, Number(ttlMs) || 7 * 24 * 60 * 60_000)
  const payload_json = Buffer.from(JSON.stringify(payloadObj))
  db.prepare('INSERT INTO cache (cache_key, payload_json, created_at, expires_at, hits, last_write_at) VALUES (?, ?, ?, ?, 0, ?) ON CONFLICT(cache_key) DO UPDATE SET payload_json=excluded.payload_json, expires_at=excluded.expires_at, last_write_at=excluded.last_write_at')
    .run(cache_key, payload_json, now, exp, now)
  return true
}

// Linking helpers
function upsertGardener(gardener_id, platform = null) {
  const now = Date.now()
  db.prepare(`INSERT INTO gardeners (gardener_id, user_id, platform, created_at, last_seen)
              VALUES (?, NULL, ?, ?, ?)
              ON CONFLICT(gardener_id) DO UPDATE SET platform = COALESCE(excluded.platform, gardeners.platform), last_seen = excluded.last_seen`).run(gardener_id, platform, now, now)
  return db.prepare('SELECT gardener_id, user_id, platform, created_at, last_seen FROM gardeners WHERE gardener_id = ?').get(gardener_id)
}

function touchGardener(gardener_id) {
  const now = Date.now()
  db.prepare('UPDATE gardeners SET last_seen = ? WHERE gardener_id = ?').run(now, gardener_id)
}

function upsertSeedling(seedling_id) {
  const now = Date.now()
  db.prepare(`INSERT INTO seedlings (seedling_id, user_id, created_at, last_seen)
              VALUES (?, NULL, ?, ?)
              ON CONFLICT(seedling_id) DO UPDATE SET last_seen = excluded.last_seen`).run(seedling_id, now, now)
  return db.prepare('SELECT seedling_id, user_id, created_at, last_seen FROM seedlings WHERE seedling_id = ?').get(seedling_id)
}

function listBindingsByGardener(gardener_id) {
  return db.prepare('SELECT seedling_id, gardener_id, secret, created_at FROM bindings WHERE gardener_id = ? ORDER BY created_at DESC').all(gardener_id)
}

function listBindingsBySeedling(seedling_id) {
  return db.prepare('SELECT seedling_id, gardener_id, secret, created_at FROM bindings WHERE seedling_id = ? ORDER BY created_at DESC').all(seedling_id)
}

function createBinding(gardener_id, seedling_id, secret) {
  const now = Date.now()
  db.prepare('INSERT OR REPLACE INTO bindings (seedling_id, gardener_id, secret, created_at) VALUES (?, ?, ?, ?)').run(seedling_id, gardener_id, secret, now)
}

function deleteBinding(gardener_id, seedling_id) {
  db.prepare('DELETE FROM bindings WHERE gardener_id = ? AND seedling_id = ?').run(gardener_id, seedling_id)
}

function countBindingsForGardener(gardener_id) {
  const r = db.prepare('SELECT COUNT(*) AS c FROM bindings WHERE gardener_id = ?').get(gardener_id)
  return (r && r.c) || 0
}

function countBindingsForSeedling(seedling_id) {
  const r = db.prepare('SELECT COUNT(*) AS c FROM bindings WHERE seedling_id = ?').get(seedling_id)
  return (r && r.c) || 0
}

function createLinkToken(token, gardener_id, ttlMs) {
  const now = Date.now()
  const exp = now + Math.max(60_000, ttlMs || 10 * 60_000)
  db.prepare('INSERT OR REPLACE INTO link_tokens (token, gardener_id, expires_at, created_at) VALUES (?, ?, ?, ?)').run(token, gardener_id, exp, now)
  return { token, gardener_id, expires_at: exp }
}

function getLinkToken(token) {
  const row = db.prepare('SELECT token, gardener_id, expires_at, created_at FROM link_tokens WHERE token = ?').get(token)
  if (!row) return null
  if (row.expires_at < Date.now()) return null
  return row
}

function deleteLinkToken(token) {
  try { db.prepare('DELETE FROM link_tokens WHERE token = ?').run(token) } catch (_) {}
}

function getBindingSecret(gardener_id, seedling_id) {
  if (!gardener_id || !seedling_id) return null
  const row = db.prepare('SELECT secret FROM bindings WHERE gardener_id = ? AND seedling_id = ?').get(gardener_id, seedling_id)
  return row ? row.secret : null
}

// Audit log
function writeAudit(event, metaObj) {
  const at = Date.now()
  const meta_json = metaObj ? Buffer.from(JSON.stringify(metaObj)) : null
  db.prepare('INSERT INTO audit (event, at, meta_json) VALUES (?, ?, ?)').run(event, at, meta_json)
}

module.exports = {
  initDb,
  upsertUser,
  getUser,
  createSession,
  getSession,
  deleteSession,
  upsertAiKey,
  getAiKey,
  listAiKeys,
  deleteAiKey,
  // greenhouse helpers
  upsertDevice,
  upsertInstallation,
  createPairing,
  getPairing,
  completePairing,
  expireOldPairings,
  touchRoom,
  getCacheRow,
  setCacheRow,
  setCacheRowWeeklyCapped,
  writeAudit,
  getLatestLinkedPairingByInstall,
  // linking
  upsertGardener,
  touchGardener,
  upsertSeedling,
  listBindingsByGardener,
  listBindingsBySeedling,
  createBinding,
  deleteBinding,
  countBindingsForGardener,
  countBindingsForSeedling,
  createLinkToken,
  getLinkToken,
  deleteLinkToken,
  getBindingSecret,
}
