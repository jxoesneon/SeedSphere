#!/usr/bin/env node

const path = require("path")
const http = require("http")
const express = require("express")
let compression = null
try { compression = require("compression") } catch (_) { /* optional */ }
const { execSync } = require("child_process")
const axios = require("axios")
const { getRouter, publishToCentral } = require("stremio-addon-sdk")
const boosts = require("./lib/boosts")
const { isTrackerUrl, unique, filterByHealth } = require("./lib/health")
const addonInterface = require("./addon")
const { getHealthStats } = require("./lib/health")

const BASE_PORT = Number(process.env.PORT) || 55025
const STRICT_PORT = Boolean(process.env.PORT)

const app = express()
if (compression) app.use(compression())
const server = http.createServer(app)

// Static assets
const PUBLIC_DIR = path.join(__dirname, "public")
// Ensure manifest is always revalidated by clients (so Stremio sees updates)
app.use((req, res, next) => {
  if (req.path === '/manifest.json') {
    res.setHeader('Cache-Control', 'no-cache')
  }
  next()
})
// Serve root landing page and static assets
function setCSP(res) {
  // Allow self assets; images can be https or data URIs for QR
  res.setHeader("Content-Security-Policy",
    [
      "default-src 'self'",
      "script-src 'self'",
      "style-src 'self'",
      "img-src 'self' https: data:",
      "connect-src 'self'",
      "frame-ancestors 'none'",
    ].join('; ')
  )
}
app.get("/", (_req, res) => {
  setCSP(res)
  res.sendFile(path.join(PUBLIC_DIR, "index.html"))
})
app.use(express.static(PUBLIC_DIR, {
  setHeaders: (res, filePath) => {
    // Immutable cache for versioned assets
    if (filePath.includes(path.join("public", "assets"))) {
      res.setHeader("Cache-Control", "public, max-age=31536000, immutable")
    } else {
      res.setHeader("Cache-Control", "public, max-age=300")
    }
  },
}))

// Static assets for browser-based /configure helper page
const CONFIGURE_DIR = path.join(__dirname, "public", "configure")
// Force our custom /configure page to override SDK's landing
app.all("/configure", (_req, res) => {
  setCSP(res)
  res.sendFile(path.join(CONFIGURE_DIR, "index.html"))
})

// Minimal CORS for API (read-only GET endpoints)
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  if (req.method === 'OPTIONS') return res.sendStatus(204)
  next()
})

// Simple in-memory rate limiter
const rlStore = new Map() // key -> { ts, count }
function rateLimit(key, limit = 60, windowMs = 60_000) {
  const now = Date.now()
  const rec = rlStore.get(key)
  if (!rec || (now - rec.ts) > windowMs) { rlStore.set(key, { ts: now, count: 1 }); return true }
  if (rec.count >= limit) return false
  rec.count += 1
  return true
}

// On-demand sweep: fetch a trackers list URL and run health filtering
app.get("/api/trackers/sweep", async (req, res) => {
  if (!rateLimit(`sweep:${req.ip}` , 30, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
  try {
    const url = String(req.query.url || "").trim()
    const mode = String(req.query.mode || "basic").toLowerCase()
    const limit = Math.max(0, parseInt(String(req.query.limit || "0"), 10) || 0)
    if (!url) return res.status(400).json({ ok: false, error: "missing_url" })
    // basic input validation
    try {
      const u = new URL(url)
      if (!/^https?:$/i.test(u.protocol)) return res.status(400).json({ ok: false, error: 'invalid_scheme' })
      if (url.length > 1024) return res.status(400).json({ ok: false, error: 'url_too_long' })
    } catch (_) { return res.status(400).json({ ok: false, error: 'invalid_url' }) }
    const response = await axios.get(url, { timeout: 12000 })
    const text = typeof response.data === "string" ? response.data : String(response.data)
    const urls = unique(text.split("\n").map((t) => t.trim()).filter((t) => t && !t.startsWith("#") && isTrackerUrl(t)))
    const healthy = await filterByHealth(urls, mode, limit)
    return res.json({ ok: true, total: urls.length, healthy: healthy.length, limit, mode, sample: healthy.slice(0, 10) })
  } catch (e) {
    return res.status(500).json({ ok: false, error: e.message })
  }
})
app.get("/configure/index.html", (_req, res) => {
  res.sendFile(path.join(CONFIGURE_DIR, "index.html"))
})
app.use("/configure", express.static(CONFIGURE_DIR))

// Health endpoint (extended)
const pkg = require("./package.json")
const { getLastFetch } = require("./lib/trackers_meta")
app.get(["/health"], (_req, res) => {
  res.json({
    ok: true,
    version: pkg.version || "",
    uptime_s: Math.round(process.uptime()),
    last_trackers_fetch_ts: getLastFetch() || 0,
  })
})

// Recent boosts for visibility
app.get("/api/boosts/recent", (_req, res) => {
  if (!rateLimit(`recent:${_req.ip}`, 120, 60_000)) return res.status(429).json({ ok: false, error: 'rate_limited' })
  try {
    res.json({ ok: true, items: boosts.recent() })
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message })
  }
})

// SSE: live boost events
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

  // Initial version info for client self-update banner
  writeEvent('server-info', { version: pkg.version || '' })

  // Initial snapshot
  writeEvent('snapshot', { items: boosts.recent() })

  const onBoost = (it) => writeEvent('boost', it)
  const unsubscribe = boosts.subscribe(onBoost)

  // keepalive pings
  const timer = setInterval(() => {
    writeEvent('ping', { t: Date.now() })
    // Periodic version broadcast (cheap) so clients can react without polling
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

// Health stats endpoint for tracker validator cache
app.get("/api/trackers/health", (_req, res) => {
  try {
    const stats = getHealthStats()
    res.json(stats)
  } catch (e) {
    res.status(500).json({ error: e.message })
  }
})

// URL validation endpoint for the browser UI
app.get("/api/validate", async (req, res) => {
  const target = (req.query.url || "").toString()
  if (!target) return res.status(400).json({ ok: false, error: "Missing url" })
  try {
    const response = await axios.get(target, { timeout: 8000 })
    const text = typeof response.data === "string" ? response.data : String(response.data)
    const lines = text
      .split("\n")
      .map((t) => t.trim())
      .filter((t) => t && !t.startsWith("#"))
    const looksLikeTrackers = lines.filter((l) => /^(udp|http|https|ws):\/\//i.test(l))
    res.json({ ok: looksLikeTrackers.length > 0, count: looksLikeTrackers.length, sample: looksLikeTrackers.slice(0, 5) })
  } catch (e) {
    res.status(200).json({ ok: false, error: e.message })
  }
})

// Start HTTP server with auto-fallback if port is in use (unless PORT is explicitly set)
function freePortIfBusy(port) {
  try {
    // macOS: use lsof to get PIDs listening on the port
    const out = execSync(`lsof -nP -iTCP:${port} -sTCP:LISTEN -t`, { stdio: ["ignore", "pipe", "ignore"] })
    const pids = out.toString().split(/\s+/).map((s) => s.trim()).filter(Boolean)
    for (const pid of pids) {
      try {
        process.kill(Number(pid), "SIGKILL")
        console.warn(`Killed process ${pid} that was listening on port ${port}`)
      } catch (_) {}
    }
    return pids.length > 0
  } catch (_) {
    return false
  }
}

function delay(ms) { return new Promise((r) => setTimeout(r, ms)) }

function startOnPort(port, attemptsLeft = 10, freeRetries = 3) {
  const srv = server
    .listen(port, () => {
      console.log(`SeedSphere Addon listening on http://127.0.0.1:${port}`)
    })
    .on("error", (err) => {
      if (err && err.code === "EADDRINUSE") {
        (async () => {
          while (freeRetries > 0) {
            const killed = freePortIfBusy(port)
            if (killed) {
              console.warn(`Port ${port} was busy; freed. Retrying same port...`)
              await delay(300)
              return startOnPort(port, attemptsLeft, freeRetries - 1)
            }
            // If nothing to kill but still busy, small wait then retry
            await delay(200)
            freeRetries -= 1
          }
          if (STRICT_PORT || attemptsLeft <= 0) {
            console.error(`Port ${port} is in use and no fallback allowed. Could not free it. Set a free PORT or stop the other process.`)
            process.exit(1)
          }
          const next = port + 1
          console.warn(`Port ${port} in use, retrying on ${next}...`)
          startOnPort(next, attemptsLeft - 1)
        })()
      } else {
        console.error("Server error:", err)
        process.exit(1)
      }
    })
  return srv
}

// Attach Stremio SDK HTTP router to our Express app
app.use(getRouter(addonInterface))
// Kick off server
startOnPort(BASE_PORT)

// when you've deployed your addon, un-comment this line
// publishToCentral("https://my-addon.awesome/manifest.json")
// for more information on deploying, see: https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/deploying/README.md
