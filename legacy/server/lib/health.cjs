const axios = require("axios")
const dns = require("dns").promises
const dgram = require("dgram")

const HEALTH_TTL_MS = 24 * 60 * 60 * 1000
const healthCache = new Map() // trackerUrl -> { ok: boolean, ts: number, lastError?: string }
const VALIDATION_CONCURRENCY = 8
const RETRIES = 2
const BACKOFF_MS = 300

function isTrackerUrl(s) {
  return /^(udp|http|https|ws):\/\//i.test(s)
}

function unique(arr) {
  return Array.from(new Set(arr))
}

async function dnsResolves(hostname) {
  try {
    const res = await dns.lookup(hostname, { all: false })
    return Boolean(res && res.address)
  } catch (e) { return false }
}

async function httpHeadOk(origin, timeout = 2500) {
  try {
    const resp = await axios.head(origin, { timeout, maxRedirects: 2, validateStatus: () => true })
    if (resp.status >= 200 && resp.status < 400) return true
    const getResp = await axios.get(origin, { timeout, maxRedirects: 2, validateStatus: () => true })
    return getResp.status >= 200 && getResp.status < 400
  } catch (_) { return false }
}

function parseHost(urlStr) { try { return new URL(urlStr).hostname } catch (_) { return "" } }
function originFrom(urlStr) { try { const u = new URL(urlStr); return `${u.protocol}//${u.host}` } catch (_) { return urlStr } }

async function checkHealthyBasic(urlStr) {
  const cached = healthCache.get(urlStr)
  const now = Date.now()
  if (cached && (now - cached.ts) < HEALTH_TTL_MS) return cached.ok
  let ok = true, lastError = ""
  const host = parseHost(urlStr)
  if (!host) { ok = false; lastError = "no-host" }
  else {
    const resolved = await dnsResolves(host)
    if (!resolved) { ok = false; lastError = "dns" }
    if (ok && /^https?:\/\//i.test(urlStr)) {
      const fine = await httpHeadOk(originFrom(urlStr))
      if (!fine) { ok = false; lastError = "http" }
    }
  }
  healthCache.set(urlStr, { ok, ts: now, lastError })
  return ok
}

// Simple token bucket for UDP checks
let udpTokens = 20
let lastRefill = Date.now()
function takeUdpToken() {
  const now = Date.now()
  if (now - lastRefill >= 60_000) { udpTokens = 20; lastRefill = now }
  if (udpTokens <= 0) return false
  udpTokens -= 1
  return true
}

function udpTrackerConnectOk(urlStr, timeoutMs = 2500) {
  return new Promise((resolve) => {
    try {
      const u = new URL(urlStr)
      const host = u.hostname
      const port = Number(u.port || 80)
      if (!host || !port) return resolve(false)
      if (!takeUdpToken()) return resolve(false)
      const sock = dgram.createSocket('udp4')
      const connReq = Buffer.alloc(16)
      // protocol ID 0x41727101980
      connReq.writeUInt32BE(0x417, 0)
      connReq.writeUInt32BE(0x27101980, 4)
      connReq.writeUInt32BE(0, 8) // action connect
      const txId = (Math.random() * 0xffffffff) >>> 0
      connReq.writeUInt32BE(txId, 12)
      let done = false
      const finalize = (val) => { if (!done) { done = true; try { sock.close() } catch (_) {}; resolve(val) } }
      const timer = setTimeout(() => finalize(false), timeoutMs)
      sock.on('message', (msg) => {
        if (done) return
        if (msg.length < 16) return
        const action = msg.readUInt32BE(0)
        const rtx = msg.readUInt32BE(4)
        if (action === 0 && rtx === txId) { // connect response
          clearTimeout(timer)
          finalize(true)
        }
      })
      sock.on('error', () => finalize(false))
      sock.send(connReq, port, host, (err) => { if (err) finalize(false) })
    } catch (_) { resolve(false) }
  })
}

async function checkHealthyAggressive(urlStr) {
  // UDP trackers: do a UDP connect handshake
  if (/^udp:\/\//i.test(urlStr)) {
    const ok = await udpTrackerConnectOk(urlStr)
    healthCache.set(urlStr, { ok, ts: Date.now(), lastError: ok ? "" : "udp" })
    return ok
  }
  // HTTP(S): stronger retry
  let ok = await checkHealthyBasic(urlStr)
  if (ok) return true
  if (/^https?:\/\//i.test(urlStr)) {
    const fine = await httpHeadOk(originFrom(urlStr), 4000)
    if (fine) {
      healthCache.set(urlStr, { ok: true, ts: Date.now(), lastError: "" })
      return true
    }
  }
  return false
}

async function delay(ms) { return new Promise((r) => setTimeout(r, ms)) }

async function checkWithRetry(urlStr, mode) {
  for (let attempt = 0; attempt <= RETRIES; attempt++) {
    const ok = (mode === "aggressive") ? await checkHealthyAggressive(urlStr)
             : (mode === "off") ? true
             : await checkHealthyBasic(urlStr)
    if (ok) return true
    if (attempt < RETRIES) await delay(BACKOFF_MS * Math.pow(2, attempt))
  }
  return false
}

async function filterByHealth(urls, mode, limit, onProgress) {
  const results = []
  const cap = (!limit || limit <= 0) ? Infinity : limit
  const queue = Array.from(urls)
  let stopped = false
  let processed = 0

  async function worker() {
    while (!stopped) {
      const u = queue.shift()
      if (!u) break
      const ok = await checkWithRetry(u, mode)
      if (ok) results.push(u)
      processed += 1
      try { if (typeof onProgress === 'function') onProgress({ processed, healthy: results.length }) } catch (_) { /* ignore */ }
      if (results.length >= cap) { stopped = true; break }
    }
  }

  const n = Math.max(1, Math.min(VALIDATION_CONCURRENCY, queue.length))
  await Promise.all(Array.from({ length: n }, () => worker()))
  return results
}

function getHealthStats() {
  let ok = 0, bad = 0
  for (const [, v] of healthCache) {
    if (v.ok) ok++; else bad++
  }
  return {
    ok,
    bad,
    total: ok + bad,
    ttlMs: HEALTH_TTL_MS,
    sample: Array.from(healthCache.entries()).slice(0, 10).map(([k, v]) => ({ url: k, ok: v.ok, ts: v.ts, lastError: v.lastError || "" })),
  }
}

module.exports = {
  isTrackerUrl,
  unique,
  filterByHealth,
  getHealthStats,
  checkHealthyBasic,
  checkHealthyAggressive,
  healthCache,
}
