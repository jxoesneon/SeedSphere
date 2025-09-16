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
  // Mitigate occasional lock contention when multiple endpoints touch DB
  try { db.pragma('busy_timeout = 5000') } catch (_) {}
  migrate()
  try { ensureSchemaUpgrades() } catch (_) {}
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

// Ensure post-migration schema upgrades without creating separate migration files
function ensureSchemaUpgrades() {
  // Helper to check if a column exists on a table
  const hasColumn = (table, column) => {
    try {
      const rows = db.prepare(`PRAGMA table_info(${table})`).all()
      return rows.some(r => String(r.name) === String(column))
    } catch (_) { return false }
  }

  // installations: add key_hash (TEXT), salt (BLOB), status (TEXT), config_json (BLOB)
  try { if (!hasColumn('installations', 'key_hash')) db.exec('ALTER TABLE installations ADD COLUMN key_hash TEXT') } catch (_) {}
  try { if (!hasColumn('installations', 'salt')) db.exec('ALTER TABLE installations ADD COLUMN salt BLOB') } catch (_) {}
  try { if (!hasColumn('installations', 'status')) db.exec("ALTER TABLE installations ADD COLUMN status TEXT DEFAULT 'active'") } catch (_) {}
  try { if (!hasColumn('installations', 'config_json')) db.exec('ALTER TABLE installations ADD COLUMN config_json BLOB') } catch (_) {}

  // cache: ensure last_write_at present (idempotent)
  try { if (!hasColumn('cache', 'last_write_at')) db.exec('ALTER TABLE cache ADD COLUMN last_write_at INTEGER') } catch (_) {}

  // bans: simple table to mark banned users
  try {
    db.exec(`CREATE TABLE IF NOT EXISTS bans (
      user_id TEXT PRIMARY KEY,
      reason TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )`)
  } catch (_) {}

  // gardeners: add status (TEXT)
  try { if (!hasColumn('gardeners', 'status')) db.exec('ALTER TABLE gardeners ADD COLUMN status TEXT') } catch (_) {}
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
  return db.prepare('SELECT install_id, user_id, platform, created_at, last_seen, key_hash, salt, status, config_json FROM installations WHERE install_id = ?').get(install_id)
}

function setInstallationSecret(install_id, saltBuf, keyHashHex) {
  const now = Date.now()
  db.prepare('UPDATE installations SET salt = ?, key_hash = ?, last_seen = ? WHERE install_id = ?').run(saltBuf, keyHashHex, now, install_id)
}

function setInstallationUser(install_id, user_id) {
  const now = Date.now()
  db.prepare('UPDATE installations SET user_id = ?, last_seen = ? WHERE install_id = ?').run(user_id, now, install_id)
}

function setInstallationStatus(install_id, status) {
  db.prepare('UPDATE installations SET status = ? WHERE install_id = ?').run(status, install_id)
}

function setInstallationConfig(install_id, cfgObj) {
  const buf = cfgObj ? Buffer.from(JSON.stringify(cfgObj)) : null
  db.prepare('UPDATE installations SET config_json = ? WHERE install_id = ?').run(buf, install_id)
}

function getInstallation(install_id) {
  return db.prepare('SELECT install_id, user_id, platform, created_at, last_seen, key_hash, salt, status, config_json FROM installations WHERE install_id = ?').get(install_id)
}

function findRecentInstallationByUser(user_id, withinMs = 10 * 60_000) {
  const now = Date.now()
  const minTs = now - Math.max(60_000, withinMs)
  return db.prepare('SELECT install_id, user_id, platform, created_at, last_seen, key_hash, salt, status, config_json FROM installations WHERE user_id = ? AND created_at >= ? ORDER BY created_at DESC LIMIT 1').get(user_id, minTs)
}

function countInstallationsByUser(user_id) {
  const row = db.prepare('SELECT COUNT(*) AS c FROM installations WHERE user_id = ?').get(user_id)
  return (row && row.c) || 0
}

function listInstallationsByUser(user_id) {
  try {
    return db.prepare('SELECT install_id, user_id, platform, created_at, last_seen, status FROM installations WHERE user_id = ? ORDER BY created_at DESC').all(user_id)
  } catch (e) {
    const msg = String(e && e.message || '')
    if (msg.includes('no such column') && msg.includes('status')) {
      const rows = db.prepare('SELECT install_id, user_id, platform, created_at, last_seen FROM installations WHERE user_id = ? ORDER BY created_at DESC').all(user_id)
      return rows.map((r) => Object.assign({}, r, { status: 'active' }))
    }
    throw e
  }
}

function revokeInstallationOwned(user_id, install_id) {
  // Only allow status change if the installation belongs to this user
  const row = db.prepare('SELECT install_id FROM installations WHERE install_id = ? AND user_id = ?').get(install_id, user_id)
  if (!row) return false
  const sleeper = (ms) => { try { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, Math.max(1, ms)) } catch (_) {} }
  const maxAttempts = 5
  let attempt = 0
  // Retry loop to mitigate SQLITE_BUSY under concurrent writes
  while (true) {
    try {
      db.prepare('UPDATE installations SET status = ? WHERE install_id = ?').run('revoked', install_id)
      break
    } catch (e) {
      const msg = String(e && e.message || '')
      // Handle legacy DBs missing 'status' column by adding it on the fly
      if (msg.includes('no such column') && msg.includes('status')) {
        try { db.exec("ALTER TABLE installations ADD COLUMN status TEXT") } catch (_) { /* ignore */ }
        // retry immediately once after adding column
        continue
      }
      // Retry on SQLITE_BUSY / database is locked
      if (msg.includes('SQLITE_BUSY') || msg.includes('database is locked')) {
        attempt += 1
        if (attempt >= maxAttempts) throw e
        sleeper(50 * attempt)
        continue
      }
      throw e
    }
  }
  return true
}

function revokeAllInstallationsByUser(user_id) {
  if (!user_id) return 0
  const info = db.prepare('UPDATE installations SET status = ? WHERE user_id = ?').run('revoked', user_id)
  return info.changes || 0
}

// Permanently delete an installation owned by the user and related rows
function deleteInstallationOwned(user_id, install_id) {
  const row = db.prepare('SELECT install_id, user_id FROM installations WHERE install_id = ? AND user_id = ?').get(install_id, user_id)
  if (!row) return false
  const txn = db.transaction(() => {
    try { db.prepare('DELETE FROM pairings WHERE install_id = ?').run(install_id) } catch (_) {}
    try { db.prepare('DELETE FROM bindings WHERE seedling_id = ?').run(install_id) } catch (_) {}
    try { db.prepare('DELETE FROM seedlings WHERE seedling_id = ?').run(install_id) } catch (_) {}
    db.prepare('DELETE FROM installations WHERE install_id = ?').run(install_id)
  })
  txn()
  return true
}

// Bans
function setBan(user_id, reason) {
  const now = Date.now()
  db.prepare('INSERT OR REPLACE INTO bans (user_id, reason, created_at) VALUES (?, ?, ?)').run(user_id, reason || null, now)
}
function removeBan(user_id) {
  db.prepare('DELETE FROM bans WHERE user_id = ?').run(user_id)
}
function listBans() {
  return db.prepare('SELECT user_id, reason, created_at FROM bans ORDER BY created_at DESC').all()
}
function isBanned(user_id) {
  const row = db.prepare('SELECT 1 FROM bans WHERE user_id = ?').get(user_id)
  return !!row
}

// Delete user and related data
function deleteUserAndRelated(user_id) {
  const txn = db.transaction(() => {
    try { db.prepare('DELETE FROM sessions WHERE user_id = ?').run(user_id) } catch (_) {}
    try { db.prepare('DELETE FROM ai_keys WHERE user_id = ?').run(user_id) } catch (_) {}
    try { db.prepare('UPDATE devices SET user_id = NULL WHERE user_id = ?').run(user_id) } catch (_) {}
    try { db.prepare('UPDATE installations SET user_id = NULL WHERE user_id = ?').run(user_id) } catch (_) {}
    try { db.prepare('DELETE FROM bans WHERE user_id = ?').run(user_id) } catch (_) {}
    db.prepare('DELETE FROM users WHERE id = ?').run(user_id)
  })
  txn()
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

function reassignBinding(seedling_id, from_gardener_id, to_gardener_id) {
  const sid = String(seedling_id || '').trim()
  const from = String(from_gardener_id || '').trim()
  const to = String(to_gardener_id || '').trim()
  if (!sid || !from || !to || from === to) return false
  const txn = db.transaction(() => {
    const row = db.prepare('SELECT secret, created_at FROM bindings WHERE seedling_id = ? AND gardener_id = ?').get(sid, from)
    if (!row) return false
    db.prepare('INSERT OR REPLACE INTO bindings (seedling_id, gardener_id, secret, created_at) VALUES (?, ?, ?, ?)').run(sid, to, row.secret, row.created_at)
    db.prepare('DELETE FROM bindings WHERE seedling_id = ? AND gardener_id = ?').run(sid, from)
    return true
  })
  return txn()
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

// --- Gardeners admin helpers ---
function listGardeners(options = {}) {
  const q = String(options.query || '').trim().toLowerCase()
  const limit = Math.max(1, Math.min(200, Number(options.limit || 50)))
  const offset = Math.max(0, Number(options.offset || 0))
  // Build dynamic WHERE for search over gardener_id and platform
  const where = []
  const params = []
  if (q) {
    where.push('(LOWER(g.gardener_id) LIKE ? OR LOWER(g.platform) LIKE ?)')
    params.push(`%${q}%`, `%${q}%`)
  }
  const whereSql = where.length ? ('WHERE ' + where.join(' AND ')) : ''
  const sql = `
    SELECT g.gardener_id, g.user_id, g.platform, g.created_at, g.last_seen,
           COALESCE(b.cnt, 0) AS bindings_count
    FROM gardeners g
    LEFT JOIN (
      SELECT gardener_id, COUNT(*) AS cnt FROM bindings GROUP BY gardener_id
    ) b ON b.gardener_id = g.gardener_id
    ${whereSql}
    ORDER BY g.created_at DESC
    LIMIT ? OFFSET ?`
  return db.prepare(sql).all(...params, limit, offset)
}

function getGardenerWithCounts(gardener_id) {
  const gid = String(gardener_id || '').trim()
  if (!gid) return null
  const row = db.prepare(`
    SELECT g.gardener_id, g.user_id, g.platform, g.created_at, g.last_seen, g.status,
           (SELECT COUNT(*) FROM bindings WHERE gardener_id = g.gardener_id) AS bindings_count
    FROM gardeners g WHERE g.gardener_id = ?
  `).get(gid)
  if (!row) return null
  const bindings = db.prepare('SELECT seedling_id, created_at FROM bindings WHERE gardener_id = ? ORDER BY created_at DESC').all(gid)
  return Object.assign({}, row, { bindings })
}

function listGardenersByUser(user_id) {
  try {
    return db.prepare('SELECT gardener_id, user_id, platform, created_at, last_seen, status FROM gardeners WHERE user_id = ? ORDER BY created_at DESC').all(user_id)
  } catch (e) {
    const msg = String(e && e.message || '')
    if (msg.includes('no such column') && msg.includes('status')) {
      const rows = db.prepare('SELECT gardener_id, user_id, platform, created_at, last_seen FROM gardeners WHERE user_id = ? ORDER BY created_at DESC').all(user_id)
      return rows.map((r) => Object.assign({}, r, { status: 'active' }))
    }
    throw e
  }
}

function setGardenerStatus(gardener_id, status) {
  const gid = String(gardener_id || '').trim()
  if (!gid) return false
  db.prepare('UPDATE gardeners SET status = ? WHERE gardener_id = ?').run(status, gid)
  return true
}

function deleteGardenerOwned(user_id, gardener_id) {
  const gid = String(gardener_id || '').trim()
  if (!gid) return false
  const row = db.prepare('SELECT gardener_id FROM gardeners WHERE gardener_id = ? AND user_id = ?').get(gid, user_id)
  if (!row) return false
  const txn = db.transaction(() => {
    try { db.prepare('DELETE FROM bindings WHERE gardener_id = ?').run(gid) } catch (_) {}
    db.prepare('DELETE FROM gardeners WHERE gardener_id = ?').run(gid)
  })
  txn()
  return true
}

function getGardener(gardener_id) {
  const gid = String(gardener_id || '').trim()
  if (!gid) return null
  try { return db.prepare('SELECT gardener_id, user_id, platform, created_at, last_seen FROM gardeners WHERE gardener_id = ?').get(gid) } catch { return null }
}

// Admin helpers for gardeners
function setGardenerUser(gardener_id, user_id) {
  const gid = String(gardener_id || '').trim()
  if (!gid) return false
  db.prepare('UPDATE gardeners SET user_id = ? WHERE gardener_id = ?').run(user_id || null, gid)
  return true
}

function deleteBindingsForGardener(gardener_id) {
  const gid = String(gardener_id || '').trim()
  if (!gid) return 0
  const info = db.prepare('DELETE FROM bindings WHERE gardener_id = ?').run(gid)
  return info.changes || 0
}

function deleteGardener(gardener_id) {
  const gid = String(gardener_id || '').trim()
  if (!gid) return false
  const txn = db.transaction(() => {
    try { db.prepare('DELETE FROM bindings WHERE gardener_id = ?').run(gid) } catch (_) {}
    const info = db.prepare('DELETE FROM gardeners WHERE gardener_id = ?').run(gid)
    return info.changes > 0
  })
  return txn()
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
  setInstallationSecret,
  setInstallationUser,
  setInstallationStatus,
  setInstallationConfig,
  getInstallation,
  findRecentInstallationByUser,
  countInstallationsByUser,
  listInstallationsByUser,
  revokeInstallationOwned,
  deleteInstallationOwned,
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
  // gardeners admin
  listGardeners,
  getGardenerWithCounts,
  listGardenersByUser,
  setGardenerStatus,
  getGardener,
  setGardenerUser,
  deleteBindingsForGardener,
  deleteGardener,
  deleteGardenerOwned,
  reassignBinding,
  // bans & admin helpers
  setBan,
  removeBan,
  listBans,
  isBanned,
  deleteUserAndRelated,
  revokeAllInstallationsByUser,
}
