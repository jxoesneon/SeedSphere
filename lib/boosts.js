// Simple in-memory ring buffer for recent boost events
// Not persisted across restarts; designed for lightweight visibility in /configure UI

const MAX = 20
const items = []

function push(entry) {
  try {
    const now = new Date()
    const normalized = {
      time: now.toISOString(),
      mode: String(entry.mode || "").toLowerCase(),
      limit: Number.isFinite(entry.limit) ? entry.limit : 0,
      healthy: Number(entry.healthy || 0),
      total: Number(entry.total || 0),
      source: String(entry.source || ""),
    }
    items.unshift(normalized)
    if (items.length > MAX) items.pop()
  } catch (_) { /* ignore */ }
}

function recent() {
  return items.slice(0, MAX)
}

module.exports = { push, recent }
