#!/usr/bin/env node
import os from 'node:os'
import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'

const BASE_URL = process.env.SEEDSPHERE_BASE_URL || 'http://127.0.0.1:8080'
const CONFIG_DIR = path.join(os.homedir(), '.seedsphere')
const CONFIG_PATH = path.join(CONFIG_DIR, 'gardener.json')

function log(...args) { console.log('[gardener]', ...args) }
function err(...args) { console.error('[gardener]', ...args) }

async function ensureDir(p) { try { await fs.mkdir(p, { recursive: true }) } catch (_) {} }

async function loadConfig() {
  try {
    const buf = await fs.readFile(CONFIG_PATH)
    return JSON.parse(String(buf))
  } catch (_) { return {} }
}
async function saveConfig(cfg) {
  await ensureDir(CONFIG_DIR)
  await fs.writeFile(CONFIG_PATH, JSON.stringify(cfg, null, 2))
}

async function httpJson(url, { method = 'GET', body = undefined, headers = {}, timeoutMs = 4000 } = {}) {
  const ctl = new AbortController()
  const t = setTimeout(() => ctl.abort(), timeoutMs)
  try {
    const res = await fetch(url, { method, headers, body, signal: ctl.signal })
    const txt = await res.text()
    let json = null
    try { json = JSON.parse(txt) } catch { json = null }
    return { ok: res.ok, status: res.status, json, text: txt }
  } finally { clearTimeout(t) }
}

async function cmdRegister() {
  const url = `${BASE_URL}/api/executor/register`
  const r = await httpJson(url, { method: 'POST' })
  if (!r.ok || !r.json || !r.json.ok) { err('register_failed', { status: r.status, body: r.text }); process.exit(1) }
  const device_id = r.json.device_id
  if (!device_id) { err('missing_device_id'); process.exit(1) }
  const cfg = await loadConfig()
  cfg.gardener_id = device_id
  cfg.base_url = BASE_URL
  cfg.registered_at = Date.now()
  await saveConfig(cfg)
  log('registered', { gardener_id: device_id })
}

async function cmdStatus() {
  const cfg = await loadConfig()
  const gardener_id = cfg.gardener_id
  if (!gardener_id) { err('not_registered'); process.exit(1) }
  const url = `${BASE_URL}/api/link/status?gardener_id=${encodeURIComponent(gardener_id)}`
  const r = await httpJson(url)
  if (!r.ok || !r.json) { err('status_failed', { status: r.status, body: r.text }); process.exit(1) }
  const linked = Array.isArray(r.json.linked_seedlings) ? r.json.linked_seedlings : []
  log('status', { gardener_id, linked_seedlings: linked })
}

// --- Resource-aware executor runtime ---
function sleep(ms) { return new Promise((r) => setTimeout(r, ms)) }

function getCpuLoadRatio() {
  try {
    const [l1] = os.loadavg()
    const cores = Math.max(1, os.cpus().length)
    const ratio = l1 / cores
    return Math.max(0, Math.min(2, ratio)) // cap at 2.0 for extreme loads
  } catch { return 0 }
}

function getMemoryPressure() {
  try {
    const total = os.totalmem()
    const free = os.freemem()
    const used = total - free
    const usedRatio = used / total // 0..1
    return Math.max(0, Math.min(1, usedRatio))
  } catch { return 0 }
}

function computeHealthScore({ maxCpuRatio = 0.85, maxMemRatio = 0.90 } = {}) {
  const cpu = getCpuLoadRatio() // ~1.0 means fully loaded
  const mem = getMemoryPressure() // 1.0 means all memory used
  // Map to penalty 0..1 beyond thresholds
  const cpuPenalty = Math.max(0, (cpu - maxCpuRatio) / (1.5 - maxCpuRatio)) // allow some spike headroom
  const memPenalty = Math.max(0, (mem - maxMemRatio) / (1 - maxMemRatio))
  const penalty = Math.max(cpuPenalty, memPenalty)
  const score = Math.max(0, Math.min(1, 1 - penalty))
  return { cpu, mem, score }
}

async function postHeartbeat({ baseUrl, gardener_id, queue = 0, success1m = 0, fail1m = 0, score }) {
  const url = `${baseUrl}/api/rooms/${encodeURIComponent(gardener_id)}/heartbeat`
  const body = JSON.stringify({ queue, success1m, fail1m, healthscore: Number.isFinite(score) ? score : undefined })
  try { await httpJson(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body, timeoutMs: 3000 }) } catch (_) {}
}

async function runExecutor() {
  // Adaptive throttling config (env overrides)
  let MAX_CPU_RATIO = Math.min(1, Math.max(0.2, Number(process.env.GARDENER_MAX_CPU_RATIO || 0.85)))
  let MAX_MEM_RATIO = Math.min(0.98, Math.max(0.5, Number(process.env.GARDENER_MAX_MEM_RATIO || 0.90)))
  let MIN_INTERVAL_MS = Math.max(200, Number(process.env.GARDENER_MIN_INTERVAL_MS || 500))
  let MAX_INTERVAL_MS = Math.max(MIN_INTERVAL_MS, Number(process.env.GARDENER_MAX_INTERVAL_MS || 8000))
  let HEARTBEAT_EVERY = Math.max(1, Number(process.env.GARDENER_HEARTBEAT_EVERY || 3)) // every N loops

  const cfg = await loadConfig()
  let gardener_id = cfg.gardener_id
  if (!gardener_id) {
    await cmdRegister()
    const cfg2 = await loadConfig(); gardener_id = cfg2.gardener_id
  }
  await cmdStatus().catch(() => {})

  let loop = 0
  let intervalMs = MIN_INTERVAL_MS
  let recentSuccess = 0
  let recentFail = 0
  log('executor:start', { gardener_id, base_url: BASE_URL, cpu_cap: MAX_CPU_RATIO, mem_cap: MAX_MEM_RATIO })

  async function applyServerPrefs() {
    try {
      const url = `${BASE_URL}/api/gardeners/${encodeURIComponent(gardener_id)}/prefs`
      const r = await httpJson(url, { timeoutMs: 3000 })
      const p = (r && r.ok && r.json && r.json.prefs) ? r.json.prefs : null
      if (p && typeof p === 'object') {
        if (typeof p.max_cpu_ratio === 'number') MAX_CPU_RATIO = Math.min(1, Math.max(0.2, p.max_cpu_ratio))
        if (typeof p.max_mem_ratio === 'number') MAX_MEM_RATIO = Math.min(0.98, Math.max(0.5, p.max_mem_ratio))
        if (typeof p.min_interval_ms === 'number') MIN_INTERVAL_MS = Math.max(200, Math.floor(p.min_interval_ms))
        if (typeof p.max_interval_ms === 'number') MAX_INTERVAL_MS = Math.max(MIN_INTERVAL_MS, Math.floor(p.max_interval_ms))
        if (typeof p.heartbeat_every === 'number') HEARTBEAT_EVERY = Math.max(1, Math.floor(p.heartbeat_every))
      }
    } catch (_) {}
  }
  await applyServerPrefs()
  let lastPrefsAt = Date.now()
  while (true) {
    try {
      // 1) Measure current pressure and compute health
      const { cpu, mem, score } = computeHealthScore({ maxCpuRatio: MAX_CPU_RATIO, maxMemRatio: MAX_MEM_RATIO })
      // 2) Adapt interval based on worst pressure
      const pressure = Math.max(cpu, mem)
      const t = MIN_INTERVAL_MS + (MAX_INTERVAL_MS - MIN_INTERVAL_MS) * Math.max(0, Math.min(1, (pressure - 0.5) / 0.5))
      intervalMs = Math.max(MIN_INTERVAL_MS, Math.min(MAX_INTERVAL_MS, Math.round(t)))

      // 3) Perform lightweight work placeholder (future: actual queue processing)
      // Simulate success/fail counters decaying
      recentSuccess = Math.max(0, Math.floor(recentSuccess * 0.9))
      recentFail = Math.max(0, Math.floor(recentFail * 0.9))

      // 4) Heartbeat periodically with queue and healthscore
      if ((loop % HEARTBEAT_EVERY) === 0) {
        await postHeartbeat({ baseUrl: BASE_URL, gardener_id, queue: 0, success1m: recentSuccess, fail1m: recentFail, score })
      }

      // 5) Sleep adaptively to throttle load
      await sleep(intervalMs)
      // 6) Periodically refresh preferences (every ~60s)
      if (Date.now() - lastPrefsAt > 60_000) { await applyServerPrefs(); lastPrefsAt = Date.now() }
      loop += 1
    } catch (e) {
      recentFail += 1
      await sleep(Math.min(MAX_INTERVAL_MS, intervalMs * 2))
    }
  }
}

async function cmdLinkStart() {
  const cfg = await loadConfig()
  const gardener_id = cfg.gardener_id
  if (!gardener_id) { err('not_registered'); process.exit(1) }
  const url = `${BASE_URL}/api/link/start`
  const body = JSON.stringify({ gardener_id, platform: process.platform })
  const r = await httpJson(url, { method: 'POST', body, headers: { 'Content-Type': 'application/json' } })
  if (!r.ok || !r.json || !r.json.ok) { err('link_start_failed', { status: r.status, body: r.text }); process.exit(1) }
  const token = r.json.token
  const expires_at = r.json.expires_at
  log('link_token', { token, expires_at })
  console.log('\nTo complete linking, go to the SeedSphere website, sign in, and bind your seedling using this token.')
}

async function main() {
  const [,, sub, ...rest] = process.argv
  switch ((sub || 'help').toLowerCase()) {
    case 'register':
      await cmdRegister(); break
    case 'status':
      await cmdStatus(); break
    case 'link-start':
    case 'link':
      await cmdLinkStart(); break
    case 'start':
      await runExecutor(); break
    default:
      console.log('SeedSphere Gardener Executor CLI')
      console.log('Usage:')
      console.log('  gardener register            Register this device with the backend')
      console.log('  gardener status              Show linked seedlings for this device')
      console.log('  gardener link-start          Create a short-lived link token')
      console.log('  gardener start               Register and show status (placeholder)')
      process.exit(1)
  }
}

main().catch((e) => { err('fatal', e?.message || String(e)); process.exit(1) })
