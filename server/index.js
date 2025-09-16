#!/usr/bin/env node
import path from 'node:path'
import http from 'node:http'
import https from 'node:https'
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
const { filterAvailableProviders, aggregateStreams, buildInformativeStream } = require('./lib/aggregate.cjs')
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
  listGardeners,
  getGardenerWithCounts,
  setGardenerUser,
  deleteBindingsForGardener,
  deleteGardener,
  reassignBinding,
  // per-seedling helpers
  setInstallationSecret,
  setInstallationUser,
  setInstallationStatus,
  setInstallationConfig,
  getInstallation,
  getUser,
  findRecentInstallationByUser,
  countInstallationsByUser,
  listInstallationsByUser,
  revokeInstallationOwned,
  deleteInstallationOwned,
  // gardeners management
  listGardenersByUser,
  setGardenerStatus,
  deleteGardenerOwned,
  // admin: users moderation
  setBan,
  removeBan,
  isBanned,
  deleteUserAndRelated,
  revokeAllInstallationsByUser,
} = require('./lib/db.cjs')
const { readSession } = require('./lib/session.cjs')
const { initCrypto } = require('./lib/crypto.cjs')
const cookieParser = require('cookie-parser')
const authRouter = require('./routes/auth.cjs')
const keysRouter = require('./routes/keys.cjs')
const { subscribe, publish } = require('./lib/rooms.cjs')
const rolllog = require('./lib/rolllog.cjs')
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
  let httpsServer = null
  try {
    // Allow long-lived SSE connections
    httpServer.keepAliveTimeout = 120_000
    // Disable per-request inactivity timeout to prevent SSE from being cut
    // Node >= 18: requestTimeout controls inactivity timeout
    httpServer.requestTimeout = 0
    // Disable header timeout for long streams
    httpServer.headersTimeout = 0
  } catch (_) {}

  // Compute effective listen port (supports 0 and explicit overrides)
  let listenPort
  if (opts && Object.prototype.hasOwnProperty.call(opts, 'port')) {
    listenPort = Number(opts.port)
  } else if (process.env.PORT !== undefined) {
    listenPort = Number(process.env.PORT)
  } else {
    listenPort = 8080
  }

  // Select the best gardener by current in-memory health score (fallback prediction)
  function chooseBestGardener() {
    try {
      let bestId = ''
      let bestHealth = null
      for (const [gid, h] of activeGardeners.entries()) {
        if (!h || typeof h !== 'object') continue
        const score = Number(h.score || 0)
        if (!bestHealth || score > Number(bestHealth.score || 0)) {
          bestId = gid
          bestHealth = h
        }
      }
      if (!bestId) return { gardener_id: '', health: null }
      const { ts, queue, s1m, f1m, score } = bestHealth
      return { gardener_id: bestId, health: { ts, queue, s1m, f1m, score } }
    } catch (_) { return { gardener_id: '', health: null } }
  }
  if (!Number.isFinite(listenPort)) listenPort = 8080

  // Optional HTTPS (dev): use mkcert certs if enabled and present
  let httpsPort = null
  try {
    const enableHttps = String(process.env.HTTPS_ENABLE || '').toLowerCase() === 'true'
    const certPath = process.env.CERT_PATH || path.resolve(__dirname, 'certs', 'localhost.pem')
    const keyPath = process.env.KEY_PATH || path.resolve(__dirname, 'certs', 'localhost-key.pem')
    const defaultHttpsPort = Number(process.env.HTTPS_PORT || 8443)
    if (enableHttps) {
      const [cert, key] = await Promise.allSettled([
        fs.readFile(certPath),
        fs.readFile(keyPath),
      ])
      if (cert.status === 'fulfilled' && key.status === 'fulfilled') {
        httpsServer = https.createServer({ cert: cert.value, key: key.value }, app)
        try {
          httpsServer.keepAliveTimeout = 120_000
          httpsServer.requestTimeout = 0
          httpsServer.headersTimeout = 0
        } catch (_) {}
        httpsPort = defaultHttpsPort
      } else {
        try { console.warn('[https] enabled but cert or key not found', { certPath, keyPath }) } catch (_) {}
      }
    }
  } catch (_) { /* ignore https init errors */ }

  // Dev-only: canonicalize 127.0.0.1 to localhost for HTML navigations only (avoid affecting programmatic clients)
  app.use((req, res, next) => {
    try {
      if (!isProd && req.method === 'GET') {
        const accept = String(req.headers.accept || '').toLowerCase()
        const isHtml = accept.includes('text/html')
        const host = String(req.headers.host || '')
        const pathOnly = (req.path || req.originalUrl || '/')
        const isApiOrAddon = (
          pathOnly.startsWith('/api/') || pathOnly === '/api' ||
          pathOnly.startsWith('/s/') || pathOnly.startsWith('/manifest') ||
          pathOnly.startsWith('/stream')
        )
        if (isHtml && !isApiOrAddon && /^127\.0\.0\.1(?::\d+)?$/.test(host)) {
          const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
          const targetHost = host.replace(/^127\.0\.0\.1/, 'localhost')
          const location = `${proto}://${targetHost}${req.originalUrl || req.url || '/'}`
          return res.redirect(302, location)
        }
      }
    } catch (_) { /* ignore */ }
    next()
  })

  // Safety net (.json variant used by Stremio SDK)
  app.get('/stream/:type/:id/:extra?.json', (req, res) => {
    try {
      res.setHeader('Cache-Control', 'no-store')
      const { type, id } = req.params || {}
      try { rolllog.log('stream_fallback', { component: 'server_base_stream_json', reason: 'account_no_binding', type, id }) } catch (_) {}
      const info = buildInformativeStream({
        reason: 'account_no_binding',
        details: { note: 'Addon installed without per-seedling endpoint. Reinstall from the Gardener app.' },
        labelName: 'SeedSphere',
        configureUrl: '/configure',
      })
      return res.json({ streams: [info] })
    } catch (e) {
      return res.json({ streams: [{ name: 'SeedSphere', title: 'SeedSphere — Installation not linked', description: 'Install the addon via the Gardener app so it uses a per‑seedling endpoint.\nConfigure: /configure', infoHash: '0000000000000000000000000000000000000000', behaviorHints: { bingeGroup: 'seedsphere-info', notWebReady: true } }] })
    }
  })

  // Read-only: return the currently selected gardener for a seedling (as last observed)
  app.get('/api/seedlings/:seedling_id/gardener', (req, res) => {
    if (!rateLimit(`seedling-gardener:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const seedling_id = String(req.params.seedling_id || '').trim()
      if (!seedling_id) return res.status(400).json({ ok: false, error: 'missing_seedling_id' })
      const rec = lastSelectedGardener.get(seedling_id) || null
      const gardener_id = rec && rec.gardener_id ? String(rec.gardener_id) : ''
      let health = null
      try {
        if (gardener_id) {
          const h = activeGardeners.get(gardener_id) || null
          if (h && typeof h === 'object') {
            // Return a minimal snapshot
            const { ts, queue, s1m, f1m, score } = h
            health = { ts, queue, s1m, f1m, score }
          }
        }
      } catch (_) { health = null }
      // Fallback: predict current selection from best active gardener if none observed yet
      if (!gardener_id) {
        const best = chooseBestGardener()
        res.setHeader('Cache-Control', 'no-store')
        return res.json({ ok: true, gardener_id: best.gardener_id || null, health: best.health })
      }
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, gardener_id: gardener_id || null, health })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Authenticated: check if current session owns a given seedling
  app.get('/api/seedlings/:seedling_id/owner', (req, res) => {
    if (!rateLimit(`seedling-owner:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess) return res.status(401).json({ ok: false, error: 'not_authenticated' })
      const seedling_id = String(req.params.seedling_id || '').trim()
      if (!seedling_id) return res.status(400).json({ ok: false, error: 'missing_seedling_id' })
      const rec = getInstallation(seedling_id)
      if (!rec) return res.status(404).json({ ok: false, error: 'not_found' })
      const owner = String(rec.user_id || '')
      if (owner && owner === String(sess.user_id)) return res.json({ ok: true })
      return res.status(403).json({ ok: false, error: 'forbidden', reason: owner ? 'owned' : 'unowned' })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Dev-only: verify a seedling record and an sk value
  if (!isProd) {
    app.get('/api/dev/debug/seedling/:seedling_id/verify', (req, res) => {
      try {
        const seedling_id = String(req.params.seedling_id || '').trim()
        const skParam = String(req.query.sk || '').trim()
        const rec = getInstallation(seedling_id)
        if (!rec) return res.json({ ok: true, exists: false })
        let skValid = false
        try {
          const raw = fromB64url(skParam)
          const calc = sha256hex(Buffer.concat([rec.salt || Buffer.alloc(0), raw]))
          skValid = (calc === String(rec.key_hash || ''))
        } catch (_) { skValid = false }
        const status = String(rec.status || 'active')
        return res.json({ ok: true, exists: true, status, user_id: rec.user_id || null, skValid })
      } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
    })
  }

  // Dev: ensure a post-Vite safety-net for misinstalled addons calling base /stream
  app.get('/stream/:type/:id', (req, res) => {
    try {
      res.setHeader('Cache-Control', 'no-store')
      const { type, id } = req.params || {}
      try { rolllog.log('stream_fallback', { component: 'server_base_stream_postvite', reason: 'account_no_binding', type, id }) } catch (_) {}
      const info = buildInformativeStream({
        reason: 'account_no_binding',
        details: { note: 'Addon installed without per-seedling endpoint. Reinstall from the Gardener app.' },
        labelName: 'SeedSphere',
        configureUrl: '/configure',
      })
      return res.json({ streams: [info] })
    } catch (_) {
      return res.json({ streams: [{ name: 'SeedSphere', title: 'SeedSphere — Installation not linked', description: 'Install the addon via the Gardener app so it uses a per‑seedling endpoint.\nConfigure: /configure', infoHash: '0000000000000000000000000000000000000000', behaviorHints: { bingeGroup: 'seedsphere-info', notWebReady: true } }] })
    }
  })

  // Standardized error page: renders dynamic error codes and CTAs via query params
  app.get('/error', (req, res) => {
    try {
      const file = path.resolve(__dirname, '../public/error/index.html')
      return res.sendFile(file)
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // List gardeners for the current authenticated user
  app.get('/api/gardeners', (req, res) => {
    if (!rateLimit(`gardener-list:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess) return res.status(401).json({ ok: false, error: 'not_authenticated' })
      let rows = []
      try { rows = listGardenersByUser(sess.user_id) } catch (e2) {
        try { writeAudit('gardeners:list_error', { message: e2?.message || String(e2) }) } catch (_) {}
        rows = []
      }
      const includeRevoked = (() => { const v = String(req.query.include_revoked || '').toLowerCase(); return v === '1' || v === 'true' || v === 'yes' })()
      const out = includeRevoked ? rows : rows.filter(r => String(r.status || 'active') !== 'revoked')
      return res.json({ ok: true, gardeners: out })
    } catch (e) {
      try { writeAudit('gardeners:list_error', { message: e?.message || String(e) }) } catch (_) {}
      return res.json({ ok: true, gardeners: [] })
    }
  })

  // Revoke a gardener (owned by current user)
  app.post('/api/gardeners/revoke', express.json(), (req, res) => {
    if (!rateLimit(`gardener-revoke:${req.ip}`, 20, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess) return res.status(401).json({ ok: false, error: 'not_authenticated' })
      const gardener_id = String(req.body?.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      // Ownership check via listGardenersByUser
      let owned = false
      try { owned = !!listGardenersByUser(sess.user_id).find(g => String(g.gardener_id) === gardener_id) } catch (_) { owned = false }
      if (!owned) return res.status(404).json({ ok: false, error: 'not_found_or_not_owned' })
      setGardenerStatus(gardener_id, 'revoked')
      try { touch(activeGardeners, gardener_id, { status: 'revoked' }) } catch (_) {}
      try { writeAudit('gardener:revoked', { gardener_id, user_id: sess.user_id }) } catch (_) {}
      return res.json({ ok: true })
    } catch (e) {
      try { writeAudit('gardeners:revoke_error', { message: e?.message || String(e) }) } catch (_) {}
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Permanently delete a gardener (owned by current user)
  app.post('/api/gardeners/delete', express.json(), (req, res) => {
    if (!rateLimit(`gardener-delete:${req.ip}`, 10, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess) return res.status(401).json({ ok: false, error: 'not_authenticated' })
      const gardener_id = String(req.body?.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      let ok = false
      try { ok = deleteGardenerOwned(sess.user_id, gardener_id) } catch (e) {
        try { writeAudit('gardeners:delete_error', { message: e?.message || String(e), gardener_id, user_id: sess.user_id }) } catch (_) {}
        if (!isProd) return res.status(500).json({ ok: false, error: 'db_error', detail: String(e?.message || e || '') })
        return res.status(500).json({ ok: false, error: 'db_error' })
      }
      if (!ok) return res.status(404).json({ ok: false, error: 'not_found_or_not_owned' })
      try { touch(activeGardeners, gardener_id, { status: 'revoked' }) } catch (_) {}
      try { writeAudit('gardener:deleted', { gardener_id, user_id: sess.user_id }) } catch (_) {}
      return res.json({ ok: true })
    } catch (e) {
      try { writeAudit('gardeners:delete_error', { message: e?.message || String(e) }) } catch (_) {}
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Permanently delete a seedling owned by the current user
  app.post('/api/seedlings/delete', express.json(), (req, res) => {
    if (!rateLimit(`seedling-delete:${req.ip}`, 10, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess) return res.status(401).json({ ok: false, error: 'not_authenticated' })
      const install_id = String(req.body?.install_id || '')
      if (!install_id) return res.status(400).json({ ok: false, error: 'missing_install_id' })
      let ok = false
      try {
        ok = deleteInstallationOwned(sess.user_id, install_id)
      } catch (e) {
        try { writeAudit('seedlings:delete_error', { message: e?.message || String(e), install_id, user_id: sess.user_id }) } catch (_) {}
        try { console.error('[seedling-delete] db_error', { install_id, user_id: sess.user_id, error: e?.message || String(e) }) } catch (_) {}
        if (!isProd) return res.status(500).json({ ok: false, error: 'db_error', detail: String(e?.message || e || '') })
        return res.status(500).json({ ok: false, error: 'db_error' })
      }
      if (!ok) return res.status(404).json({ ok: false, error: 'not_found_or_not_owned' })
      try { writeAudit('seedling:deleted', { install_id, user_id: sess.user_id }) } catch (_) {}
      return res.json({ ok: true })
    } catch (e) {
      try { writeAudit('seedlings:delete_error', { message: e?.message || String(e) }) } catch (_) {}
      try { console.error('[seedling-delete] unhandled', e) } catch (_) {}
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // CORS — permissive for private testing; audit every CORS request
  app.use((req, res, next) => {
    try {
      const origin = String(req.headers.origin || '')
      const allow = !isProd ? '*' : (origin || '*')
      res.setHeader('Access-Control-Allow-Origin', allow)
      res.setHeader('Vary', 'Origin')
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-SeedSphere-G, X-SeedSphere-Id, X-SeedSphere-Ts, X-SeedSphere-Nonce, X-SeedSphere-Sig')
      // Optional: do not set Allow-Credentials to keep wildcard compatibility
      const maskedPath = maskSensitivePath(req.originalUrl || req.url)
      const fp = deviceFingerprint(req)
      const ipBucket = clientIpBucket(req)
      try { writeAudit('cors', { ip: req.ip, ipBucket, origin, method: req.method, path: maskedPath, fp }) } catch (_) {}
      if (req.method === 'OPTIONS') return res.sendStatus(204)
    } catch (_) { /* ignore */ }
    next()
  })

  // Public: gardener-specific preferences (adaptive throttling etc.)
  app.get('/api/gardeners/:gardener_id/prefs', (req, res) => {
    if (!rateLimit(`gprefs-get:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      const row = getCacheRow(`gardener:prefs:${gardener_id}`)
      let prefs = null
      if (row && row.payload_json) { try { prefs = JSON.parse(Buffer.from(row.payload_json).toString('utf8')) } catch (_) {} }
      return res.json({ ok: true, prefs })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })
  app.post('/api/gardeners/:gardener_id/prefs', express.json(), (req, res) => {
    if (!rateLimit(`gprefs-set:${req.ip}`, 120, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      const prefs = (req.body && req.body.prefs) || {}
      // Store for 365 days; small structure
      setCacheRow(`gardener:prefs:${gardener_id}`, prefs, 365 * 24 * 60 * 60_000)
      try { writeAudit('gardener:prefs_set', { gardener_id }) } catch (_) {}
      return res.json({ ok: true })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Reassign a binding to a different gardener
  app.post('/api/admin/gardeners/:gardener_id/bindings/:seedling_id/reassign', requireAdmin, express.json(), (req, res) => {
    try {
      const fromId = String(req.params.gardener_id || '').trim()
      const seedling_id = String(req.params.seedling_id || '').trim()
      const toId = (req.body && String(req.body.to_gardener_id || '').trim()) || ''
      if (!fromId || !seedling_id || !toId) return res.status(400).json({ ok: false, error: 'missing_input' })
      const ok = reassignBinding(seedling_id, fromId, toId)
      try { writeAudit('admin:reassign_binding', { from: fromId, to: toId, seedling_id, ok }) } catch (_) {}
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Assign a user to a gardener
  app.post('/api/admin/gardeners/:gardener_id/user', requireAdmin, express.json(), (req, res) => {
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      const user_id = (req.body && String(req.body.user_id || '').trim()) || ''
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      setGardenerUser(gardener_id, user_id || null)
      try { writeAudit('admin:gardener_set_user', { gardener_id, user_id: user_id || null }) } catch (_) {}
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Clear gardener user
  app.delete('/api/admin/gardeners/:gardener_id/user', requireAdmin, (req, res) => {
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      setGardenerUser(gardener_id, null)
      try { writeAudit('admin:gardener_clear_user', { gardener_id }) } catch (_) {}
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Unlink all bindings for a gardener
  app.delete('/api/admin/gardeners/:gardener_id/bindings', requireAdmin, (req, res) => {
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      const count = deleteBindingsForGardener(gardener_id)
      try { writeAudit('admin:unlink_all_bindings', { gardener_id, count }) } catch (_) {}
      res.json({ ok: true, count })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Delete a gardener (and all its bindings)
  app.delete('/api/admin/gardeners/:gardener_id', requireAdmin, (req, res) => {
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      const ok = deleteGardener(gardener_id)
      try { writeAudit('admin:delete_gardener', { gardener_id, ok }) } catch (_) {}
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // --- Gardeners management ---
  app.get('/api/admin/gardeners', requireAdmin, (req, res) => {
    try {
      const query = String(req.query.query || '')
      const limit = Math.min(200, Math.max(1, Number(req.query.limit || 50)))
      const offset = Math.max(0, Number(req.query.offset || 0))
      const rows = listGardeners({ query, limit, offset })
      res.json({ ok: true, gardeners: rows })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  app.get('/api/admin/gardeners/:gardener_id', requireAdmin, (req, res) => {
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      if (!gardener_id) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      const rec = getGardenerWithCounts(gardener_id)
      if (!rec) return res.status(404).json({ ok: false, error: 'not_found' })
      res.json({ ok: true, gardener: rec })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  app.delete('/api/admin/gardeners/:gardener_id/bindings/:seedling_id', requireAdmin, (req, res) => {
    try {
      const gardener_id = String(req.params.gardener_id || '').trim()
      const seedling_id = String(req.params.seedling_id || '').trim()
      if (!gardener_id || !seedling_id) return res.status(400).json({ ok: false, error: 'missing_ids' })
      deleteBinding(gardener_id, seedling_id)
      try { writeAudit('admin:unlink_binding', { gardener_id, seedling_id }) } catch (_) {}
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Public: check if a seedling is claimable (unowned) by verifying possession of sk
  app.get('/api/seedlings/:seedling_id/claimable', (req, res) => {
    if (!rateLimit(`seedling-claimable:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const seedling_id = String(req.params.seedling_id || '').trim()
      const skParam = String(req.query.sk || '').trim()
      if (!seedling_id || !skParam) return res.json({ ok: true, claimable: false })
      const rec = getInstallation(seedling_id)
      if (!rec) return res.json({ ok: true, claimable: false })
      try {
        const raw = fromB64url(skParam)
        const calc = sha256hex(Buffer.concat([rec.salt || Buffer.alloc(0), raw]))
        const skValid = (calc === String(rec.key_hash || ''))
        const claimable = skValid && !rec.user_id
        return res.json({ ok: true, claimable })
      } catch (_) { return res.json({ ok: true, claimable: false }) }
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Admin: fallback_stream reason summary over recent window
  app.get('/api/admin/metrics/fallbacks', requireAdmin, (req, res) => {
    try {
      const minutes = Math.min(24 * 60, Math.max(1, Number(req.query.minutes || 60)))
      const since = Date.now() - minutes * 60_000
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      const rows = dbraw.prepare("SELECT at, meta_json FROM audit WHERE event = 'fallback_stream' AND at >= ? ORDER BY at DESC LIMIT 5000").all(since)
      const reasons = {}
      for (const r of rows) {
        let meta = {}
        try { meta = r.meta_json ? JSON.parse(Buffer.from(r.meta_json).toString('utf8')) : {} } catch (_) {}
        const key = String(meta.reason || 'unknown')
        reasons[key] = (reasons[key] || 0) + 1
      }
      res.json({ ok: true, minutes, reasons })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Revoke all installations for a user
  app.post('/api/admin/users/:user_id/revoke-installations', requireAdmin, (req, res) => {
    try {
      const user_id = String(req.params.user_id || '').trim()
      if (!user_id) return res.status(400).json({ ok: false, error: 'missing_user_id' })
      const count = revokeAllInstallationsByUser(user_id)
      try { writeAudit('admin:revoke_all_installs', { user_id, count }) } catch (_) {}
      res.json({ ok: true, count })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Ban and revoke all installations in one step
  app.post('/api/admin/users/:user_id/ban-and-revoke', requireAdmin, express.json(), (req, res) => {
    try {
      const user_id = String(req.params.user_id || '').trim()
      if (!user_id) return res.status(400).json({ ok: false, error: 'missing_user_id' })
      const reason = (req.body && typeof req.body.reason === 'string') ? req.body.reason : ''
      setBan(user_id, reason)
      const count = revokeAllInstallationsByUser(user_id)
      try { writeAudit('admin:ban_and_revoke', { user_id, reason, count }) } catch (_) {}
      res.json({ ok: true, count })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // List bans
  app.get('/api/admin/bans', requireAdmin, (_req, res) => {
    try {
      const dbh = require('./lib/db.cjs')
      const bans = dbh.listBans()
      res.json({ ok: true, bans })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Metrics: errors/events summary for recent window
  app.get('/api/admin/metrics/errors', requireAdmin, (req, res) => {
    try {
      const minutes = Math.min(24 * 60, Math.max(1, Number(req.query.minutes || 60)))
      const since = Date.now() - minutes * 60_000
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      const rows = dbraw.prepare('SELECT event, COUNT(*) AS c FROM audit WHERE at >= ? GROUP BY event ORDER BY c DESC').all(since)
      const summary = {}
      for (const r of rows) { if (r && r.event) summary[r.event] = r.c }
      res.json({ ok: true, minutes, summary })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Public settings for client (non-sensitive)
  app.get('/api/settings/public', (_req, res) => {
    try {
      let s = { kofi_overlay: 'on', telemetry_sample: 1 }
      const row = getCacheRow('admin:settings')
      if (row && row.payload_json) {
        try { const obj = JSON.parse(Buffer.from(row.payload_json).toString('utf8')) || {}; if (obj.kofi_overlay) s.kofi_overlay = obj.kofi_overlay; if (obj.telemetry_sample !== undefined) s.telemetry_sample = obj.telemetry_sample } catch (_) {}
      }
      res.setHeader('Cache-Control', 'no-store')
      res.json({ ok: true, settings: s })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // --- Admin API (guarded) ---
  function isAdminRequest(req) {
    try {
      const sess = readSession(req)
      if (!sess) return false
      const user = getUser(sess.user_id)
      const email = String(user?.email || '').toLowerCase()
      return email === 'joseeduardox@gmail.com'
    } catch { return false }
  }
  function requireAdmin(req, res, next) {
    if (!isAdminRequest(req)) return res.status(401).json({ ok: false, error: 'unauthorized' })
    return next()
  }

  app.get('/api/admin/summary', requireAdmin, (_req, res) => {
    try {
      const dbh = require('./lib/db.cjs')
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      const counts = {}
      try { counts.users = dbraw.prepare('SELECT COUNT(*) AS c FROM users').get().c } catch { counts.users = 0 }
      try { counts.installations = dbraw.prepare('SELECT COUNT(*) AS c FROM installations').get().c } catch { counts.installations = 0 }
      try { counts.revoked = dbraw.prepare("SELECT COUNT(*) AS c FROM installations WHERE LOWER(COALESCE(status,''))='revoked'").get().c } catch { counts.revoked = 0 }
      try { counts.pairings = dbraw.prepare('SELECT COUNT(*) AS c FROM pairings').get().c } catch { counts.pairings = 0 }
      res.json({ ok: true, counts })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  app.get('/api/admin/users', requireAdmin, (_req, res) => {
    try {
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      const rows = dbraw
        .prepare('SELECT u.id, u.provider, u.email, u.created_at, b.user_id IS NOT NULL AS banned FROM users u LEFT JOIN bans b ON b.user_id = u.id ORDER BY u.created_at DESC LIMIT 500')
        .all()
      res.json({ ok: true, users: rows })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Ban a user
  app.post('/api/admin/users/:user_id/ban', requireAdmin, express.json(), (req, res) => {
    try {
      const user_id = String(req.params.user_id || '').trim()
      if (!user_id) return res.status(400).json({ ok: false, error: 'missing_user_id' })
      const reason = (req.body && typeof req.body.reason === 'string') ? req.body.reason : ''
      setBan(user_id, reason)
      try { writeAudit('admin:ban', { user_id, reason }) } catch (_) {}
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Unban a user
  app.delete('/api/admin/users/:user_id/ban', requireAdmin, (req, res) => {
    try {
      const user_id = String(req.params.user_id || '').trim()
      if (!user_id) return res.status(400).json({ ok: false, error: 'missing_user_id' })
      removeBan(user_id)
      try { writeAudit('admin:unban', { user_id }) } catch (_) {}
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Delete a user (and related associations)
  app.delete('/api/admin/users/:user_id', requireAdmin, (req, res) => {
    try {
      const user_id = String(req.params.user_id || '').trim()
      if (!user_id) return res.status(400).json({ ok: false, error: 'missing_user_id' })
      deleteUserAndRelated(user_id)
      try { writeAudit('admin:delete_user', { user_id }) } catch (_) {}
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  app.get('/api/admin/installations', requireAdmin, (_req, res) => {
    try {
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      const rows = dbraw.prepare('SELECT install_id, user_id, status, created_at, last_seen FROM installations ORDER BY created_at DESC LIMIT 1000').all()
      res.json({ ok: true, installations: rows })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  app.post('/api/admin/installations/revoke', requireAdmin, express.json(), (req, res) => {
    try {
      const { install_id } = req.body || {}
      if (!install_id) return res.status(400).json({ ok: false, error: 'missing_install_id' })
      setInstallationStatus(String(install_id), 'revoked')
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  app.delete('/api/admin/installations/:install_id', requireAdmin, (req, res) => {
    try {
      const install_id = String(req.params.install_id || '')
      if (!install_id) return res.status(400).json({ ok: false, error: 'missing_install_id' })
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      dbraw.prepare('DELETE FROM installations WHERE install_id = ?').run(install_id)
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Admin settings stored in cache table with long TTL
  const ADMIN_SETTINGS_KEY = 'admin:settings'
  app.get('/api/admin/settings', requireAdmin, (_req, res) => {
    try {
      const row = getCacheRow(ADMIN_SETTINGS_KEY)
      let settings = {
        probe_providers: 'auto',
        probe_timeout_ms: 400,
        provider_fetch_timeout_ms: 2500,
        swarm_enabled: 'on',
        swarm_top_n: 2,
        swarm_timeout_ms: 800,
        swarm_missing_only: 'on',
        sort_order: 'desc',
        sort_fields: 'resolution,peers,language',
        ai_enabled: 'off', ai_provider: 'openai', ai_model: 'gpt-4o', ai_timeout_ms: 2500, ai_cache_ttl_ms: 60000,
        telemetry_sample: 1,
        kofi_overlay: 'on',
        max_seedlings_per_user: Number(process.env.MAX_SEEDLINGS_PER_USER || 20),
      }
      if (row && row.payload_json) {
        try { settings = Object.assign(settings, JSON.parse(Buffer.from(row.payload_json).toString('utf8'))) } catch (_) {}
      }
      res.json({ ok: true, settings })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })
  app.post('/api/admin/settings', requireAdmin, express.json(), (req, res) => {
    try {
      const incoming = (req.body && req.body.settings) || {}
      setCacheRow(ADMIN_SETTINGS_KEY, incoming, 365 * 24 * 60 * 60_000)
      res.json({ ok: true })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Rotate secret for installation and return new links
  app.post('/api/admin/installations/:install_id/rotate-secret', requireAdmin, (req, res) => {
    try {
      const install_id = String(req.params.install_id || '').trim()
      if (!install_id) return res.status(400).json({ ok: false, error: 'missing_install_id' })
      const row = getInstallation(install_id)
      if (!row) return res.status(404).json({ ok: false, error: 'not_found' })
      const skRaw = crypto.randomBytes(16)
      const sk = skRaw.toString('base64url')
      const salt = crypto.randomBytes(16)
      const keyHash = sha256hex(Buffer.concat([salt, skRaw]))
      setInstallationSecret(install_id, salt, keyHash)
      const base = originFromReq(req)
      const manifestUrl = `${base}/s/${install_id}/${sk}/manifest.json`
      const stremioUrl = toStremioProtocol(manifestUrl)
      res.json({ ok: true, install_id, sk, manifestUrl, stremioUrl })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Signed manifest links (short-lived)
  function randToken() { return crypto.randomBytes(24).toString('base64url') }
  app.post('/api/admin/installations/:install_id/signed-manifest', requireAdmin, (req, res) => {
    try {
      const install_id = String(req.params.install_id || '').trim()
      if (!install_id) return res.status(400).json({ ok: false, error: 'missing_install_id' })
      const ttlMs = Math.max(60_000, Number(req.query.ttl_ms || 10 * 60_000))
      // Create a fresh key so the link works without exposing existing sk
      const skRaw = crypto.randomBytes(16)
      const sk = skRaw.toString('base64url')
      const salt = crypto.randomBytes(16)
      const keyHash = sha256hex(Buffer.concat([salt, skRaw]))
      setInstallationSecret(install_id, salt, keyHash)
      const token = randToken()
      setCacheRow(`signed:manifest:${token}`, { install_id, sk }, ttlMs)
      const base = originFromReq(req)
      res.json({ ok: true, url: `${base}/api/admin/signed/${token}/manifest.json`, ttl_ms: ttlMs })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })
  app.get('/api/admin/signed/:token/manifest.json', (req, res) => {
    try {
      const token = String(req.params.token || '')
      const row = getCacheRow(`signed:manifest:${token}`)
      if (!row || !row.payload_json) return res.status(410).json({ ok: false, error: 'expired' })
      let payload = null
      try { payload = JSON.parse(Buffer.from(row.payload_json).toString('utf8')) } catch (_) {}
      const install_id = payload && payload.install_id
      const sk = payload && payload.sk
      if (!install_id || !sk) return res.status(410).json({ ok: false, error: 'invalid' })
      const base = originFromReq(req)
      return res.redirect(302, `${base}/s/${install_id}/${sk}/manifest.json`)
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Trackers refresh
  app.post('/api/admin/trackers/refresh', requireAdmin, async (_req, res) => {
    try { await fetchTrackers(DEFAULT_TRACKERS_URL); res.json({ ok: true }) }
    catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Audit listing with pagination
  app.get('/api/admin/audit', requireAdmin, (req, res) => {
    try {
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      const limit = Math.min(500, Math.max(1, Number(req.query.limit || 100)))
      const offset = Math.max(0, Number(req.query.offset || 0))
      const rows = dbraw.prepare('SELECT id, event, at, meta_json FROM audit ORDER BY id DESC LIMIT ? OFFSET ?').all(limit, offset)
      res.json({ ok: true, items: rows })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // Metrics summary (daily counts)
  app.get('/api/admin/metrics/summary', requireAdmin, (req, res) => {
    try {
      const days = Math.min(90, Math.max(1, Number(req.query.days || 30)))
      const sinceMs = Date.now() - days * 24 * 60 * 60_000
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      const users = dbraw.prepare("SELECT strftime('%Y-%m-%d', created_at/1000, 'unixepoch') AS day, COUNT(*) AS c FROM users WHERE created_at >= ? GROUP BY day ORDER BY day").all(sinceMs)
      const installs = dbraw.prepare("SELECT strftime('%Y-%m-%d', created_at/1000, 'unixepoch') AS day, COUNT(*) AS c FROM installations WHERE created_at >= ? GROUP BY day ORDER BY day").all(sinceMs)
      res.json({ ok: true, users, installs })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  // SSE: seedling-specific boosts stream
  app.get('/api/seedlings/:seedling_id/events', (req, res) => {
    if (!rateLimit(`events-seed:${req.ip}`, 120, 60_000)) return res.status(429).end()
    try {
      const seedling_id = String(req.params.seedling_id || '').trim()
      if (!seedling_id) return res.status(400).end()
      res.setHeader('Content-Type', 'text/event-stream')
      res.setHeader('Cache-Control', 'no-store, no-cache, no-transform')
      res.setHeader('Connection', 'keep-alive')
      res.flushHeaders && res.flushHeaders()
      const writeEvent = (event, data) => { try { if (event) res.write(`event: ${event}\n`); res.write(`data: ${JSON.stringify(data)}\n\n`) } catch (_) {} }
      writeEvent('init', { seedling_id, t: Date.now() })
      // Filtered snapshot
      try {
        const items = boosts.recent().filter(it => String(it.seedling_id || '') === seedling_id)
        writeEvent('snapshot', { items })
      } catch (_) {}
      const onBoost = (it) => { try { if (String(it.seedling_id || '') === seedling_id) writeEvent('boost', it) } catch (_) {} }
      const unsubscribe = boosts.subscribe(onBoost)
      const timer = setInterval(() => { writeEvent('ping', { t: Date.now() }) }, 20000)
      const close = () => { try { clearInterval(timer) } catch (_) {}; try { unsubscribe && unsubscribe() } catch (_) {}; try { res.end() } catch (_) {} }
      req.on('close', close)
      req.on('aborted', close)
    } catch (_) { try { res.end() } catch (_) {} }
  })

  // List seedlings for the current authenticated user
  app.get('/api/seedlings', (req, res) => {
    if (!rateLimit(`seedling-list:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess) return res.status(401).json({ ok: false, error: 'not_authenticated' })
      let rows = []
      try { rows = listInstallationsByUser(sess.user_id) } catch (e2) {
        try { writeAudit('seedlings:list_error', { message: e2?.message || String(e2) }) } catch (_) {}
        rows = []
      }
      // Filter revoked unless requested
      const includeRevoked = (() => { const v = String(req.query.include_revoked || '').toLowerCase(); return v === '1' || v === 'true' || v === 'yes' })()
      const out = includeRevoked ? rows : rows.filter(r => String(r.status || 'active') !== 'revoked')
      return res.json({ ok: true, seedlings: out })
    } catch (e) {
      try { writeAudit('seedlings:list_error', { message: e?.message || String(e) }) } catch (_) {}
      // Be resilient: return empty list instead of a hard failure
      return res.json({ ok: true, seedlings: [] })
    }
  })

  // Revoke a seedling owned by the current user
  app.post('/api/seedlings/revoke', express.json(), (req, res) => {
    if (!rateLimit(`seedling-revoke:${req.ip}`, 20, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess) return res.status(401).json({ ok: false, error: 'not_authenticated' })
      const install_id = String(req.body?.install_id || '')
      if (!install_id) return res.status(400).json({ ok: false, error: 'missing_install_id' })
      let ok = false
      try {
        ok = revokeInstallationOwned(sess.user_id, install_id)
      } catch (e) {
        try { writeAudit('seedlings:revoke_error', { message: e?.message || String(e), install_id, user_id: sess.user_id }) } catch (_) {}
        try { console.error('[revoke] db_error', { install_id, user_id: sess.user_id, error: e?.message || String(e) }) } catch (_) {}
        if (!isProd) return res.status(500).json({ ok: false, error: 'db_error', detail: String(e?.message || e || '') })
        return res.status(500).json({ ok: false, error: 'db_error' })
      }
      if (!ok) return res.status(404).json({ ok: false, error: 'not_found_or_not_owned' })
      return res.json({ ok: true })
    } catch (e) {
      try { writeAudit('seedlings:revoke_error', { message: e?.message || String(e) }) } catch (_) {}
      try { console.error('[revoke] unhandled', e) } catch (_) {}
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // (moved) /api/seedlings/bind is declared after JSON middleware and near mint API

  // Ownership check for a seedling (installation)
  app.get('/api/seedlings/:seedling_id/owner', (req, res) => {
    if (!rateLimit(`seedling-owner:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess) return res.status(401).json({ ok: false, error: 'not_authenticated' })
      const seedling_id = String(req.params.seedling_id || '').trim()
      if (!seedling_id) return res.status(400).json({ ok: false, error: 'missing_seedling_id' })
      const rec = getInstallation(seedling_id)
      if (!rec) return res.status(404).json({ ok: false, error: 'not_found' })
      const isOwner = String(rec.user_id || '') === String(sess.user_id || '')
      if (!isOwner) {
        // Allow auto-claim only if the caller proves possession of the secret key (sk)
        const skParam = String(req.query.sk || '').trim()
        if (!rec.user_id && skParam) {
          try {
            const raw = fromB64url(skParam)
            const calc = sha256hex(Buffer.concat([rec.salt || Buffer.alloc(0), raw]))
            if (calc === String(rec.key_hash || '')) {
              setInstallationUser(seedling_id, sess.user_id)
              try { writeAudit('seedling:auto_claim', { seedling_id, user_id: sess.user_id }) } catch (_) {}
              return res.json({ ok: true })
            }
          } catch (_) { /* ignore */ }
        }
        return res.status(403).json({ ok: false, error: 'forbidden' })
      }
      return res.json({ ok: true })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Per-seedling dynamic manifest
  app.get('/s/:seedling_id/:sk/manifest.json', (req, res) => {
    try {
      const seedling_id = String(req.params.seedling_id || '').trim()
      const sk = String(req.params.sk || '').trim()
      if (!seedling_id || !sk) return res.status(400).json({ error: 'missing_params' })
      const rec = getInstallation(seedling_id)
      if (!rec || !rec.salt || !rec.key_hash || String(rec.status || 'active') !== 'active') return res.status(401).json({ error: 'unauthorized' })
      const raw = fromB64url(sk)
      if (!raw || raw.length === 0) return res.status(401).json({ error: 'unauthorized' })
      const calc = sha256hex(Buffer.concat([rec.salt, raw]))
      if (calc !== String(rec.key_hash)) return res.status(401).json({ error: 'unauthorized' })
      const base = addonInterface && addonInterface.manifest ? addonInterface.manifest : (addonInterface && addonInterface.manifestRef ? addonInterface.manifestRef : null)
      const manifest = base ? { ...base } : {}
      try { delete manifest.stremioAddonsConfig } catch (_) {}
      const origin = originFromReq(req)
      try { manifest.endpoint = `${origin}/s/${seedling_id}/${sk}` } catch (_) {}
      try { manifest.configurationRequired = true } catch (_) {}
      try { manifest.configuration = `${origin}/s/${seedling_id}/${sk}/configure` } catch (_) {}
      manifest.seedsphere = Object.assign({}, manifest.seedsphere || {}, { seedling_id, config_scope: 'seedling' })
      try {
        if (rec.config_json && Array.isArray(manifest.config)) {
          const cfg = JSON.parse(Buffer.from(rec.config_json).toString('utf8'))
          if (cfg && typeof cfg === 'object') {
            manifest.config = manifest.config.map((entry) => {
              try { const k = entry && entry.key; return (k && Object.prototype.hasOwnProperty.call(cfg, k)) ? Object.assign({}, entry, { default: cfg[k] }) : entry } catch { return entry }
            })
          }
        }
      } catch (_) {}
      const reqOrigin = String(req.headers.origin || '')
      const isWebStremio = reqOrigin === 'https://web.strem.io' || reqOrigin === 'https://web.stremio.com'
      const assetBase = isWebStremio ? 'https://seedsphere.fly.dev' : origin
      if (assetBase) {
        manifest.logo = `${assetBase}/assets/icon-256.png`
        manifest.background = `${assetBase}/assets/background-1024.jpg`
      }
      res.setHeader('Cache-Control', 'public, max-age=300, stale-while-revalidate=600')
      return res.json(manifest)
    } catch (e) { return res.status(500).json({ error: e.message }) }
  })

  // Seedling auth validator for per-seedling routes (excludes manifest handled above)
  const reqctx = require('./lib/reqctx.cjs')
  function validateSeedling(req, res, next) {
    try {
      const seedling_id = String(req.params.seedling_id || '').trim()
      const sk = String(req.params.sk || '').trim()
      const rec = getInstallation(seedling_id)
      const isStreamReq = (req.method === 'GET') && ((req.path || '').startsWith('/stream'))
      const revoked = !!(rec && String(rec.status || 'active') !== 'active')
      if (!rec || !rec.salt || !rec.key_hash || revoked) {
        try { rolllog.log('seedling_validate', { component: 'validateSeedling', outcome: revoked ? 'revoked' : 'account_no_binding', seedling_id, method: req.method, path: req.path, isStreamReq }) } catch (_) {}
        if (isStreamReq) {
          try { res.setHeader('Cache-Control', 'no-store') } catch (_) {}
          try { writeAudit('fallback_stream', { where: 'sdk_validate', reason: revoked ? 'seedling_revoked' : 'account_no_binding', seedling_id }) } catch (_) {}
          try { writeAudit('informative_stream', { where: 'sdk_validate', reason: revoked ? 'seedling_revoked' : 'account_no_binding' }) } catch (_) {}
          const info = buildInformativeStream({
            reason: revoked ? 'seedling_revoked' : 'account_no_binding',
            details: { note: revoked ? 'This installation was revoked. Reinstall from Home.' : 'Installation is not linked or missing.' },
            labelName: 'SeedSphere',
            configureUrl: `/configure?seedling_id=${encodeURIComponent(seedling_id)}`,
          })
          return res.json({ streams: [info] })
        }
        // Non-stream request: if browser HTML, show error page; else JSON
        {
          const accept = String(req.headers.accept || '').toLowerCase()
          if (accept.includes('text/html')) {
            const base = originFromReq(req)
            const code = revoked ? 'seedling_revoked' : 'account_no_binding'
            const target = `${base}/error?code=${encodeURIComponent(code)}&seedling_id=${encodeURIComponent(seedling_id)}`
            return res.redirect(302, target)
          }
        }
        return res.status(401).json({ error: 'unauthorized' })
      }
      const raw = fromB64url(sk)
      if (!raw || raw.length === 0) {
        try { rolllog.log('seedling_validate', { component: 'validateSeedling', outcome: 'seedling_invalid_signature', seedling_id, method: req.method, path: req.path, isStreamReq, reason: 'empty_raw' }) } catch (_) {}
        if (isStreamReq) {
          try { res.setHeader('Cache-Control', 'no-store') } catch (_) {}
          try { writeAudit('fallback_stream', { where: 'sdk_validate', reason: 'seedling_invalid_signature', seedling_id }) } catch (_) {}
          const info = buildInformativeStream({ reason: 'seedling_invalid_signature', details: { note: 'Invalid link signature. Reopen Configure.' }, labelName: 'SeedSphere', configureUrl: `/configure?seedling_id=${encodeURIComponent(seedling_id)}` })
          return res.json({ streams: [info] })
        }
        {
          const accept = String(req.headers.accept || '').toLowerCase()
          if (accept.includes('text/html')) {
            const base = originFromReq(req)
            const target = `${base}/error?code=seedling_invalid_signature&seedling_id=${encodeURIComponent(seedling_id)}`
            return res.redirect(302, target)
          }
        }
        return res.status(401).json({ error: 'unauthorized' })
      }
      const calc = sha256hex(Buffer.concat([rec.salt, raw]))
      if (calc !== String(rec.key_hash)) {
        try { rolllog.log('seedling_validate', { component: 'validateSeedling', outcome: 'seedling_invalid_signature', seedling_id, method: req.method, path: req.path, isStreamReq, reason: 'mismatch' }) } catch (_) {}
        if (isStreamReq) {
          try { res.setHeader('Cache-Control', 'no-store') } catch (_) {}
          try { writeAudit('fallback_stream', { where: 'sdk_validate', reason: 'seedling_invalid_signature', seedling_id }) } catch (_) {}
          const info = buildInformativeStream({ reason: 'seedling_invalid_signature', details: { note: 'Invalid link signature. Reinstall from Home.' }, labelName: 'SeedSphere', configureUrl: `/configure?seedling_id=${encodeURIComponent(seedling_id)}` })
          return res.json({ streams: [info] })
        }
        {
          const accept = String(req.headers.accept || '').toLowerCase()
          if (accept.includes('text/html')) {
            const base = originFromReq(req)
            const target = `${base}/error?code=seedling_invalid_signature&seedling_id=${encodeURIComponent(seedling_id)}`
            return res.redirect(302, target)
          }
        }
        return res.status(401).json({ error: 'unauthorized' })
      }
      try { rolllog.log('seedling_validate', { component: 'validateSeedling', outcome: 'ok', seedling_id, method: req.method, path: req.path, isStreamReq, user_id: rec.user_id || undefined }) } catch (_) {}
      // Store per-seedling defaults from extras for future manifest regeneration
      try {
        if (req.method === 'GET' && (req.path || '').startsWith('/stream')) {
          const base = addonInterface && (addonInterface.manifest || addonInterface.manifestRef)
          const keys = (base && Array.isArray(base.config)) ? base.config.map(e => e && e.key).filter(Boolean) : []
          let cfg = {}
          // Parse extras from query: either flat keys or JSON in ?extra=
          if (req.query && typeof req.query === 'object') {
            if (typeof req.query.extra === 'string') {
              try { const obj = JSON.parse(req.query.extra); if (obj && typeof obj === 'object') cfg = obj } catch (_) {}
            }
            for (const k of keys) { if (req.query[k] !== undefined) cfg[k] = req.query[k] }
          }
          if (Object.keys(cfg).length > 0) setInstallationConfig(seedling_id, cfg)
        }
      } catch (_) {}
      touch(activeSeedlings, seedling_id, { user_id: rec.user_id || null })
      // Run downstream handlers within a request context containing seedling_id
      return reqctx.run({ seedling_id }, () => next())
    } catch (e) { return res.status(500).json({ error: e.message }) }
  }

  // Secure Configure: validate SK then let the SPA handle the dynamic route (place BEFORE insecure redirect)
  app.get('/s/:seedling_id/:sk/configure', validateSeedling, (req, res, next) => {
    try {
      const accept = String(req.headers.accept || '').toLowerCase()
      // For HTML navigations, fall through so Vite/prod static handler serves index.html and Vue Router takes over
      if (accept.includes('text/html')) return next()
      // For non-HTML, acknowledge route exists
      return res.json({ ok: true })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Friendly redirect for insecure Configure link without SK -> /configure-info (must come BEFORE addon router mount)
  app.get('/s/:seedling_id/configure', (req, res) => {
    try {
      const seedling_id = String(req.params.seedling_id || '').trim()
      const base = originFromReq(req)
      const target = `${base}/configure-info${seedling_id ? (`?seedling_id=${encodeURIComponent(seedling_id)}`) : ''}`
      return res.redirect(302, target)
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Mount addon router only under per-seedling prefix
  app.use('/s/:seedling_id/:sk', validateSeedling, addonInterface.getRouter())

  // Safety net: if addon is queried at base /stream/... (misinstalled without per-seedling),
  // ensure we still return an informative stream rather than an empty list.
  app.get('/stream/:type/:id', (req, res) => {
    try {
      res.setHeader('Cache-Control', 'no-store')
      const { type, id } = req.params || {}
      try { rolllog.log('stream_fallback', { component: 'server_base_stream', reason: 'account_no_binding', type, id }) } catch (_) {}
      const info = buildInformativeStream({
        reason: 'account_no_binding',
        details: { note: 'Addon installed without per-seedling endpoint. Reinstall from the Gardener app.' },
        labelName: 'SeedSphere',
        configureUrl: '/configure',
      })
      return res.json({ streams: [info] })
    } catch (e) {
      // Minimal fallback
      return res.json({ streams: [{ name: 'SeedSphere', title: 'SeedSphere — Installation not linked', description: 'Install the addon via the Gardener app so it uses a per‑seedling endpoint.\nConfigure: /configure', infoHash: '0000000000000000000000000000000000000000', behaviorHints: { bingeGroup: 'seedsphere-info', notWebReady: true } }] })
    }
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
      // Optional health payload
      const body = req.body || {}
      const queue = Number(body.queue || 0)
      const success1m = Number(body.success_1m || 0)
      const fail1m = Number(body.fail_1m || 0)
      const score = Number(body.healthscore || NaN)
      const obj = { queue: Number.isFinite(queue) ? queue : 0, s1m: Number.isFinite(success1m) ? success1m : 0, f1m: Number.isFinite(fail1m) ? fail1m : 0 }
      // Attach owning user_id and status from DB, if available, to support selection
      try {
        const rec = getGardenerWithCounts(gardener_id)
        if (rec && rec.user_id) obj.user_id = String(rec.user_id)
        if (rec && rec.status) obj.status = String(rec.status)
      } catch (_) {}
      if (Number.isFinite(score)) obj.score = Math.min(1, Math.max(0, score))
      touch(activeGardeners, gardener_id, obj)
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
      if (gardener_id) {
        // Dynamic: seedlings linked to the same account as this gardener
        let uid = ''
        try { const rec = getGardenerWithCounts(gardener_id); uid = String(rec && rec.user_id || '') } catch (_) {}
        if (uid) {
          try { out.linked_seedlings = listInstallationsByUser(uid).map(r => r.install_id) } catch (_) { out.linked_seedlings = [] }
          out.user_id = uid
        } else {
          out.linked_seedlings = []
        }
      }
      if (seedling_id) {
        // Optional: include owning user for UI convenience
        try { const rec = getInstallation(seedling_id); if (rec && rec.user_id) out.user_id = String(rec.user_id) } catch (_) {}
        // linked_gardeners is no longer used for hard links; keep empty for compatibility
        out.linked_gardeners = out.linked_gardeners || []
      }
      try {
        rolllog.log('link_status', {
          component: 'link_status',
          gardener_id: gardener_id || undefined,
          seedling_id: seedling_id || undefined,
          user_id: out.user_id || undefined,
          linked_seedlings_count: Array.isArray(out.linked_seedlings) ? out.linked_seedlings.length : 0,
        })
      } catch (_) {}
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

  // Rolling logs API (SSE + recent + emit)
  app.get('/api/logs/recent', (req, res) => {
    try {
      const limit = Math.max(1, Math.min(5000, parseInt(String(req.query.limit || '200'), 10) || 200))
      const filters = {
        type: String(req.query.type || '').trim() || undefined,
        component: String(req.query.component || '').trim() || undefined,
        user_id: String(req.query.user_id || '').trim() || undefined,
        gardener_id: String(req.query.gardener_id || '').trim() || undefined,
        seedling_id: String(req.query.seedling_id || '').trim() || undefined,
      }
      const items = rolllog.getRecent(limit, filters)
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, items })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })
  app.get('/api/logs/events', (req, res) => {
    try {
      if (!rateLimit(`logs:${req.ip}`, 200, 60_000)) return res.status(429).end()
      res.setHeader('Content-Type', 'text/event-stream')
      res.setHeader('Cache-Control', 'no-cache, no-transform')
      res.setHeader('Connection', 'keep-alive')
      res.setHeader('X-Accel-Buffering', 'no')
      res.setHeader('X-Content-Type-Options', 'nosniff')
      res.flushHeaders && res.flushHeaders()
      const filters = {
        type: String(req.query.type || '').trim() || undefined,
        component: String(req.query.component || '').trim() || undefined,
        user_id: String(req.query.user_id || '').trim() || undefined,
        gardener_id: String(req.query.gardener_id || '').trim() || undefined,
        seedling_id: String(req.query.seedling_id || '').trim() || undefined,
      }
      const unsub = rolllog.subscribe(res, filters, Math.max(1, Math.min(1000, parseInt(String(req.query.snapshot || '200'), 10) || 200)))
      const close = () => { try { unsub && unsub() } catch (_) {}; try { res.end() } catch (_) {} }
      req.on('close', close)
      req.on('aborted', close)
    } catch (e) { try { res.status(500).end() } catch (_) {} }
  })
  app.post('/api/logs/emit', (req, res) => {
    if (!rateLimit(`logs-emit:${req.ip}`, 120, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      const body = req.body || {}
      const type = String(body.type || 'client_event').trim()
      const data = Object.assign({}, body.data || {}, {
        component: String(body.component || 'client'),
        user_id: (sess && sess.user_id) ? String(sess.user_id) : (String(body.user_id || '').trim() || undefined),
        ip: req.ip,
      })
      rolllog.log(type, data)
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

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

  // --- In-memory TTL caches (180 minutes) and recent seedling window ---
  const TTL_MS = Number(process.env.ACTIVE_TTL_MS || (180 * 60_000))
  const SIZE_CAP = Number(process.env.ACTIVE_SIZE_CAP || 50_000)
  const RECENT_WINDOW_MS = Number(process.env.RECENT_SEEDLING_WINDOW_MS || (10 * 60_000))
  const activeUsers = new Map()      // user_id -> { ts }
  const activeGardeners = new Map()  // gardener_id -> { ts, queue, s1m, f1m, score }
  const activeSeedlings = new Map()  // seedling_id -> { ts, user_id }
  const lastSelectedGardener = new Map() // seedling_id -> { ts, gardener_id }
  const recentSeedlings = new Map()  // seedling_id -> { ts, user_id, sk }
  const MAX_SEEDLINGS_PER_USER = Number(process.env.MAX_SEEDLINGS_PER_USER || 20)

  // Admin: get in-memory health snapshot for a gardener
  app.get('/api/admin/gardeners/:gardener_id/health', requireAdmin, (req, res) => {
    try {
      const gid = String(req.params.gardener_id || '').trim()
      if (!gid) return res.status(400).json({ ok: false, error: 'missing_gardener_id' })
      const obj = activeGardeners.get(gid) || null
      res.json({ ok: true, health: obj })
    } catch (e) { res.status(500).json({ ok: false, error: e.message }) }
  })

  function touch(map, key, valueObj = {}) {
    const now = Date.now()
    const cur = map.get(key) || {}
    const next = Object.assign({}, cur, valueObj, { ts: now })
    map.set(key, next)
    if (map.size > SIZE_CAP) {
      const arr = Array.from(map.entries())
      arr.sort((a, b) => (a[1].ts || 0) - (b[1].ts || 0))
      const removeN = Math.ceil(arr.length / 10)
      for (let i = 0; i < removeN; i++) map.delete(arr[i][0])
    }
  }
  function originFromReq(req) {
    try {
      const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').toString()
      let host = (req.headers['x-forwarded-host'] || req.headers.host || 'localhost').toString()
      // In development, prefer localhost to avoid localStorage splitting between 127.0.0.1 and localhost
      if (!isProd) host = host.replace(/^127\.0\.0\.1(?::|$)/, (m) => m.replace('127.0.0.1', 'localhost'))
      return `${proto}://${host}`
    } catch (_) { return '' }
  }
  // Mask sensitive path segments such as /s/:seedling_id/:sk → /s/:seedling_id/xxxxx
  function maskSensitivePath(urlStr) {
    try {
      const [pathPart, queryPart] = String(urlStr || '').split('?', 2)
      const maskedPath = pathPart.replace(/(\/s\/[^\/?#]+\/)([^\/?#]+)/g, (_, a) => `${a}xxxxx`)
      return queryPart ? `${maskedPath}?${queryPart}` : maskedPath
    } catch (_) { return urlStr }
  }
  // Compute coarse IP bucket (/24 for IPv4, /64 for IPv6), XFF-aware
  function clientIpBucket(req) {
    try {
      const xff = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim()
      const ip = xff || String(req.ip || '').replace(/^::ffff:/, '')
      if (/^\d+\.\d+\.\d+\.\d+$/.test(ip)) {
        const parts = ip.split('.')
        return `${parts[0]}.${parts[1]}.${parts[2]}.0/24`
      }
      if (ip.includes(':')) {
        const segs = ip.split(':')
        return `${segs.slice(0, 4).join(':')}::/64`
      }
      return ip || 'unknown'
    } catch (_) { return 'unknown' }
  }
  // Device fingerprint for analytics (UA + Accept-Language + coarse IP bucket)
  function deviceFingerprint(req) {
    try {
      const ua = String(req.headers['user-agent'] || '')
      const lang = String(req.headers['accept-language'] || '')
      const bucket = clientIpBucket(req)
      return sha256hex(Buffer.from(`${ua}\n${lang}\n${bucket}`, 'utf8')).slice(0, 16)
    } catch (_) { return 'fp_unknown' }
  }
  function b64url(buf) {
    return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  }
  function fromB64url(str) {
    try {
      const pad = str.length % 4 === 2 ? '==' : (str.length % 4 === 3 ? '=' : (str.length % 4 === 1 ? '===' : ''))
      const b64 = str.replace(/-/g, '+').replace(/_/g, '/') + pad
      return Buffer.from(b64, 'base64')
    } catch (_) { return Buffer.alloc(0) }
  }
  function sha256hex(buf) { return crypto.createHash('sha256').update(buf).digest('hex') }
  function toStremioProtocol(uStr) { try { return uStr.replace(/^https?:\/\//, 'stremio://') } catch { return uStr } }
  function rememberRecentSeedling(user_id, seedling_id, sk) { recentSeedlings.set(seedling_id, { user_id, sk, ts: Date.now() }) }
  function getRecentSeedlingForUser(user_id) {
    try {
      if (!user_id) return null
      const rec = findRecentInstallationByUser(user_id, RECENT_WINDOW_MS)
      if (!rec) return null
      const entry = recentSeedlings.get(rec.install_id)
      if (!entry) return null
      if ((Date.now() - entry.ts) > RECENT_WINDOW_MS) { recentSeedlings.delete(rec.install_id); return null }
      return { seedling_id: rec.install_id, sk: entry.sk }
    } catch (_) { return null }
  }

  // Periodic prune based on TTL for active maps
  function pruneMap(map) {
    const now = Date.now()
    for (const [k, v] of map.entries()) {
      if (!v || typeof v.ts !== 'number') continue
      if ((now - v.ts) > TTL_MS) map.delete(k)
    }
  }
  try {
    const gcTimer = setInterval(() => { pruneMap(activeUsers); pruneMap(activeGardeners); pruneMap(activeSeedlings) }, Math.min(TTL_MS, 10 * 60_000))
    try { gcTimer.unref && gcTimer.unref() } catch (_) {}
  } catch (_) {}

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

  // Dev-only helper: generate a Magic Link callback URL (no email is sent)
  app.get('/api/auth/dev/magic', (req, res) => {
    try {
      if (String(process.env.NODE_ENV) === 'production') return res.status(404).json({ ok: false, error: 'not_found' })
      const email = String(req.query?.email || 'dev+e2e@example.com').trim().toLowerCase()
      if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return res.status(400).json({ ok: false, error: 'invalid_email' })
      const secret = process.env.AUTH_JWT_SECRET || 'dev-secret'
      const jti = nanoid()
      const token = jwt.sign({ sub: email, jti, typ: 'magic' }, secret, { issuer: 'seedsphere', audience: 'auth', expiresIn: '15m' })
      const proto = req.headers['x-forwarded-proto'] || req.protocol || 'http'
      const host = req.headers['x-forwarded-host'] || req.headers.host
      const link = `${proto}://${host}/api/auth/magic/callback?token=${encodeURIComponent(token)}`
      try { writeAudit('dev_magic', { email, jti }) } catch (_) {}
      return res.json({ ok: true, link })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // --- Seedling mint API ---
  app.post('/api/seedlings', (req, res) => {
    if (!rateLimit(`seedling-mint:${req.ip}`, 30, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess || !sess.user_id) return res.status(401).json({ ok: false, error: 'unauthorized' })
      try {
        const current = countInstallationsByUser(sess.user_id)
        // Honor admin setting for max seedlings per user if available
        let cap = MAX_SEEDLINGS_PER_USER
        try { const row = getCacheRow('admin:settings'); if (row && row.payload_json) { const s = JSON.parse(Buffer.from(row.payload_json).toString('utf8')); if (Number.isFinite(Number(s.max_seedlings_per_user))) cap = Number(s.max_seedlings_per_user) } } catch (_) {}
        if (Number.isFinite(cap) && current >= cap) {
          res.setHeader('Retry-After', '3600')
          return res.status(429).json({ ok: false, error: 'seedlings_cap' })
        }
      } catch (_) { /* ignore cap check errors */ }
      const user_id = sess.user_id
      const seedling_id = nanoid(16)
      upsertInstallation({ install_id: seedling_id, user_id })
      const skRaw = crypto.randomBytes(16)
      const sk = b64url(skRaw)
      const salt = crypto.randomBytes(16)
      const keyHash = sha256hex(Buffer.concat([salt, skRaw]))
      setInstallationSecret(seedling_id, salt, keyHash)
      setInstallationStatus && setInstallationStatus(seedling_id, 'active')
      rememberRecentSeedling(user_id, seedling_id, sk)
      const base = originFromReq(req)
      const manifestUrl = `${base}/s/${seedling_id}/${sk}/manifest.json`
      const stremioUrl = toStremioProtocol(manifestUrl)
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, seedling_id, sk, manifestUrl, stremioUrl })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // Bind a seedling to the current authenticated user (from Start.vue onboarding)
  app.post('/api/seedlings/bind', (req, res) => {
    if (!rateLimit(`seedling-bind:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const sess = readSession(req)
      if (!sess || !sess.user_id) return res.status(401).json({ ok: false, error: 'unauthorized' })
      const seedling_id = String((req.body && req.body.seedling_id) || (req.query && req.query.sid) || '').trim()
      const skParam = String((req.body && req.body.sk) || (req.query && req.query.sk) || '').trim()
      if (!seedling_id) return res.status(400).json({ ok: false, error: 'missing_seedling_id' })
      const rec = getInstallation(seedling_id)
      if (!rec) return res.status(404).json({ ok: false, error: 'not_found' })
      // If already owned by someone else, deny
      if (rec.user_id && String(rec.user_id) !== String(sess.user_id)) return res.status(403).json({ ok: false, error: 'forbidden' })
      // If already owned by the same user, return ok
      if (rec.user_id && String(rec.user_id) === String(sess.user_id)) { res.setHeader('Cache-Control', 'no-store'); return res.json({ ok: true }) }
      // Unowned: require valid sk proof to claim
      if (!skParam) return res.status(400).json({ ok: false, error: 'missing_sk' })
      try {
        const raw = fromB64url(skParam)
        const calc = sha256hex(Buffer.concat([rec.salt || Buffer.alloc(0), raw]))
        if (calc !== String(rec.key_hash || '')) return res.status(401).json({ ok: false, error: 'invalid_sk' })
      } catch (_) { return res.status(401).json({ ok: false, error: 'invalid_sk' }) }
      setInstallationUser(seedling_id, sess.user_id)
      touch(activeUsers, sess.user_id)
      touch(activeSeedlings, seedling_id, { user_id: sess.user_id })
      try { writeAudit('seedling:claimed', { seedling_id, user_id: sess.user_id }) } catch (_) {}
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })

  // --- Telemetry collector ---
  app.post('/api/telemetry/collect', async (req, res) => {
    if (!rateLimit(`tele:${req.ip}`, 120, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    const sharedKey = process.env.TELEMETRY_KEY || ''
    const provided = String(req.get('x-telemetry-key') || req.query.key || '')
    if (sharedKey && provided !== sharedKey) return res.status(401).json({ ok: false, error: 'unauthorized' })
    try {
      let sample = Math.max(0, Math.min(1, Number(process.env.TELEMETRY_SAMPLE || '1')))
      try { const row = getCacheRow('admin:settings'); if (row && row.payload_json) { const s = JSON.parse(Buffer.from(row.payload_json).toString('utf8')); if (s && s.telemetry_sample !== undefined) sample = Math.max(0, Math.min(1, Number(s.telemetry_sample))) } } catch (_) {}
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
      const sess = readSession(req)
      const body = req.body || {}
      const install_id = String(body.install_id || '').trim() || nanoid(12)
      // Enforce linking seedlings to users; require auth and link on creation
      if (!sess || !sess.user_id) return res.status(401).json({ ok: false, error: 'unauthorized' })
      upsertInstallation({ install_id, user_id: sess.user_id })
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
    try {
      const roomLimit = !isProd ? 10000 : 300
      if (!rateLimit(`room:${req.ip}`, roomLimit, 60_000)) return res.status(429).end()
      const gardener_id = String(req.params.gardener_id || '').trim() || 'default'
      res.setHeader('Content-Type', 'text/event-stream')
      res.setHeader('Cache-Control', 'no-cache, no-transform')
      res.setHeader('Connection', 'keep-alive')
      res.setHeader('X-Accel-Buffering', 'no')
      res.setHeader('X-Content-Type-Options', 'nosniff')
      try { req.socket && req.socket.setKeepAlive && req.socket.setKeepAlive(true, 60_000) } catch (_) {}
      res.flushHeaders && res.flushHeaders()
      // Send an immediate comment to flush bytes through proxies and clients
      try { res.write(`:ok\n\n`) } catch (_) {}
      try { res.write(`retry: 4000\n\n`) } catch (_) {}
      const writeEvent = (event, data) => { try { if (event) res.write(`event: ${event}\n`); res.write(`data: ${JSON.stringify(data)}\n\n`) } catch (_) {} }
      try { console.log('[sse] open gardener_room', gardener_id, req.ip) } catch (_) {}
      writeEvent('init', { gardener_id, t: Date.now(), clients: 1 })
      try { rolllog.log('sse_open', { component: 'gardener_room', gardener_id, ip: req.ip }) } catch (_) {}
      try { writeAudit('sse_open', { where: 'gardener_room', gardener_id, ip: req.ip }) } catch (_) {}
      // Associate this gardener with the current user session for coordination
      try {
        const sess = readSession(req)
        if (sess && sess.user_id) {
          // Ensure a gardener row exists before associating the user
          try { upsertGardener(gardener_id, 'web') } catch (_) {}
          setGardenerUser(gardener_id, sess.user_id)
          try { rolllog.log('sse_associate', { component: 'gardener_room', gardener_id, user_id: sess.user_id }) } catch (_) {}
          // Reflect association in in-memory health map as well (include status)
          try {
            const rec = getGardenerWithCounts(gardener_id)
            const info = { user_id: sess.user_id }
            if (rec && rec.status) info.status = String(rec.status)
            touch(activeGardeners, gardener_id, info)
          } catch (_) { try { touch(activeGardeners, gardener_id, { user_id: sess.user_id }) } catch (_) {} }
        }
      } catch (_) {}
      try { touchRoom(gardener_id); touchGardener(gardener_id) } catch (_) {}
      const unsubscribe = subscribe(gardener_id, res)
      const hb = setInterval(() => { try { touchGardener(gardener_id); res.write(`:keepalive\n\n`) } catch (_) {} }, 15000)
      const close = () => {
        try { clearInterval(hb) } catch (_) {}
        try { unsubscribe && unsubscribe() } catch (_) {}
        try { res.end() } catch (_) {}
        try { writeAudit('sse_close', { where: 'gardener_room', gardener_id, ip: req.ip }) } catch (_) {}
        try { rolllog.log('sse_close', { component: 'gardener_room', gardener_id, ip: req.ip }) } catch (_) {}
        try { console.log('[sse] close gardener_room', gardener_id, req.ip) } catch (_) {}
      }
      req.on('close', close)
      req.on('aborted', close)
    } catch (e) {
      try { console.error('[sse] error gardener_room', e && e.message ? e.message : String(e)) } catch (_) {}
      try { rolllog.log('sse_error', { component: 'gardener_room', error: e && e.message ? e.message : String(e) }) } catch (_) {}
      try { res.status(500).end() } catch (_) {}
    }
  })

  // Backward-compat SSE route
  app.get('/api/rooms/:room_id/events', (req, res) => {
    try {
      const roomLimit = !isProd ? 5000 : 120
      if (!rateLimit(`room:${req.ip}`, roomLimit, 60_000)) return res.status(429).end()
      const room_id = String(req.params.room_id || '').trim() || 'default'
      res.setHeader('Content-Type', 'text/event-stream')
      res.setHeader('Cache-Control', 'no-cache, no-transform')
      res.setHeader('Connection', 'keep-alive')
      res.setHeader('X-Accel-Buffering', 'no')
      res.setHeader('X-Content-Type-Options', 'nosniff')
      try { req.socket && req.socket.setKeepAlive && req.socket.setKeepAlive(true, 60_000) } catch (_) {}
      res.flushHeaders && res.flushHeaders()
      // Send an immediate comment to flush bytes through proxies and clients
      try { res.write(`:ok\n\n`) } catch (_) {}
      // Recommend reconnect delay
      try { res.write(`retry: 4000\n\n`) } catch (_) {}

      const writeEvent = (event, data) => {
        try {
          if (event) res.write(`event: ${event}\n`)
          res.write(`data: ${JSON.stringify(data)}\n\n`)
        } catch (_) { /* ignore */ }
      }

      try { console.log('[sse] open room', room_id, req.ip) } catch (_) {}
      writeEvent('init', { room_id, t: Date.now(), clients: 1 })
      try { writeAudit('sse_open', { where: 'room', room_id, ip: req.ip }) } catch (_) {}
      try { touchRoom(room_id) } catch (_) {}
      const unsubscribe = subscribe(room_id, res)
      const hb = setInterval(() => { try { res.write(`:keepalive\n\n`) } catch (_) {} }, 15000)
      const close = () => {
        try { clearInterval(hb) } catch (_) {}
        try { unsubscribe && unsubscribe() } catch (_) {}
        try { res.end() } catch (_) {}
        try { writeAudit('sse_close', { where: 'room', room_id, ip: req.ip }) } catch (_) {}
        try { console.log('[sse] close room', room_id, req.ip) } catch (_) {}
      }
      req.on('close', close)
      req.on('aborted', close)
    } catch (e) {
      try { console.error('[sse] error room', e && e.message ? e.message : String(e)) } catch (_) {}
      try { res.status(500).end() } catch (_) {}
    }
  })

  // --- Greenhouse: Tasks (issue and result) ---
  // Diagnostics: fetch recent fallback_stream reasons for seedling/gardener
  app.get('/api/diagnostics/fallbacks', (req, res) => {
    if (!rateLimit(`diag-fallbacks:${req.ip}`, 30, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const seedling_id = String(req.query.seedling_id || '').trim()
      const gardener_id = String(req.query.gardener_id || '').trim()
      const limit = Math.max(1, Math.min(50, parseInt(String(req.query.limit || '10'), 10) || 10))
      const minutes = Math.max(1, Math.min(1440, parseInt(String(req.query.minutes || '1440'), 10) || 1440))
      const since = Date.now() - minutes * 60_000
      const dbraw = require('better-sqlite3')(require('node:path').join(__dirname, 'data', 'seedsphere.db'))
      const rows = dbraw.prepare('SELECT at, meta_json FROM audit WHERE event = ? AND at >= ? ORDER BY at DESC LIMIT ?').all('fallback_stream', since, limit * 5)
      const items = []
      for (const r of rows) {
        let meta = {}
        try { meta = r.meta_json ? JSON.parse(Buffer.from(r.meta_json).toString('utf8')) : {} } catch (_) {}
        if (seedling_id && String(meta.seedling_id || '') !== seedling_id) continue
        if (gardener_id && String(meta.gardener_id || '') !== gardener_id) continue
        items.push({ at: r.at, reason: meta.reason || 'unknown', where: meta.where || 'unknown', seedling_id: meta.seedling_id || '', gardener_id: meta.gardener_id || '' })
        if (items.length >= limit) break
      }
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, items })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
  })
  app.post('/api/tasks/request', (req, res) => {
    if (!rateLimit(`task-req:${req.ip}`, 60, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
    try {
      const body = req.body || {}
      let room_id = String(body.room_id || '').trim()
      const task = {
        type: String(body.type || 'normalize'),
        params: body.params || {},
        aud: 'executor',
      }

      // Optional routing hints
      const seedling_id = String(body.seedling_id || '').trim()
      let user_id = String(body.user_id || '').trim()
      if (!user_id && seedling_id) {
        try { const rec = getInstallation(seedling_id); if (rec && rec.user_id) user_id = String(rec.user_id) } catch (_) {}
      }

      // If no explicit room provided, try to select a gardener for the user
      let selected_gardener = ''
      if (!room_id && user_id) {
        selected_gardener = pickGardenerForUser(user_id)
        if (selected_gardener) room_id = selected_gardener
      }
      // Fallback: generate a transient room if none could be resolved
      if (!room_id) room_id = nanoid(10)

      const secret = process.env.AUTH_JWT_SECRET || 'dev-secret'
      const token = jwt.sign(task, secret, { expiresIn: '5m' })
      // Publish notify event to room that a task is available (optional)
      publish(room_id, 'task', { token, type: task.type, seedling_id: seedling_id || undefined, user_id: user_id || undefined })
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, token, room_id, gardener_id: selected_gardener || undefined, user_id: user_id || undefined })
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
    }
  })

  // Gardener selection: choose the healthiest available gardener for a user
  function pickGardenerForUser(user_id) {
    try {
      if (!user_id) return ''
      const now = Date.now()
      // consider presence in last 60s
      const FRESH_MS = 60_000
      const candidates = []
      for (const [gid, obj] of activeGardeners.entries()) {
        // require association and recent heartbeat/touch
        const owned = (obj && String(obj.user_id || obj.userId || obj.user) === String(user_id))
        const fresh = obj && typeof obj.ts === 'number' && (now - obj.ts) <= FRESH_MS
        if (!owned || !fresh) continue
        // skip revoked gardeners
        let revoked = false
        if (obj && typeof obj.status !== 'undefined') revoked = String(obj.status) === 'revoked'
        if (!revoked) {
          try {
            const rec = getGardenerWithCounts(gid)
            if (!rec || String(rec.status || '') === 'revoked') revoked = true
          } catch (_) {}
        }
        if (revoked) continue
        const score = Number(obj.score || 0)
        const queue = Number(obj.queue || 0)
        const f1m = Number(obj.f1m || 0)
        candidates.push({ gid, score, queue, f1m })
      }
      if (candidates.length === 0) return ''
      candidates.sort((a, b) => (b.score - a.score) || (a.queue - b.queue) || (a.f1m - b.f1m) || (a.gid < b.gid ? -1 : 1))
      return candidates[0].gid
    } catch (_) { return '' }
  }

  // Admin: preview which gardener would be selected for a user/seedling
  app.get('/api/admin/dispatch/preview', requireAdmin, (req, res) => {
    try {
      const qSeedling = String(req.query.seedling_id || '').trim()
      let qUser = String(req.query.user_id || '').trim()
      if (!qUser && qSeedling) {
        try { const rec = getInstallation(qSeedling); if (rec && rec.user_id) qUser = String(rec.user_id) } catch (_) {}
      }
      const gardener_id = qUser ? pickGardenerForUser(qUser) : ''
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, user_id: qUser || undefined, gardener_id: gardener_id || null })
    } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
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

  // Health endpoint
  app.get('/health', (req, res) => {
    try { res.setHeader('Cache-Control', 'no-store') } catch (_) {}
    return res.json({ ok: true })
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

  // Configure page: serve an informative screen for Configure flows
  app.get('/configure', (req, res) => {
    try {
      const file = path.resolve(__dirname, '../public/configure/index.html')
      return res.sendFile(file)
    } catch (e) {
      return res.status(500).json({ ok: false, error: e.message })
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
      // Determine owning user from seedling, then associate gardener to that user (no hard links)
      const rec = getInstallation(seedling_id)
      if (!rec) return res.status(404).json({ ok: false, error: 'seedling_not_found' })
      const user_id = String(rec.user_id || '')
      if (!user_id) return res.status(400).json({ ok: false, error: 'seedling_not_owned' })
      upsertGardener(gardener_id, 'web')
      setGardenerUser(gardener_id, user_id)
      try { touch(activeGardeners, gardener_id, { user_id }) } catch (_) {}
      // Best-effort: ensure seedling exists in DB
      upsertSeedling(seedling_id)
      res.setHeader('Cache-Control', 'no-store')
      return res.json({ ok: true, gardener_id, user_id })
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

  // Root manifest: return recent per-seedling manifest for session, else redirect to /#/start or return base manifest for JSON fetches
  app.get(['/manifest.json', '/manifest'], (req, res) => {
    try { console.log('[manifest] request', { ip: req.ip, ua: req.headers['user-agent'], q: req.query, accept: req.headers.accept || '' }) } catch (_) {}
    try {
      // If the manifest URL is opened in a browser/webview (Accept includes text/html),
      // redirect to /#/start onboarding instead of returning JSON.
      // Normal addon fetches (Accept: application/json) should get JSON.
      const accept = String(req.headers.accept || '').toLowerCase()
      if (accept.includes('text/html')) {
        const target = `${originFromReq(req)}/#/start`
        return res.redirect(302, target)
      }
      // For JSON fetches: if session has a recent seedling, return its per-seedling manifest directly
      const sess = readSession(req)
      const recent = (sess && sess.user_id) ? getRecentSeedlingForUser(sess.user_id) : null
      if (recent && recent.seedling_id && recent.sk) {
        const origin = originFromReq(req)
        const base = addonInterface && addonInterface.manifest ? addonInterface.manifest : (addonInterface && addonInterface.manifestRef ? addonInterface.manifestRef : null)
        const manifest = base ? { ...base } : {}
        try { delete manifest.stremioAddonsConfig } catch (_) {}
        try { manifest.endpoint = `${origin}/s/${recent.seedling_id}/${recent.sk}` } catch (_) {}
        try { manifest.configurationRequired = true } catch (_) {}
        try { manifest.configuration = `${origin}/#/start?sid=${recent.seedling_id}` } catch (_) {}
        manifest.seedsphere = Object.assign({}, manifest.seedsphere || {}, { seedling_id: recent.seedling_id, config_scope: 'seedling' })
        const reqOrigin = String(req.headers.origin || '')
        const isWebStremio = reqOrigin === 'https://web.strem.io' || reqOrigin === 'https://web.stremio.com'
        const assetBase = isWebStremio ? 'https://seedsphere.fly.dev' : origin
        if (assetBase) {
          manifest.logo = `${assetBase}/assets/icon-256.png`
          manifest.background = `${assetBase}/assets/background-1024.jpg`
        }
        try { rolllog.log('manifest_recent_seedling', { component: 'manifest', endpoint: manifest.endpoint || origin, seedling_id: recent.seedling_id, user_id: (sess && sess.user_id) || undefined }) } catch (_) {}
        res.setHeader('Cache-Control', 'public, max-age=300, stale-while-revalidate=600')
        return res.json(manifest)
      }
      // Fallback to base manifest (legacy)
      const base = addonInterface && addonInterface.manifest ? addonInterface.manifest : (addonInterface && addonInterface.manifestRef ? addonInterface.manifestRef : null)
      const manifest = base ? { ...base } : {}
      try { delete manifest.stremioAddonsConfig } catch (_) {}
      const origin = originFromReq(req)
      try { manifest.endpoint = origin } catch (_) {}
      const reqOrigin = String(req.headers.origin || '')
      const isWebStremio = reqOrigin === 'https://web.strem.io' || reqOrigin === 'https://web.stremio.com'
      const assetBase = isWebStremio ? 'https://seedsphere.fly.dev' : origin
      if (assetBase) {
        manifest.logo = `${assetBase}/assets/icon-256.png`
        manifest.background = `${assetBase}/assets/background-1024.jpg`
      }
      try { rolllog.log('manifest_base', { component: 'manifest', endpoint: manifest.endpoint || origin }) } catch (_) {}
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

  // NOTE: SDK router is mounted under per-seedling prefix earlier; do not mount at root

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
      if (!gardener_id || !seedling_id) {
        try { res.setHeader('Cache-Control', 'no-store') } catch (_) {}
        try { writeAudit('fallback_stream', { where: 'bridge', reason: 'account_missing_identities', gardener_id, seedling_id }) } catch (_) {}
        const accept = String(req.headers.accept || '').toLowerCase()
        if (accept.includes('text/html')) {
          const base = originFromReq(req)
          const target = `${base}/error?code=account_missing_identities`
          return res.redirect(302, target)
        }
        const info = buildInformativeStream({ reason: 'account_missing_identities', details: { note: 'Missing identities headers.' }, labelName: 'SeedSphere', configureUrl: '/configure' })
        return res.json({ streams: [info] })
      }
      const secret = getBindingSecret(gardener_id, seedling_id)
      if (!secret) {
        try { res.setHeader('Cache-Control', 'no-store') } catch (_) {}
        try { writeAudit('fallback_stream', { where: 'bridge', reason: 'account_no_binding', gardener_id, seedling_id }) } catch (_) {}
        const accept = String(req.headers.accept || '').toLowerCase()
        if (accept.includes('text/html')) {
          const base = originFromReq(req)
          const target = `${base}/error?code=account_no_binding&seedling_id=${encodeURIComponent(seedling_id)}`
          return res.redirect(302, target)
        }
        const info = buildInformativeStream({ reason: 'account_no_binding', details: { note: 'No binding found for this Gardener/Seedling pair.' }, labelName: 'SeedSphere', configureUrl: `/configure?seedling_id=${encodeURIComponent(seedling_id)}` })
        return res.json({ streams: [info] })
      }
      if (!verifySignature(secret, req)) {
        try { res.setHeader('Cache-Control', 'no-store') } catch (_) {}
        try { writeAudit('fallback_stream', { where: 'bridge', reason: 'account_invalid_signature', gardener_id, seedling_id }) } catch (_) {}
        const accept = String(req.headers.accept || '').toLowerCase()
        if (accept.includes('text/html')) {
          const base = originFromReq(req)
          const target = `${base}/error?code=account_invalid_signature&seedling_id=${encodeURIComponent(seedling_id)}&gardener_id=${encodeURIComponent(gardener_id)}`
          return res.redirect(302, target)
        }
        const info = buildInformativeStream({ reason: 'account_invalid_signature', details: { note: 'Signature verification failed.' }, labelName: 'SeedSphere', configureUrl: `/configure?seedling_id=${encodeURIComponent(seedling_id)}` })
        return res.json({ streams: [info] })
      }

      // Signature OK: record last selected gardener for this seedling (displayed in Configure badge)
      try { touch(lastSelectedGardener, seedling_id, { gardener_id }) } catch (_) {}

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

      // Fallback to informative stream to always return at least one stream
      res.setHeader('Cache-Control', 'no-store')
      const reason = (lastError && String(lastError.message || '').includes('timeout')) ? 'global_timeout' : 'no_results'
      try { writeAudit('fallback_stream', { where: 'bridge', reason, gardener_id, seedling_id }) } catch (_) {}
      const info = buildInformativeStream({
        reason,
        details: { note: 'Stream bridge exhausted retry budgets; open Configure to review settings.' },
        labelName: 'SeedSphere',
        configureUrl: `/configure?seedling_id=${encodeURIComponent(seedling_id || '')}`,
      })
      return res.json({ streams: [info] })
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
      const streams = await aggregateStreams({
        type,
        id,
        providers,
        trackers: effective,
        bingeGroup: 'seedsphere-optimized',
        labelName,
        descAppendOriginal,
        descRequireDetails,
        aiConfig,
        // Performance knobs
        probeProviders: String(cfg.probe_providers || 'off').toLowerCase() === 'on',
        probeTimeoutMs: Number(cfg.probe_timeout_ms) || undefined,
        providerFetchTimeoutMs: Number(cfg.provider_fetch_timeout_ms) || undefined,
        maxProviderConcurrency: Number(cfg.max_provider_concurrency) || undefined,
      })
      return { streams: Array.isArray(streams) ? streams : [] }
    } catch (_) { return { streams: [] } }
  }

  // In development, mount Vite after the API routes so /api and SSE endpoints are handled by Express first.
  if (!isProd && !opts.disableVite && !process.env.SEEDSPHERE_DISABLE_VITE) {
    const { createServer: createViteServer } = await import('vite')
    const useHttpsForHmr = Boolean(httpsServer && httpsPort)
    const hmr = useHttpsForHmr
      ? { server: httpsServer, port: httpsPort, clientPort: httpsPort, protocol: 'wss' }
      : { server: httpServer, port: listenPort, clientPort: listenPort }
    const vite = await createViteServer({ server: { middlewareMode: true, hmr }, appType: 'custom' })
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
        p.startsWith('/stream') ||
        /^\/s\/[^/]+\/[^/]+\/stream\//.test(p)
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
      const pfWarm = setTimeout(() => { prefetchPopular().catch(() => {}) }, 2000)
      try { pfWarm.unref && pfWarm.unref() } catch (_) {}
      const pfTimer = setInterval(() => { prefetchPopular().catch(() => {}) }, PREFETCH_INTERVAL_MS)
      try { pfTimer.unref && pfTimer.unref() } catch (_) {}
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
      if (httpsServer && httpsPort) {
        try {
          httpsServer.listen(httpsPort, () => {
            try {
              const a = httpsServer.address()
              const p = (a && typeof a === 'object') ? a.port : httpsPort
              if (process.env.NO_SERVER_LOG !== '1') {
                console.log(`Server listening on https://localhost:${p}`)
              }
            } catch (_) {}
          })
        } catch (e) { try { console.error('[https] listen failed', e?.message || e) } catch (_) {} }
      }
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
