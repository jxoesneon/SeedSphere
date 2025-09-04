// Simple in-memory ring buffer for recent boost events
// Not persisted across restarts; designed for lightweight visibility in /configure UI

const MAX = 20
const items = []
const listeners = new Set()

function push(entry) {
  try {
    const now = new Date()
    const normalized = {
      // timestamps
      time: now.toISOString(),
      ts: Date.now(),
      // core fields
      mode: String(entry.mode || "").toLowerCase(),
      limit: Number.isFinite(entry.limit) ? entry.limit : 0,
      healthy: Number(entry.healthy || 0),
      total: Number(entry.total || 0),
      source: String(entry.source || ""),
      type: String(entry.type || ""),
      id: String(entry.id || ""),
      // optional title for UI
      title: String(entry.title || ""),
      // optional series fields
      ...(Number.isFinite(Number(entry.season)) ? { season: Number(entry.season) } : {}),
      ...(Number.isFinite(Number(entry.episode)) ? { episode: Number(entry.episode) } : {}),
    }
    items.unshift(normalized)
    if (items.length > MAX) items.pop()
    for (const fn of listeners) {
      try { fn(normalized) } catch (_) { /* ignore */ }
    }
  } catch (_) { /* ignore */ }
}

function recent() {
  return items.slice(0, MAX)
}

function subscribe(fn) {
  if (typeof fn === 'function') listeners.add(fn)
  return () => listeners.delete(fn)
}

// Test-only helper for isolation
function __resetForTests() {
  try { items.length = 0 } catch (_) {}
  try { listeners.clear() } catch (_) {}
}

module.exports = { push, recent, subscribe, __resetForTests }
