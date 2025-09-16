'use strict'

// Lightweight in-memory rolling log with SSE broadcasting
// Not persisted. Intended for local dev / diagnostics.

const MAX_EVENTS_DEFAULT = 2000
const events = [] // { ts, type, data }
let maxEvents = MAX_EVENTS_DEFAULT

// Simple subscriber set; each entry is an object { res, filters }
const subscribers = new Set()

function setMaxSize(n) {
  const v = Number(n)
  if (Number.isFinite(v) && v >= 100) {
    maxEvents = Math.min(100_000, Math.max(100, v))
    // Trim immediately if needed
    while (events.length > maxEvents) events.shift()
  }
}

function getRecent(limit = 200, filters = null) {
  const lim = Math.max(1, Math.min(5000, Number(limit) || 200))
  const src = filters ? events.filter((e) => matchesFilters(e, filters)) : events
  const start = Math.max(0, src.length - lim)
  return src.slice(start)
}

function matchesFilters(e, filters) {
  if (!filters || typeof filters !== 'object') return true
  try {
    // Supported filters: type, component, user_id, gardener_id, seedling_id
    const d = e && e.data ? e.data : {}
    if (filters.type && e.type !== filters.type) return false
    if (filters.component && String(d.component || '') !== String(filters.component)) return false
    if (filters.user_id && String(d.user_id || '') !== String(filters.user_id)) return false
    if (filters.gardener_id && String(d.gardener_id || '') !== String(filters.gardener_id)) return false
    if (filters.seedling_id && String(d.seedling_id || '') !== String(filters.seedling_id)) return false
    return true
  } catch (_) { return true }
}

function log(type, data) {
  const rec = { ts: Date.now(), type: String(type || 'event'), data: data || {} }
  events.push(rec)
  if (events.length > maxEvents) events.shift()
  // Broadcast to SSE subscribers
  for (const sub of subscribers) {
    try {
      if (matchesFilters(rec, sub.filters)) {
        sub.res.write(`event: log\n`)
        sub.res.write(`data: ${JSON.stringify(rec)}\n\n`)
      }
    } catch (_) { /* ignore broken pipe */ }
  }
  return rec
}

function subscribe(res, filters = null, snapshotLimit = 200) {
  const sub = { res, filters: filters || null }
  subscribers.add(sub)
  // Send a snapshot first
  try {
    const snap = getRecent(snapshotLimit, filters)
    res.write(`event: snapshot\n`)
    res.write(`data: ${JSON.stringify({ items: snap })}\n\n`)
  } catch (_) { /* ignore */ }
  // Heartbeat every 25s to keep connections alive
  const timer = setInterval(() => {
    try { res.write(`event: hb\n`); res.write(`data: {"t":${Date.now()}}\n\n`) } catch (_) { /* ignore */ }
  }, 25_000)
  const unsubscribe = () => {
    try { clearInterval(timer) } catch (_) {}
    subscribers.delete(sub)
  }
  res.on('close', unsubscribe)
  res.on('finish', unsubscribe)
  res.on('error', unsubscribe)
  return unsubscribe
}

module.exports = { log, getRecent, setMaxSize, subscribe }
