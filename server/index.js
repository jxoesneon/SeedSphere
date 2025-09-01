#!/usr/bin/env node
import path from 'node:path'
import http from 'node:http'
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
const { filterAvailableProviders } = require('./lib/aggregate.cjs')
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
} = require('./lib/db.cjs')
const { initCrypto } = require('./lib/crypto.cjs')
const cookieParser = require('cookie-parser')
const authRouter = require('./routes/auth.cjs')
const keysRouter = require('./routes/keys.cjs')
const { subscribe, publish } = require('./lib/rooms.cjs')
const { normalize } = require('./lib/normalize.cjs')
const { nanoid } = require('nanoid')
const jwt = require('jsonwebtoken')
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
const port = Number(process.env.PORT) || 5173

async function createServer() {
  const app = express()
  const httpServer = http.createServer(app)

  // Minimal CORS for API
  app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*')
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
    if (req.method === 'OPTIONS') return res.sendStatus(204)
    next()
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

  // Mount Stremio SDK router (serves /manifest.json and /stream/*)
  app.use(addonInterface.getRouter())

  // In development, mount Vite after the API routes so /api and SSE endpoints are handled by Express first.
  if (!isProd) {
    const { createServer: createViteServer } = await import('vite')
    const vite = await createViteServer({
      server: {
        middlewareMode: true,
        hmr: { server: httpServer, port, clientPort: port },
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

  return new Promise((resolve) => {
    httpServer.listen(port, () => {
      console.log(`Server listening on http://localhost:${port}`)
      resolve(httpServer)
    })
  })
}

createServer()
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
