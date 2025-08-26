#!/usr/bin/env node

const path = require("path")
const http = require("http")
const express = require("express")
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
const server = http.createServer(app)

// Static assets for browser-based /configure helper page
const CONFIGURE_DIR = path.join(__dirname, "public", "configure")
// Force our custom /configure page to override SDK's landing
app.all("/configure", (_req, res) => {
  res.sendFile(path.join(CONFIGURE_DIR, "index.html"))
})

// On-demand sweep: fetch a trackers list URL and run health filtering
app.get("/api/trackers/sweep", async (req, res) => {
  try {
    const target = (req.query.url || "").toString()
    const mode = (req.query.mode || "basic").toString()
    let limit = Number(req.query.limit)
    if (!Number.isFinite(limit) || limit < 0) limit = 0 // 0 = unlimited
    if (!target) return res.status(400).json({ ok: false, error: "Missing url" })
    const response = await axios.get(target, { timeout: 12000 })
    const text = typeof response.data === "string" ? response.data : String(response.data)
    const urls = unique(text.split("\n").map((t) => t.trim()).filter((t) => t && !t.startsWith("#") && isTrackerUrl(t)))
    const healthy = await filterByHealth(urls, mode.toLowerCase(), limit)
    return res.json({ ok: true, total: urls.length, healthy: healthy.length, limit, mode, sample: healthy.slice(0, 10) })
  } catch (e) {
    return res.status(500).json({ ok: false, error: e.message })
  }
})
app.get("/configure/index.html", (_req, res) => {
  res.sendFile(path.join(CONFIGURE_DIR, "index.html"))
})
app.use("/configure", express.static(CONFIGURE_DIR))

// Health endpoint (optional, helpful for debugging)
app.get(["/", "/health"], (_req, res) => {
  res.type("text/plain").send("OK")
})

// Recent boosts for visibility
app.get("/api/boosts/recent", (_req, res) => {
  try {
    res.json({ ok: true, items: boosts.recent() })
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message })
  }
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
