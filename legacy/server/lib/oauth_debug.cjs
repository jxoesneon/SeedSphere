'use strict'

// Simple in-memory ring buffer for recent OAuth events.
// Not persisted; intended for local dev/debugging only.

const MAX_EVENTS = 50
const events = []

function addEvent(evt) {
  try {
    const safe = sanitize(evt)
    safe.ts = new Date().toISOString()
    events.push(safe)
    if (events.length > MAX_EVENTS) events.shift()
  } catch (_) {
    // ignore
  }
}

function getEvents() {
  return events.slice().reverse() // newest first
}

function sanitize(evt) {
  const e = Object.assign({}, evt || {})
  // Ensure we never leak secrets
  if (e.request && e.request.client_secret) e.request.client_secret = '[redacted]'
  if (e.token && e.token.id_token) e.token.id_token = '[redacted]'
  if (e.error && e.error.stack) e.error = String(e.error.stack).slice(0, 1000)
  return e
}

module.exports = { addEvent, getEvents }
