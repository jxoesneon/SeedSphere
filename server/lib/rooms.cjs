'use strict'

// Simple in-memory SSE rooms manager
// room_id -> Set(res)
const ROOMS = new Map()

function subscribe(room_id, res) {
  let set = ROOMS.get(room_id)
  if (!set) { set = new Set(); ROOMS.set(room_id, set) }
  set.add(res)
  const unsubscribe = () => {
    try { set.delete(res) } catch (_) {}
    if (set.size === 0) ROOMS.delete(room_id)
  }
  res.on('close', unsubscribe)
  res.on('finish', unsubscribe)
  res.on('error', unsubscribe)
  return unsubscribe
}

function publish(room_id, event, data) {
  const set = ROOMS.get(room_id)
  if (!set || set.size === 0) return 0
  const payload = JSON.stringify(data)
  let sent = 0
  for (const res of set) {
    try {
      if (event) res.write(`event: ${event}\n`)
      res.write(`data: ${payload}\n\n`)
      sent += 1
    } catch (_) { /* drop silently */ }
  }
  return sent
}

function count(room_id) {
  const set = ROOMS.get(room_id)
  return set ? set.size : 0
}

module.exports = { subscribe, publish, count }
