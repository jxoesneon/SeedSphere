#!/usr/bin/env node
import path from 'node:path'
import http from 'node:http'
import crypto from 'node:crypto'
import { fileURLToPath } from 'node:url'
import fs from 'node:fs/promises'
import express from 'express'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const axios = require('axios')
const boosts = require('./lib/boosts.cjs')
const { isTrackerUrl, unique, filterByHealth, getHealthStats } = require('./lib/health.cjs')
const { getLastFetch, setLastFetch } = require('./lib/trackers_meta.cjs')
const addonInterface = require('./addon.cjs')
const { filterAvailableProviders, aggregateStreams } = require('./lib/aggregate.cjs')
const {
  initDb,
  upsertDevice,
  upsertInstallation,
  createPairing,
  getPairing,
  completePairing,
  expireOldPairings,
  touchRoom,
  setCacheRow,
  writeAudit,
  getLatestLinkedPairingByInstall,
  // linking model
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
  getCacheRow,
  setCacheRowWeeklyCapped,
} = require('./lib/db.cjs')
const { initCrypto } = require('./lib/crypto.cjs')
const cookieParser = require('cookie-parser')
const authRouter = require('./routes/auth.cjs')
const keysRouter = require('./routes/keys.cjs')
const { subscribe, publish } = require('./lib/rooms.cjs')
const { normalize } = require('./lib/normalize.cjs')
const { nanoid } = require('nanoid')
const jwt = require('jsonwebtoken')
const { fetchTrackers, DEFAULT_TRACKERS_URL, VARIANT_URLS } = require('./lib/trackers.cjs')
const torrentio = require('./providers/torrentio.cjs')
const yts = require('./providers/yts.cjs')
const eztv = require('./providers/eztv.cjs')
const nyaa = require('./providers/nyaa.cjs')
const x1337 = require('./providers/x1337.cjs')
const piratebay = require('./providers/piratebay.cjs')
const torrentgalaxy = require('./providers/torrentgalaxy.cjs')
const torlock = require('./providers/torlock.cjs')
const magnetdl = require('./providers/magnetdl.cjs')
const anidex = require('./providers/anidex.cjs')
const tokyotosho = require('./providers/tokyotosho.cjs')
const zooqle = require('./providers/zooqle.cjs')
const rutor = require('./providers/rutor.cjs')

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const isProd = process.env.NODE_ENV === 'production'
// Port is determined inside createServer to allow tests to override

export async function createServer(opts = {}) {
  const app = express()
  const httpServer = http.createServer(app)

  // Compute effective listen port (supports 0 and explicit overrides)
  let listenPort
  if (opts && Object.prototype.hasOwnProperty.call(opts, 'port')) {
    listenPort = Number(opts.port)
  } else if (process.env.PORT !== undefined) {
    listenPort = Number(process.env.PORT)
  } else {
    listenPort = 8080
  }
  if (!Number.isFinite(listenPort)) listenPort = 8080

  // CORS — permissive for private testing; audit every CORS request
  app.use((req, res, next) => {
    try {
      const origin = req.headers.origin || ''
      const allow = origin || '*'
      res.setHeader('Access-Control-Allow-Origin', allow)
      res.setHeader('Vary', 'Origin')
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-SeedSphere-G, X-SeedSphere-Id, X-SeedSphere-Ts, X-SeedSphere-Nonce, X-SeedSphere-Sig')
      // Optional: do not set Allow-Credentials to keep wildcard compatibility
      try { writeAudit('cors', { ip: req.ip, origin, method: req.method, path: req.originalUrl || req.url }) } catch (_) {}
      if (req.method === 'OPTIONS') return res.sendStatus(204)
    } catch (_) { /* ignore */ }
    next()
  })

  // Content Security Policy: allow app assets and Ko‑fi overlay (production only)
  if (isProd) {
    app.use((req, res, next) => {
      try {
        const csp = [
          "default-src 'self'",
          "script-src 'self' 'unsafe-inline' https://storage.ko-fi.com https://ko-fi.com",
          "style-src 'self' 'unsafe-inline' https:",
          "img-src 'self' data: https:",
          "font-src 'self' data: https:",
          "connect-src 'self' https: wss:",
          "frame-src https://ko-fi.com https://storage.ko-fi.com"
        ].join('; ')
        res.setHeader('Content-Security-Policy', csp)
        // Additional hardening headers
        res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload')
        res.setHeader('X-Content-Type-Options', 'nosniff')
        res.setHeader('Referrer-Policy', 'no-referrer')
        res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=(), fullscreen=(self)')
        res.setHeader('X-Frame-Options', 'DENY')
      } catch (_) { /* ignore */ }
      next()
    })
  }

  // Activity tracker to prioritize real addon requests over background prefetch
  let lastActiveTs = Date.now()
  const touchActive = () => { lastActiveTs = Date.now() }
  app.use((req, _res, next) => {
    try {
      const p = req.path || ''
      if (p.startsWith('/stream') || p.startsWith('/api')) touchActive()
    } catch (_) { /* ignore */ }
    next()
  })

  // Signed heartbeat to update presence/health per gardener
  app.post('/api/rooms/:gardener_id/heartbeat', (req, res) => {
    if (!rateLimit(`hb:${req.ip}`, 300, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      const headerG = String(req.get('X-SeedSphere-G') || '').trim()
      const seedling_id = String(req.get('X-SeedSphere-Id') || '').trim()
      if (!gardener_id || !headerG || !seedling_id) return res.status(400).json({ ok: false, error: 'missing_identities' })
      if (gardener_id !== headerG) return res.status(401).json({ ok: false, error: 'mismatch_ids' })
      const secret = getBindingSecret(gardener_id, seedling_id)
      if (!secret) return res.status(401).json({ ok: false, error: 'no_binding' })
      if (!verifySignature(secret, req)) return res.status(401).json({ ok: false, error: 'bad_signature' })
      try { touchGardener(gardener_id) } catch (_) {}
      publish(gardener_id, 'heartbeat', { t: Date.now(), seedling_id })
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // --- Link-token endpoints ---
  app.post('/api/link/start', (req, res) => {
    if (!rateLimit(`link-start:${req.ip}`, 3, 60_000)) { res.setHeader('Retry-After', '60'); return res.status(429).json({ ok: false, error: 'rate_limited' }) }
    try {
      const body = req.body || {}
      const gardener_id = String(body.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      upsertGardener(gardener_id, String(body.platform || null))
      const token = crypto.randomBytes(32).toString('base64url')
      const rec = createLinkToken(token, gardener_id, 10 * 60_000)
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, token: rec.token, gardener_id: rec.gardener_id, expires_at: rec.expires_at })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  app.post('/api/link/complete', (req, res) => {
    if (!rateLimit(`link-complete:${req.ip}`, 10, 10 * 60_000)) { res.setHeader('Retry-After', '600'); return res.status(429).json({ ok: false, error: 'rate_limited' }) }
    try {
      const body = req.body || {}
      const token = String(body.token || '').trim()
      const seedling_id = String(body.seedling_id || '').trim()
      if (!token || !seedling_id) return res.status(400).json({ ok: false, error: 'missing_input' })
      const tok = getLinkToken(token)
      if (!tok) return res.status(410).json({ ok: false, error: 'invalid_or_expired' })
      if (countBindingsForGardener(tok.gardener_id) >= 10) return res.status(429).json({ ok: false, error: 'gardener_bindings_cap' })
      if (countBindingsForSeedling(seedling_id) >= 10) return res.status(429).json({ ok: false, error: 'seedling_bindings_cap' })
      upsertSeedling(seedling_id)
      const secret = crypto.randomBytes(32).toString('base64url')
      createBinding(tok.gardener_id, seedling_id, secret)
      deleteLinkToken(token)
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, gardener_id: tok.gardener_id, seedling_id, secret })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  app.get('/api/link/status', (req, res) => {
    if (!rateLimit(`link-status:${req.ip}`, 60, 60_000)) { res.setHeader('Retry-After', '60'); return res.status(429).json({ ok: false, error: 'rate_limited' }) }
    try {
      const gardener_id = String(req.query.gardener_id || '').trim()
      const seedling_id = String(req.query.seedling_id || '').trim()
      const out = { ok: true }
      if (gardener_id) out.linked_seedlings = listBindingsByGardener(gardener_id).map(b => b.seedling_id)
      if (seedling_id) out.linked_gardeners = listBindingsBySeedling(seedling_id).map(b => b.gardener_id)
      res.setHeader('Cache-Control', 'no-store')
      return res.json(out)
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Pairing status (read-only)
  app.get('/api/pair/status', (req, res) => {
    if (!rateLimit(`pair-status:${req.ip}`, 60, 60_000)) {
      res.setHeader('Retry-After', '60')
      return res.status(429).json({ ok: false, error: 'rate_limited' })
    }
    try {
      const install_id = String(req.query.install_id || '').trim()
      if (!install_id) {
        res.setHeader('Cache-Control', 'no-store')
        return res.json({ ok: true, paired: false })
      }
      expireOldPairings()
      const row = getLatestLinkedPairingByInstall(install_id)
      res.setHeader('Cache-Control', 'no-store')
      if (!row) return res.json({ ok: true, paired: false })
      return res.json({ ok: true, paired: true, device_id: row.device_id, install_id: row.install_id })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Core middleware
  app.use(express.json({ limit: '1mb' }))
  app.use(cookieParser())

  // Initialize storage and crypto
  try { initDb(path.join(__dirname, 'data')) } catch (e) { console.error('DB init failed:', e.message) }
  try { await initCrypto() } catch (e) { console.error('Crypto init failed:', e.message) }

  // Simple in-memory rate limiter (must be defined before routes use it)
  const rlStore = new Map() // key -> { ts, count }
  function rateLimit(key, limit = 60, windowMs = 60_000) {
    const now = Date.now()
    const rec = rlStore.get(key)
    if (!rec || (now - rec.ts) > windowMs) { rlStore.set(key, { ts: now, count: 1 }); return true }
    if (rec.count >= limit) return false
    rec.count += 1
    return true
  }

  // In-memory nonce store for HMAC replay protection (5 minutes TTL)
  const nonceStore = new Map() // nonce -> ts
  function rememberNonce(nonce) {
    const now = Date.now()
    if (!nonce) return false
    // Cleanup occasionally
    if (nonceStore.size > 5000) {
      for (const [n, ts] of nonceStore) { if (now - ts > 5 * 60_000) nonceStore.delete(n) }
    }
    if (nonceStore.has(nonce)) return false
    nonceStore.set(nonce, now)
    return true
  }
  // --- HMAC Signing verification helpers ---
  function sha256(data) { return crypto.createHash('sha256').update(data).digest('hex') }
  function canonicalizeQuery(url) {
    try {
      const u = new URL(url, 'http://local')
      const entries = []
      for (const [k, v] of u.searchParams.entries()) entries.push([k, v])
      entries.sort((a, b) => a[0] === b[0] ? (a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0) : (a[0] < b[0] ? -1 : 1))
      return entries.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&')
    } catch (_) { return '' }
  }
  function buildCanonicalString(req) {
    const ts = String(req.get('X-SeedSphere-Ts') || '')
    const nonce = String(req.get('X-SeedSphere-Nonce') || '')
    const method = String(req.method || 'GET').toUpperCase()
    const pathOnly = (req.originalUrl || req.url || '').split('?')[0]
    const q = canonicalizeQuery(req.originalUrl || req.url || '')
    const bodyRaw = req.rawBody || JSON.stringify(req.body || {})
    const bodyHash = sha256(bodyRaw || '')
    return [ts, nonce, method, pathOnly, q, bodyHash].join('\n')
  }
  function verifySignature(secret, req) {
    const sig = String(req.get('X-SeedSphere-Sig') || '')
    const ts = Number(req.get('X-SeedSphere-Ts') || '0')
    const nonce = String(req.get('X-SeedSphere-Nonce') || '')
    if (!sig || !ts || !nonce) return false
    const now = Date.now()
    if (Math.abs(now - ts) > 120_000) return false // ±120s skew
    if (!rememberNonce(nonce)) return false
    const canonical = buildCanonicalString(req)
    const mac = crypto.createHmac('sha256', Buffer.from(secret)).update(canonical).digest('base64')
    const macUrl = mac.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
    try { return crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(macUrl)) } catch { return false }
  }

  // Auth and Keys API
  app.use('/api/auth', authRouter)
  app.use('/api/keys', keysRouter)

  // --- Telemetry collector ---
  app.post('/api/telemetry/collect', async (req, res) => {
    if (!rateLimit(`tele:${req.ip}`, 120, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    const sharedKey = process.env.TELEMETRY_KEY || ''
    const provided = String(req.get('x-telemetry-key') || req.query.key || '')
    if (sharedKey && provided !== sharedKey) return res.status(401).json({ ok: false, error: 'unauthorized' })
    try {
      const sample = Math.max(0, Math.min(1, Number(process.env.TELEMETRY_SAMPLE || '1')))
      if (Math.random() <= sample) {
        try { writeAudit('telemetry', { ip: req.ip, ua: req.get('user-agent') || '', body: req.body }) } catch (_) {}
      }
      const url = process.env.TELEMETRY_URL
      if (url) {
        try { await axios.post(url, req.body, { timeout: 2000 }).catch(() => {}) } catch (_) {}
      }
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // --- Greenhouse: Executor register ---
  app.post('/api/executor/register', (req, res) => {
    if (!rateLimit(`reg:${req.ip}`, 30, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const agent = String(req.get('user-agent') || '')
      const device_id = nanoid(16)
      const row = upsertDevice({ device_id, agent })
      return res.json({ ok: true, device_id: row.device_id })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // --- Greenhouse: Pairing routes ---
  // DEPRECATED in favor of link-token flow (kept for backward-compat)
  app.post('/api/pair/start', (req, res) => {
    // Stricter limit: 5 per minute per IP
    if (!rateLimit(`pair-start:${req.ip}`, 5, 60_000)) {
      res.setHeader('Retry-After', '60')
      return res.status(429).json({ ok: false, error: 'rate_limited' })
    }
    try {
      const body = req.body || {}
      const install_id = String(body.install_id || '').trim() || nanoid(12)
      upsertInstallation({ install_id })
      const code = nanoid(6).replace(/[-_]/g, 'A').toUpperCase()
      const ttlMs = 10 * 60_000
      const exp = Date.now() + ttlMs
      createPairing({ pair_code: code, install_id, expires_at: exp })
      return res.json({ ok: true, pair_code: code, expires_at: exp, install_id })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  app.post('/api/pair/complete', (req, res) => {
    // Stricter window: 10 per hour per IP
    if (!rateLimit(`pair-complete:${req.ip}`, 10, 60 * 60_000)) {
      res.setHeader('Retry-After', '3600')
      return res.status(429).json({ ok: false, error: 'rate_limited' })
    }
    try {
      expireOldPairings()
      const body = req.body || {}
      const pair_code = String(body.pair_code || '').trim().toUpperCase()
      const device_id = String(body.device_id || '').trim()
      if (!pair_code || !device_id) return res.status(400).json({ ok: false, error: 'missing_input' })
      const row = getPairing(pair_code)
      if (!row) return res.status(404).json({ ok: false, error: 'not_found' })
      if (row.expires_at < Date.now()) return res.status(410).json({ ok: false, error: 'expired' })
      completePairing(pair_code, device_id)
      return res.json({ ok: true, pair_code, device_id, install_id: row.install_id })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // --- Greenhouse: SSE rooms ---
  // New canonical SSE route by gardener_id
  app.get('/api/rooms/:gardener_id/events', (req, res) => {
    if (!rateLimit(`room:${req.ip}`, 300, 60_000)) return res.status(429).end()
    const gardener_id = String(req.params.gardener_id || '').trim() || 'default'
    res.setHeader('Content-Type', 'text/event-stream')
    res.setHeader('Cache-Control', 'no-cache, no-transform')
    res.setHeader('Connection', 'keep-alive')
    res.flushHeaders && res.flushHeaders()
    try { res.write(`retry: 2000\n\n`) } catch (_) {}
    const writeEvent = (event, data) => { try { if (event) res.write(`event: ${event}\n`); res.write(`data: ${JSON.stringify(data)}\n\n`) } catch (_) {} }
    writeEvent('init', { gardener_id, t: Date.now(), clients: 1 })
    try { touchRoom(gardener_id); touchGardener(gardener_id) } catch (_) {}
    const unsubscribe = subscribe(gardener_id, res)
    const hb = setInterval(() => { try { touchGardener(gardener_id); res.write(`:keepalive\n\n`) } catch (_) {} }, 15000)
    const close = () => { try { clearInterval(hb) } catch (_) {} try { unsubscribe && unsubscribe() } catch (_) {} try { res.end() } catch (_) {} }
    req.on('close', close)
    req.on('aborted', close)
  })

  // Backward-compat SSE route
  app.get('/api/rooms/:room_id/events', (req, res) => {
    if (!rateLimit(`room:${req.ip}`, 120, 60_000)) return res.status(429).end()
    const room_id = String(req.params.room_id || '').trim() || 'default'
    res.setHeader('Content-Type', 'text/event-stream')
    res.setHeader('Cache-Control', 'no-cache, no-transform')
    res.setHeader('Connection', 'keep-alive')
    res.flushHeaders && res.flushHeaders()
    // Recommend reconnect delay
    try { res.write(`retry: 2000\n\n`) } catch (_) {}

    const writeEvent = (event, data) => {
      try {
        if (event) res.write(`event: ${event}\n`)
        res.write(`data: ${JSON.stringify(data)}\n\n`)
      } catch (_) { /* ignore */ }
    }

    writeEvent('init', { room_id, t: Date.now(), clients: 1 })
    try { touchRoom(room_id) } catch (_) {}
    const unsubscribe = subscribe(room_id, res)
    const hb = setInterval(() => { try { res.write(`:keepalive\n\n`) } catch (_) {} }, 15000)
    const close = () => { try { clearInterval(hb) } catch (_) {} try { unsubscribe && unsubscribe() } catch (_) {} try { res.end() } catch (_) {} }
    req.on('close', close)
    req.on('aborted', close)
  })

  // --- Greenhouse: Tasks (issue and result) ---
  app.post('/api/tasks/request', (req, res) => {
    if (!rateLimit(`task-req:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const body = req.body || {}
      const room_id = String(body.room_id || nanoid(10))
      const task = {
        type: String(body.type || 'normalize'),
        params: body.params || {},
        aud: 'executor',
      }
      const secret = process.env.AUTH_JWT_SECRET || 'dev-secret'
      const token = jwt.sign(task, secret, { expiresIn: '5m' })
      // Publish notify event to room that a task is available (optional)
      publish(room_id, 'task', { token, type: task.type })
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, token, room_id })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  app.post('/api/tasks/result', (req, res) => {
    if (!rateLimit(`task-res:${req.ip}`, 120, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const body = req.body || {}
      const token = String(body.token || '').trim()
      const room_id = String(body.room_id || '').trim()
      const secret = process.env.AUTH_JWT_SECRET || 'dev-secret'
      let payload
      try { payload = jwt.verify(token, secret, { audience: undefined }) } catch (e) { return res.status(401).json({ ok: false, error: 'invalid_token' }) }
      const data = body.data || {}
      // If result contains release info, normalize it
      let normalized = null
      if (data && (data.title || data.extras || data.infohash)) {
        try { normalized = normalize(data) } catch (_) { /* ignore */ }
      }
      // Store in cache (best-effort)
      try { setCacheRow(`task:${room_id}:${Date.now()}`, { normalized, raw: data }, 5 * 60_000) } catch (_) {}
      // Publish to room
      publish(room_id || 'default', 'result', { ok: true, normalized, raw: data })
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Trackers sweep endpoint
  app.get('/api/trackers/sweep', async (req, res) => {
    if (!rateLimit(`sweep:${req.ip}`, 30, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const inputUrl = String(req.query.url || '').trim()
      const variant = String(req.query.variant || '').trim().toLowerCase()
      const mode = String(req.query.mode || 'basic').toLowerCase()
      const limit = Math.max(0, parseInt(String(req.query.limit || '0'), 10) || 0)
      const full = String(req.query.full || '0') === '1'

      // Map variants to curated public lists with mirrors
      const mk = (name) => ([
        `https://raw.githubusercontent.com/ngosang/trackerslist/master/${name}.txt`,
        `https://ngosang.github.io/trackerslist/${name}.txt`,
        `https://cdn.jsdelivr.net/gh/ngosang/trackerslist@master/${name}.txt`,
      ])
      const variantMap = {
        all: mk('trackers_all'),
        best: mk('trackers_best'),
        all_udp: mk('trackers_all_udp'),
        all_http: mk('trackers_all_http'),
        all_https: mk('trackers_all_https'),
        all_ws: mk('trackers_all_ws'),
        all_i2p: mk('trackers_all_i2p'),
        all_ip: mk('trackers_all_ip'),
        best_ip: mk('trackers_best_ip'),
      }

      let sourceUrl = inputUrl
      let sources = []
      if (!sourceUrl) {
        if (!variant) return res.status(400).json({ ok: false, error: 'missing_input' })
        sources = variantMap[variant] || []
        if (!sources.length) return res.status(400).json({ ok: false, error: 'invalid_variant' })
      } else {
        sources = [sourceUrl]
      }

      // Try primary then mirrors
      let response
      let lastErr
      for (const s of sources) {
        try {
          const u = new URL(s)
          if (!/^https?:$/i.test(u.protocol)) throw new Error('invalid_scheme')
          if (s.length > 1024) throw new Error('url_too_long')
        } catch (e) { lastErr = e; continue }
        try {
          response = await axios.get(s, { timeout: 12000 })
          sourceUrl = s
          break
        } catch (e) { lastErr = e; continue }
      }
      if (!response) {
        const msg = lastErr && lastErr.message ? lastErr.message : 'fetch_failed'
        return res.status(502).json({ ok: false, error: msg })
      }
      const text = typeof response.data === 'string' ? response.data : String(response.data)
      const urls = unique(text.split('\n').map((t) => t.trim()).filter((t) => t && !t.startsWith('#') && isTrackerUrl(t)))
      const healthy = await filterByHealth(urls, mode, limit)
      const payload = { ok: true, total: urls.length, healthy: healthy.length, limit, mode, sample: healthy.slice(0, 10) }
      if (full) payload.list = healthy
      try { setLastFetch(Date.now()) } catch (_) {}
      res.setHeader('Cache-Control', 'no-store')
      return res.json(payload)
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Trackers sweep streaming progress (SSE) — placed after rateLimit and sweep endpoint
  app.get('/api/trackers/sweep/stream', async (req, res) => {
    // Higher threshold to tolerate EventSource auto-reconnects
    if (!rateLimit(`sweep-stream:${req.ip}`, 300, 60_000)) return res.status(429).end()
    try {
      const inputUrl = String(req.query.url || '').trim()
      const variant = String(req.query.variant || '').trim().toLowerCase()
      const mode = String(req.query.mode || 'basic').toLowerCase()
      const limit = Math.max(0, parseInt(String(req.query.limit || '0'), 10) || 0)
      const full = String(req.query.full || '0') === '1'

      // Prepare SSE immediately so even early errors use event-stream
      res.setHeader('Content-Type', 'text/event-stream')
      res.setHeader('Cache-Control', 'no-cache, no-transform')
      res.setHeader('Connection', 'keep-alive')
      res.flushHeaders && res.flushHeaders()
      // Hint browser to retry after 2s on disconnect
      try { res.write(`retry: 2000\n\n`) } catch (_) {}

      const writeEvent = (event, data) => {
        try {
          if (event) res.write(`event: ${event}\n`)
          res.write(`data: ${JSON.stringify(data)}\n\n`)
        } catch (_) { /* ignore */ }
      }
      const writeComment = (text) => {
        try { res.write(`:${text || ''}\n\n`) } catch (_) { /* ignore */ }
      }

      const mk = (name) => ([
        `https://raw.githubusercontent.com/ngosang/trackerslist/master/${name}.txt`,
        `https://ngosang.github.io/trackerslist/${name}.txt`,
        `https://cdn.jsdelivr.net/gh/ngosang/trackerslist@master/${name}.txt`,
      ])
      const variantMap = {
        all: mk('trackers_all'),
        best: mk('trackers_best'),
        all_udp: mk('trackers_all_udp'),
        all_http: mk('trackers_all_http'),
        all_https: mk('trackers_all_https'),
        all_ws: mk('trackers_all_ws'),
        all_i2p: mk('trackers_all_i2p'),
        all_ip: mk('trackers_all_ip'),
        best_ip: mk('trackers_best_ip'),
      }

      let sourceUrl = inputUrl
      let sources = []
      if (!sourceUrl) {
        if (!variant) { writeEvent('error', { ok: false, error: 'missing_input' }); return res.end() }
        sources = variantMap[variant] || []
        if (!sources.length) { writeEvent('error', { ok: false, error: 'invalid_variant' }); return res.end() }
      } else {
        sources = [sourceUrl]
      }

      let response
      let lastErr
      for (const s of sources) {
        try {
          const u = new URL(s)
          if (!/^https?:$/i.test(u.protocol)) throw new Error('invalid_scheme')
          if (s.length > 1024) throw new Error('url_too_long')
        } catch (e) { lastErr = e; continue }
        try {
          response = await axios.get(s, { timeout: 12000 })
          sourceUrl = s
          break
        } catch (e) { lastErr = e; continue }
      }
      if (!response) { writeEvent('error', { ok: false, error: (lastErr && lastErr.message) || 'fetch_failed' }); return res.end() }
      const text = typeof response.data === 'string' ? response.data : String(response.data)
      const urls = unique(text.split('\n').map((t) => t.trim()).filter((t) => t && !t.startsWith('#') && isTrackerUrl(t)))

      // Send init with total
      writeEvent('init', { total: urls.length, mode, limit })
      // Emit an initial progress snapshot
      writeEvent('progress', { processed: 0, healthy: 0, total: urls.length })

      let cancelled = false
      const onClose = () => { cancelled = true; try { res.end() } catch (_) {} }
      req.on('close', onClose)
      req.on('aborted', onClose)

      // Heartbeat to keep intermediaries from closing idle connections
      const hb = setInterval(() => { if (!cancelled) writeComment('keepalive') }, 15000)

      try {
        const healthy = await filterByHealth(urls, mode, limit, (p) => {
          if (cancelled) return
          writeEvent('progress', { processed: p.processed, healthy: p.healthy, total: urls.length })
        })
        if (cancelled) return
        try { setLastFetch(Date.now()) } catch (_) {}
        const payload = { ok: true, total: urls.length, healthy: healthy.length, limit, mode }
        if (full) payload.list = healthy
        else payload.sample = healthy.slice(0, 10)
        writeEvent('final', payload)
      } catch (e) {
        writeEvent('error', { ok: false, error: e.message || 'sweep_failed' })
      } finally {
        try { clearInterval(hb) } catch (_) {}
        try { res.end() } catch (_) {}
      }
    } catch (_) {
      return res.status(500).end()
    }
  })

  // Health endpoint (extended)
  const pkg = require('../package.json')
  app.get(['/health'], (_req, res) => {
    res.setHeader('Cache-Control', 'public, max-age=5, stale-while-revalidate=60, stale-if-error=120')
    res.json({ ok: true, version: pkg.version || '', uptime_s: Math.round(process.uptime()), last_trackers_fetch_ts: getLastFetch() || 0 })
  })

  // Configure redirect: launch SPA pair screen instead of SDK's default page
  // Stremio's Configure button points to '/configure'. We redirect to '/pair'
  // and preserve gardener_id and seedling_id (ensuring cookie exists). The Pair
  // page will decide to forward to Configure if already linked.
  app.get('/configure', (req, res) => {
    try {
      const gardener_id = String(req.query.gardener_id || '').trim()
      // Ensure seedling_id cookie exists
      let seedling_id = ''
      try { seedling_id = String((req.cookies && req.cookies.seedling_id) || '').trim() } catch (_) { seedling_id = '' }
      if (!seedling_id) {
        try {
          seedling_id = nanoid()
          res.cookie('seedling_id', seedling_id, { maxAge: 365 * 24 * 60 * 60 * 1000, sameSite: 'lax', secure: isProd, httpOnly: false, path: '/' })
        } catch (_) { /* ignore */ }
      }
      const baseOrigin = (() => {
        try {
          const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
          let host = (req.headers['x-forwarded-host'] || req.headers.host || 'localhost').toString()
          host = host.replace(/^localhost(?::|$)/, (m) => m.replace('localhost', '127.0.0.1'))
          return `${proto}://${host}`
        } catch (_) { return '' }
      })()
      const params = new URLSearchParams()
      if (gardener_id) params.set('gardener_id', gardener_id)
      if (seedling_id) params.set('seedling_id', seedling_id)
      const qs = params.toString()
      const target = `${baseOrigin}/pair${qs ? ('?' + qs) : ''}`
      res.redirect(302, target)
    } catch (_) {
      res.redirect(302, '/pair')
    }
  })

  // Auto-pair endpoint: bind gardener_id and seedling_id idempotently
  app.post('/api/link/auto', (req, res) => {
    if (!rateLimit(`link-auto:${req.ip}`, 20, 60_000)) { res.setHeader('Retry-After', '60'); return res.status(429).json({ ok: false, error: 'rate_limited' }) }
    try {
      const body = req.body || {}
      const gardener_id = String(body.gardener_id || '').trim()
      let seedling_id = String(body.seedling_id || '').trim()
      if (!seedling_id) {
        // Fallback to cookie if not provided
        try { seedling_id = String((req.cookies && req.cookies.seedling_id) || '').trim() } catch (_) { /* ignore */ }
      }
      if (!gardener_id || !seedling_id) return res.status(400).json({ ok: false, error: 'missing_input' })
      // Caps
      if (countBindingsForGardener(gardener_id) >= 10) return res.status(429).json({ ok: false, error: 'gardener_bindings_cap' })
      if (countBindingsForSeedling(seedling_id) >= 10) return res.status(429).json({ ok: false, error: 'seedling_bindings_cap' })
      // Upserts
      upsertGardener(gardener_id, 'web')
      upsertSeedling(seedling_id)
      // Already linked?
      const existing = listBindingsByGardener(gardener_id).some(b => b.seedling_id === seedling_id)
      if (!existing) {
        const secret = crypto.randomBytes(32).toString('base64url')
        createBinding(gardener_id, seedling_id, secret)
      }
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, gardener_id, seedling_id })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Recent boosts
  app.get('/api/boosts/recent', (_req, res) => {
    if (!rateLimit(`recent:${_req.ip}`, 120, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      res.setHeader('Cache-Control', 'no-store')
      res.json({ ok: true, items: boosts.recent() })
    } catch (e) {
      res.status(500).json({ ok: false, error: e.message })
    }
  })

  // SSE events for boosts
  app.get('/api/boosts/events', (req, res) => {
    if (!rateLimit(`events:${req.ip}`, 60, 60_000)) return res.status(429).end()
    res.setHeader('Content-Type', 'text/event-stream')
    res.setHeader('Cache-Control', 'no-cache, no-transform')
    res.setHeader('Connection', 'keep-alive')
    res.flushHeaders && res.flushHeaders()

    const writeEvent = (event, data) => {
      try {
        if (event) res.write(`event: ${event}\n`)
        res.write(`data: ${JSON.stringify(data)}\n\n`)
      } catch (_) { /* ignore */ }
    }

    // Initial server info
    writeEvent('server-info', { version: pkg.version || '' })
    writeEvent('snapshot', { items: boosts.recent() })

    const onBoost = (it) => writeEvent('boost', it)
    const unsubscribe = boosts.subscribe(onBoost)
    const timer = setInterval(() => {
      writeEvent('ping', { t: Date.now() })
      writeEvent('server-info', { version: pkg.version || '' })
    }, 20000)

    const close = () => {
      clearInterval(timer)
      try { unsubscribe && unsubscribe() } catch (_) { /* ignore */ }
      try { res.end() } catch (_) { /* ignore */ }
    }
    req.on('close', close)
    req.on('aborted', close)
  })

  // Detect available upstream providers (best-effort)
  app.get('/api/providers/detect', async (req, res) => {
    if (!rateLimit(`providers:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const providers = [
        torrentio,
        yts,
        eztv,
        nyaa,
        x1337,
        piratebay,
        torrentgalaxy,
        torlock,
        magnetdl,
        anidex,
        tokyotosho,
        zooqle,
        rutor,
      ]
      // Try probe when available and capture timing
      const tests = await Promise.all(providers.map(async (p) => {
        const t0 = Date.now()
        try {
          let ok = true
          if (typeof p.probe === 'function') {
            const r = await p.probe(3000)
            ok = !!(r && r.ok)
          }
          return { name: p.name || 'Provider', ok, ms: Date.now() - t0 }
        } catch (_) {
          const name = (p && p.name) ? p.name : 'Provider'
          return { name, ok: false, ms: Date.now() - t0 }
        }
      }))
      res.setHeader('Cache-Control', 'public, max-age=60, stale-while-revalidate=120, stale-if-error=300')
      res.json({ ok: true, providers: tests })
    } catch (e) {
      res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Health stats for tracker validator cache
  app.get('/api/trackers/health', (_req, res) => {
    try {
      const stats = getHealthStats()
      res.setHeader('Cache-Control', 'public, max-age=30, stale-while-revalidate=120, stale-if-error=300')
      res.json(stats)
    } catch (e) {
      res.status(500).json({ error: e.message })
    }
  })

  // URL validation for browser UI
  app.get('/api/validate', async (req, res) => {
    const target = (req.query.url || '').toString()
    if (!target) return res.status(400).json({ ok: false, error: 'Missing url' })
    try {
      const response = await axios.get(target, { timeout: 8000 })
      const text = typeof response.data === 'string' ? response.data : String(response.data)
      const lines = text.split('\n').map((t) => t.trim()).filter((t) => t && !t.startsWith('#'))
      const looksLikeTrackers = lines.filter((l) => /^(udp|http|https|ws):\/\//i.test(l))
      res.setHeader('Cache-Control', 'no-store')
      res.json({ ok: looksLikeTrackers.length > 0, count: looksLikeTrackers.length, sample: looksLikeTrackers.slice(0, 5) })
    } catch (e) {
      res.setHeader('Cache-Control', 'no-store')
      res.status(200).json({ ok: false, error: e.message })
    }
  })

  // Dynamic manifest: include gardener_id (non-standard field) without duplicating manifest
  app.get(['/manifest.json', '/manifest'], (req, res) => {
    try { console.log('[manifest] request', { ip: req.ip, ua: req.headers['user-agent'], q: req.query, accept: req.headers.accept || '' }) } catch (_) {}
    try {
      // If the manifest URL is opened in a browser/webview (Accept includes text/html),
      // redirect to /configure to show the UI instead of returning JSON.
      // Normal addon fetches (Accept: application/json) should get JSON.
      const accept = String(req.headers.accept || '').toLowerCase()
      if (accept.includes('text/html')) {
        let seedling_id = ''
        try { seedling_id = String(req.cookies.seedling_id || '').trim() } catch (_) {}
        if (!seedling_id) {
          try { seedling_id = nanoid(); res.cookie('seedling_id', seedling_id, { maxAge: 365 * 24 * 60 * 60 * 1000, sameSite: 'lax', secure: isProd, httpOnly: false, path: '/' }) } catch (_) {}
        }
        const gardener_id = String(req.query.gardener_id || '').trim()
        const baseOrigin = (() => {
          try {
            const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
            let host = (req.headers['x-forwarded-host'] || req.headers.host || 'localhost').toString()
            host = host.replace(/^localhost(?::|$)/, (m) => m.replace('localhost', '127.0.0.1'))
            return `${proto}://${host}`
          } catch (_) { return '' }
        })()
        const params = new URLSearchParams()
        if (gardener_id) params.set('gardener_id', gardener_id)
        if (seedling_id) params.set('seedling_id', seedling_id)
        const qs = params.toString()
        const target = `${baseOrigin}/configure${qs ? ('?' + qs) : ''}`
        return res.redirect(302, target)
      }
      const base = addonInterface && addonInterface.manifest ? addonInterface.manifest : (addonInterface && addonInterface.manifestRef ? addonInterface.manifestRef : null)
      const manifest = base ? { ...base } : {}
      const gardener_id = String(req.query.gardener_id || '').trim()
      const origin = (() => {
        try {
          const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
          let host = (req.headers['x-forwarded-host'] || req.headers.host || 'localhost').toString()
          // Normalize localhost to 127.0.0.1 for Stremio local addon allowance
          host = host.replace(/^localhost(?::|$)/, (m) => m.replace('localhost', '127.0.0.1'))
          return `${proto}://${host}`
        } catch (_) { return '' }
      })()

      // We inject dynamic fields below; any existing signature would be invalid.
      // Strip stremioAddonsConfig so Stremio does not attempt to verify a stale signature.
      try { delete manifest.stremioAddonsConfig } catch (_) { /* ignore */ }
      // Force absolute endpoint to root to avoid path-relative /stream under subpaths
      try { if (origin) manifest.endpoint = origin } catch (_) { /* ignore */ }

      // Ensure a per-client seedling_id (persisted in cookie)
      let seedling_id = ''
      try { seedling_id = String((req.cookies && req.cookies.seedling_id) || '').trim() } catch (_) { seedling_id = '' }
      if (!seedling_id) {
        try {
          seedling_id = nanoid()
          // 1 year, Lax, secure in prod
          res.cookie('seedling_id', seedling_id, { maxAge: 365 * 24 * 60 * 60 * 1000, sameSite: 'lax', secure: isProd, httpOnly: false, path: '/' })
        } catch (_) { /* ignore cookie set errors */ }
      }

      // Inject dynamic fields
      manifest.seedsphere = { ...(manifest.seedsphere || {}), original_gardener_id: gardener_id, seedling_id }
      // Choose asset base to avoid mixed-content on web.strem.io (HTTPS)
      const reqOrigin = String(req.headers.origin || '')
      const isWebStremio = reqOrigin === 'https://web.strem.io' || reqOrigin === 'https://web.stremio.com'
      const assetBase = isWebStremio ? 'https://seedsphere.fly.dev' : origin
      if (assetBase) {
        manifest.logo = `${assetBase}/assets/icon-256.png`
        manifest.background = `${assetBase}/assets/background-1024.jpg`
      }

      res.setHeader('Cache-Control', 'public, max-age=300, stale-while-revalidate=600')
      return res.json(manifest)
    } catch (e) {
      return res.status(500).json({ error: e.message })
    }
  })

  // Experimental manifest with additional non-official fields
  // Note: We deliberately strip stremioAddonsConfig since payload is dynamic.
  app.get([
    '/manifest.experiment.json',
    '/manifest.experiment',
    // New aliases so Stremio parses actual manifest.json filenames
    '/manifest.variant.experiment/manifest.json',
    '/manifest.variant.experiment/manifest'
  ], (req, res) => {
    try { console.log('[manifest.experiment] request', { ip: req.ip, ua: req.headers['user-agent'], q: req.query }) } catch (_) {}
    try {
      // If opened in a browser/webview (Accept includes text/html), redirect to /configure
      const accept = String(req.headers.accept || '').toLowerCase()
      if (accept.includes('text/html')) {
        let seedling_id = ''
        try { seedling_id = String(req.cookies.seedling_id || '').trim() } catch (_) {}
        if (!seedling_id) {
          try { seedling_id = nanoid(); res.cookie('seedling_id', seedling_id, { maxAge: 365 * 24 * 60 * 60 * 1000, sameSite: 'lax', secure: isProd, httpOnly: false, path: '/' }) } catch (_) {}
        }
        const gardener_id = String(req.query.gardener_id || '').trim()
        const baseOrigin = (() => {
          try {
            const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
            let host = (req.headers['x-forwarded-host'] || req.headers.host || 'localhost').toString()
            host = host.replace(/^localhost(?::|$)/, (m) => m.replace('localhost', '127.0.0.1'))
            return `${proto}://${host}`
          } catch (_) { return '' }
        })()
        const params = new URLSearchParams()
        if (gardener_id) params.set('gardener_id', gardener_id)
        if (seedling_id) params.set('seedling_id', seedling_id)
        const qs = params.toString()
        const target = `${baseOrigin}/configure${qs ? ('?' + qs) : ''}`
        return res.redirect(302, target)
      }
      const base = addonInterface && addonInterface.manifest ? addonInterface.manifest : (addonInterface && addonInterface.manifestRef ? addonInterface.manifestRef : null)
      const manifest = base ? { ...base } : {}
      const gardener_id = String(req.query.gardener_id || '').trim()

      // Determine absolute origin for asset URLs
      const origin = (() => {
        try {
          const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
          let host = (req.headers['x-forwarded-host'] || req.headers.host || 'localhost').toString()
          // Normalize localhost to 127.0.0.1 for Stremio local addon allowance
          host = host.replace(/^localhost(?::|$)/, (m) => m.replace('localhost', '127.0.0.1'))
          return `${proto}://${host}`
        } catch (_) { return '' }
      })()

      // We inject dynamic fields; any existing signature would be invalid. Strip it.
      try { delete manifest.stremioAddonsConfig } catch (_) { /* ignore */ }
      // Force absolute endpoint to root to avoid path-relative /stream under subpaths
      try { if (origin) manifest.endpoint = origin } catch (_) { /* ignore */ }

      // Ensure a per-client seedling_id (persisted in cookie)
      let seedling_id = ''
      try { seedling_id = String(req.cookies.seedling_id || '').trim() } catch (_) {}
      if (!seedling_id) {
        try {
          seedling_id = nanoid()
          // 1 year, Lax, secure in prod
          res.cookie('seedling_id', seedling_id, { maxAge: 365 * 24 * 60 * 60 * 1000, sameSite: 'lax', secure: isProd, httpOnly: false, path: '/' })
        } catch (_) { /* ignore cookie set errors */ }
      }

      // Inject dynamic fields for experiment channel
      manifest.seedsphere = { ...(manifest.seedsphere || {}), original_gardener_id: gardener_id, seedling_id, channel: 'experiment' }

      // Choose asset base to avoid mixed-content on web.strem.io (HTTPS)
      const reqOrigin2 = String(req.headers.origin || '')
      const isWebStremio2 = reqOrigin2 === 'https://web.strem.io' || reqOrigin2 === 'https://web.stremio.com'
      const assetBase = isWebStremio2 ? 'https://seedsphere.fly.dev' : origin
      if (assetBase) {
        manifest.logo = `${assetBase}/assets/icon-256.png`
        manifest.background = `${assetBase}/assets/background-1024.jpg`
      }

      // Endpoint is explicitly set to the absolute origin above

      // Experimental unofficial fields
      manifest.dontAnnounce = true
      manifest.listedOn = ["desktop", "web", "android"]
      manifest.isFree = true
      manifest.suggested = ["com.stremio.opensubtitlesv3"]
      manifest.searchDebounce = 300
      manifest.countrySpecific = false
      manifest.zipSpecific = false
      manifest.countrySpecificStreams = false

      // Behavior hints suitable for experiments (ensure configurable remains true)
      manifest.behaviorHints = Object.assign({}, manifest.behaviorHints || {}, {
        configurable: true,
      })

      res.setHeader('Cache-Control', 'public, max-age=60, stale-while-revalidate=300')
      return res.json(manifest)
    } catch (e) {
      return res.status(500).json({ error: e.message })
    }
  })

  // Parameterized manifest variants: add exactly one experimental/unofficial field at a time
  // Available keys: endpoint, dontAnnounce, listedOn, isFree, suggested, searchDebounce, countrySpecific, zipSpecific, countrySpecificStreams
  app.get([
    // New preferred patterns: directory with actual filename manifest.json
    '/manifest.variant.:key/manifest.json',
    '/manifest.variant.:key/manifest',
    // Backward compatibility
    '/manifest.variant/:key.json',
    '/manifest.variant/:key'
  ], (req, res) => {
    try { console.log('[manifest.variant] request', { key: req.params.key, ip: req.ip, ua: req.headers['user-agent'], q: req.query }) } catch (_) {}
    try {
      // If opened in a browser/webview (Accept includes text/html), redirect to /configure
      const accept = String(req.headers.accept || '').toLowerCase()
      if (accept.includes('text/html')) {
        let seedling_id = ''
        try { seedling_id = String(req.cookies.seedling_id || '').trim() } catch (_) {}
        if (!seedling_id) {
          try { seedling_id = nanoid(); res.cookie('seedling_id', seedling_id, { maxAge: 365 * 24 * 60 * 60 * 1000, sameSite: 'lax', secure: isProd, httpOnly: false, path: '/' }) } catch (_) {}
        }
        const gardener_id = String(req.query.gardener_id || '').trim()
        const baseOrigin = (() => {
          try {
            const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
            let host = (req.headers['x-forwarded-host'] || req.headers.host || 'localhost').toString()
            host = host.replace(/^localhost(?::|$)/, (m) => m.replace('localhost', '127.0.0.1'))
            return `${proto}://${host}`
          } catch (_) { return '' }
        })()
        const params = new URLSearchParams()
        if (gardener_id) params.set('gardener_id', gardener_id)
        if (seedling_id) params.set('seedling_id', seedling_id)
        const qs = params.toString()
        const target = `${baseOrigin}/configure${qs ? ('?' + qs) : ''}`
        return res.redirect(302, target)
      }
      const base = addonInterface && addonInterface.manifest ? addonInterface.manifest : (addonInterface && addonInterface.manifestRef ? addonInterface.manifestRef : null)
      const manifest = base ? { ...base } : {}
      const rawKey = String(req.params.key || '').trim()
      const key = rawKey.toLowerCase()
      const gardener_id = String(req.query.gardener_id || '').trim()

      // Determine absolute origin for asset URLs
      const origin = (() => {
        try {
          const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
          let host = (req.headers['x-forwarded-host'] || req.headers.host || 'localhost').toString()
          // Normalize localhost to 127.0.0.1 for Stremio local addon allowance
          host = host.replace(/^localhost(?::|$)/, (m) => m.replace('localhost', '127.0.0.1'))
          return `${proto}://${host}`
        } catch (_) { return '' }
      })()

      // We inject dynamic fields; any existing signature would be invalid. Strip it.
      try { delete manifest.stremioAddonsConfig } catch (_) { /* ignore */ }

      // Ensure a per-client seedling_id (persisted in cookie)
      let seedling_id = ''
      try { seedling_id = String(req.cookies.seedling_id || '').trim() } catch (_) {}
      if (!seedling_id) {
        try {
          seedling_id = nanoid()
          // 1 year, Lax, secure in prod
          res.cookie('seedling_id', seedling_id, { maxAge: 365 * 24 * 60 * 60 * 1000, sameSite: 'lax', secure: isProd, httpOnly: false, path: '/' })
        } catch (_) { /* ignore */ }
      }

      // Inject dynamic fields
      manifest.seedsphere = { ...(manifest.seedsphere || {}), original_gardener_id: gardener_id, seedling_id, channel: `variant:${key}` }

      // Choose asset base to avoid mixed-content on web.strem.io (HTTPS)
      const reqOrigin3 = String(req.headers.origin || '')
      const isWebStremio3 = reqOrigin3 === 'https://web.strem.io' || reqOrigin3 === 'https://web.stremio.com'
      const assetBase3 = isWebStremio3 ? 'https://seedsphere.fly.dev' : origin
      if (assetBase3) {
        manifest.logo = `${assetBase3}/assets/icon-256.png`
        manifest.background = `${assetBase3}/assets/background-1024.jpg`
      }

      // Endpoint is explicitly set to the absolute origin above

      // Apply exactly one experimental field according to :key
      switch (key) {
        case 'endpoint':
          break
        case 'dontannounce':
          manifest.dontAnnounce = true
          break
        case 'listedon':
          manifest.listedOn = ["desktop", "web", "android"]
          break
        case 'isfree':
          manifest.isFree = true
          break
        case 'suggested':
          manifest.suggested = ["com.stremio.opensubtitlesv3"]
          break
        case 'searchdebounce':
          manifest.searchDebounce = 300
          break
        case 'countryspecific':
          manifest.countrySpecific = true
          break
        case 'zipspecific':
          manifest.zipSpecific = true
          break
        case 'countryspecificstreams':
          manifest.countrySpecificStreams = true
          break
        default:
          // If unknown key, keep base manifest (no extra fields)
          break
      }

      // Behavior hints: ensure configurable remains true for all variants
      manifest.behaviorHints = Object.assign({}, manifest.behaviorHints || {}, { configurable: true })

      res.setHeader('Cache-Control', 'public, max-age=60, stale-while-revalidate=300')
      return res.json(manifest)
    } catch (e) {
      return res.status(500).json({ error: e.message })
    }
  })

  // Mount Stremio SDK router (serves /stream/*); our manifest override stays above
  // Log incoming stream requests for observability
  app.use('/stream', (req, _res, next) => {
    try { console.log('[stream] incoming', { path: req.originalUrl || req.url, ua: req.headers['user-agent'] || '' }) } catch (_) {}
    touchActive()
    next()
  })
  app.use(addonInterface.getRouter())

  // --- Stream bridge ---
  app.post('/api/stream/:type/:id', async (req, res) => {
    if (!rateLimit(`stream:${req.ip}`, 120, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    // Diagnostic logging to compare base vs experiment stream requests
    try {
      console.log('[api.stream] incoming', {
        ip: req.ip,
        ua: req.headers['user-agent'] || '',
        origin: req.headers.origin || '',
        referer: req.headers.referer || '',
        g: String(req.get('X-SeedSphere-G') || ''),
        seedling: String(req.get('X-SeedSphere-Id') || ''),
        hasSig: Boolean(req.get('X-SeedSphere-Sig') || ''),
        type: String(req.params.type || ''),
        id: String(req.params.id || ''),
      })
    } catch (_) { /* ignore log errors */ }
    try {
      const gardener_id = String(req.get('X-SeedSphere-G') || '').trim()
      const seedling_id = String(req.get('X-SeedSphere-Id') || '').trim()
      if (!gardener_id || !seedling_id) return res.status(401).json({ ok: false, error: 'missing_identities' })
      const secret = getBindingSecret(gardener_id, seedling_id)
      if (!secret) return res.status(401).json({ ok: false, error: 'no_binding' })
      if (!verifySignature(secret, req)) return res.status(401).json({ ok: false, error: 'bad_signature' })

      const type = String(req.params.type || '')
      const id = String(req.params.id || '')
      const filters = req.body && typeof req.body === 'object' ? req.body : {}
      const streamKeyBase = JSON.stringify({ type, id, filters })
      const keyHash = crypto.createHash('sha256').update(streamKeyBase).digest('hex')
      const cacheKey = `stream:${gardener_id}:${keyHash}`

      // Attempt cached first if exists
      const cached = getCacheRow(cacheKey)
      if (cached) {
        try { res.setHeader('Cache-Control', 'no-store') } catch (_) {}
        const payload = JSON.parse(Buffer.from(cached.payload_json).toString('utf8'))
        return res.json(payload)
      }

      // Execution attempts with budgets 4s/6s/8s — reuse aggregate logic
      const budgets = [4000, 6000, 8000]
      let lastError = null
      for (const budget of budgets) {
        try {
          const result = await Promise.race([
            executeStreamTask({ type, id, filters }),
            new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), budget)),
          ])
          if (result && result.streams) {
            // weekly capped cache write
            try { setCacheRowWeeklyCapped(cacheKey, result, 7 * 24 * 60 * 60_000) } catch (_) {}
            res.setHeader('Cache-Control', 'no-store')
            return res.json(result)
          }
        } catch (e) { lastError = e }
      }

      // Fallback to cache (already tried above) or empty
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ streams: [] })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Internal executor function reusing addon aggregate logic to keep DRY
  async function executeStreamTask({ type, id, filters }) {
    try {
      const cfg = (filters && typeof filters === 'object') ? filters : {}
      // Trackers config
      const variant = String(cfg.variant || process.env.TRACKERS_VARIANT || 'all').toLowerCase()
      const trackersUrl = (cfg.trackers_url && String(cfg.trackers_url).trim()) || VARIANT_URLS[variant] || DEFAULT_TRACKERS_URL
      let trackers = []
      try { trackers = await fetchTrackers(trackersUrl) } catch (_) { trackers = [] }
      const mode = String(cfg.validation_mode || 'basic').toLowerCase()
      let maxTrackers = Number(cfg.max_trackers)
      if (!Number.isFinite(maxTrackers) || maxTrackers < 0) maxTrackers = 0
      let effective = trackers
      try { effective = await filterByHealth(trackers, mode, maxTrackers) } catch (_) { effective = maxTrackers > 0 ? trackers.slice(0, maxTrackers) : trackers }

      // Provider toggles
      const providers = []
      const on = (v) => String(v || 'on').toLowerCase() !== 'off'
      if (on(cfg.providers_torrentio)) providers.push(torrentio)
      if (on(cfg.providers_yts)) providers.push(yts)
      if (on(cfg.providers_eztv)) providers.push(eztv)
      if (on(cfg.providers_nyaa)) providers.push(nyaa)
      if (on(cfg.providers_1337x)) providers.push(x1337)
      if (on(cfg.providers_piratebay)) providers.push(piratebay)
      if (on(cfg.providers_torrentgalaxy)) providers.push(torrentgalaxy)
      if (on(cfg.providers_torlock)) providers.push(torlock)
      if (on(cfg.providers_magnetdl)) providers.push(magnetdl)
      if (on(cfg.providers_anidex)) providers.push(anidex)
      if (on(cfg.providers_tokyotosho)) providers.push(tokyotosho)
      if (on(cfg.providers_zooqle)) providers.push(zooqle)
      if (on(cfg.providers_rutor)) providers.push(rutor)

      const labelName = String(cfg.stream_label || '! SeedSphere')
      const descAppendOriginal = String(cfg.desc_append_original || 'off').toLowerCase() === 'on'
      const descRequireDetails = String(cfg.desc_require_details || 'on').toLowerCase() === 'on'
      const aiConfig = {
        enabled: String(cfg.ai_descriptions || 'off').toLowerCase() === 'on',
        provider: String(cfg.ai_provider || 'openai'),
        model: String(cfg.ai_model || 'gpt-4o'),
        timeoutMs: Number(cfg.ai_timeout_ms) || 2500,
        cacheTtlMs: Number(cfg.ai_cache_ttl_ms) || 60_000,
        userId: String(cfg.ai_user_id || ''),
      }
      const streams = await aggregateStreams({ type, id, providers, trackers: effective, bingeGroup: 'seedsphere-optimized', labelName, descAppendOriginal, descRequireDetails, aiConfig })
      return { streams: Array.isArray(streams) ? streams : [] }
    } catch (_) { return { streams: [] } }
  }

  // In development, mount Vite after the API routes so /api and SSE endpoints are handled by Express first.
  if (!isProd && !opts.disableVite && !process.env.SEEDSPHERE_DISABLE_VITE) {
    const { createServer: createViteServer } = await import('vite')
    const vite = await createViteServer({
      server: {
        middlewareMode: true,
        hmr: { server: httpServer, port: listenPort, clientPort: listenPort },
      },
      appType: 'custom',
    })
    app.use(vite.middlewares)

    app.use('*', async (req, res, next) => {
      if (req.method !== 'GET') return next()
      // Do not intercept API, health, or addon SDK routes in dev
      let p = req.path || ''
      try {
        if (!p && req.originalUrl) {
          const u = new URL(req.originalUrl, 'http://dev.local')
          p = u.pathname || ''
        }
      } catch (_) { p = req.originalUrl || '' }
      if (
        p.startsWith('/api/') || p === '/api' ||
        p === '/health' ||
        p.startsWith('/manifest') ||
        p.startsWith('/stream')
      ) return next()

      try {
        const url = req.originalUrl
        const root = path.resolve(__dirname, '..')
        const indexPath = path.join(root, 'index.html')
        const rawTemplate = await fs.readFile(indexPath, 'utf-8')
        const template = await vite.transformIndexHtml(url, rawTemplate)
        res.status(200).set({ 'Content-Type': 'text/html' }).end(template)
      } catch (e) {
        vite.ssrFixStacktrace(e)
        next(e)
      }
    })
  }

  // Production: serve built assets from dist
  if (isProd) {
    const distPath = path.resolve(__dirname, '../dist')
    const clientPath = distPath

    app.use(express.static(clientPath, { extensions: ['html'] }))

    app.get('*', (_req, res) => {
      res.sendFile(path.join(clientPath, 'index.html'))
    })
  }

  // --- Background prefetch of popular titles to warm cache ---
  if (!process.env.SEEDSPHERE_DISABLE_PREFETCH && !opts.disablePrefetch) {
    try {
      const PREFETCH_INTERVAL_MS = Math.max(60_000, Number(process.env.PREFETCH_INTERVAL_MS || 5 * 60_000))
      const PREFETCH_TIMEOUT_MS = Math.max(3000, Number(process.env.PREFETCH_TIMEOUT_MS || 8000))
      const PREFETCH_CACHE_TTL_MS = Math.max(120_000, Number(process.env.PREFETCH_CACHE_TTL_MS || 6 * 60 * 60_000))
      const PROVIDER_FETCH_TIMEOUT_MS = Math.max(800, Number(process.env.PROVIDER_FETCH_TIMEOUT_MS || 3000))
      const POP_MOVIES = String(process.env.PREFETCH_MOVIES || 'tt1375666,tt0816692,tt0133093')
        .split(',').map((s) => s.trim()).filter(Boolean)
      const POP_SERIES = String(process.env.PREFETCH_SERIES || 'tt0944947,tt0903747,tt2861424')
        .split(',').map((s) => s.trim()).filter(Boolean)

      const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

      async function warmOne({ type, id }) {
        try {
          // If recent activity, yield to prioritize real requests
          if (Date.now() - lastActiveTs < 1500) {
            await sleep(750)
          }
          // Trackers config (reuse server-side execution logic defaults)
          const variant = String(process.env.TRACKERS_VARIANT || 'all').toLowerCase()
          const trackersUrl = VARIANT_URLS[variant] || DEFAULT_TRACKERS_URL
          let trackers = []
          try { trackers = await fetchTrackers(trackersUrl) } catch (_) { trackers = [] }
          const mode = 'off'
          const maxTrackers = 0 // unlimited by default
          let effective = trackers
          if (mode !== 'off') {
            try { effective = await filterByHealth(trackers, mode, maxTrackers) } catch (_) { effective = trackers }
          } else {
            effective = maxTrackers > 0 ? trackers.slice(0, maxTrackers) : trackers
          }

          // Providers (all enabled by default)
          const providers = [
            torrentio, yts, eztv, nyaa, x1337, piratebay,
            torrentgalaxy, torlock, magnetdl, anidex, tokyotosho, zooqle, rutor,
          ]

          // Call aggregate with timeout budget; result is cached internally
          const task = aggregateStreams({
            type,
            id,
            providers,
            trackers: effective,
            trackersTotal: trackers.length,
            mode,
            maxTrackers,
            cacheTtlMs: PREFETCH_CACHE_TTL_MS,
            bingeGroup: 'seedsphere-optimized',
            labelName: 'SeedSphere',
            descAppendOriginal: false,
            descRequireDetails: true,
            aiConfig: { enabled: false },
            providerFetchTimeoutMs: PROVIDER_FETCH_TIMEOUT_MS,
          })
          await Promise.race([
            task,
            new Promise((_, rej) => setTimeout(() => rej(new Error('prefetch_timeout')), PREFETCH_TIMEOUT_MS)),
          ])
        } catch (_) { /* ignore prefetch errors */ }
      }

      async function prefetchPopular() {
        // Skip prefetch entirely if there was recent user activity
        if (Date.now() - lastActiveTs < 1000) return
        const jobs = []
        for (const id of POP_MOVIES) jobs.push(warmOne({ type: 'movie', id }))
        for (const id of POP_SERIES) jobs.push(warmOne({ type: 'series', id }))
        // Run with limited concurrency to avoid spikes
        const CONCURRENCY = 1
        let i = 0
        async function next() {
          if (i >= jobs.length) return
          const idx = i++
          try { await jobs[idx] } catch (_) {}
          return next()
        }
        const runners = Array.from({ length: Math.min(CONCURRENCY, jobs.length) }, () => next())
        await Promise.allSettled(runners)
      }

      // Initial warm shortly after start, then on interval
      setTimeout(() => { prefetchPopular().catch(() => {}) }, 2000)
      setInterval(() => { prefetchPopular().catch(() => {}) }, PREFETCH_INTERVAL_MS)
    } catch (_) { /* ignore scheduler errors */ }
  }

  return new Promise((resolve) => {
    httpServer.listen(listenPort, () => {
      try {
        const addr = httpServer.address()
        const actualPort = (addr && typeof addr === 'object') ? addr.port : listenPort
        if (process.env.NO_SERVER_LOG !== '1') {
          console.log(`Server listening on http://localhost:${actualPort}`)
        }
      } catch (_) { /* ignore logging errors */ }
      resolve(httpServer)
    })
  })
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  createServer()
    .catch((err) => {
      console.error(err)
      process.exit(1)
    })
}
