// Client-side rolling log helper
// Sends structured events to the server's /api/logs/emit endpoint.

export function emitLog(type, data = {}, options = {}) {
  try {
    const payload = {
      type: String(type || 'client_event'),
      component: String(options.component || 'client'),
      data: Object.assign({
        href: safe(() => window.location.href),
        userAgent: safe(() => navigator.userAgent),
      }, data || {}),
    }
    const body = JSON.stringify(payload)
    // Prefer sendBeacon for background safety
    if (typeof navigator !== 'undefined' && navigator.sendBeacon) {
      try {
        const blob = new Blob([body], { type: 'application/json' })
        const ok = navigator.sendBeacon('/api/logs/emit', blob)
        if (ok) return true
      } catch (_) { /* fall through */ }
    }
    // Fallback to fetch keepalive
    fetch('/api/logs/emit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      keepalive: true,
      body,
    }).catch(() => {})
    return true
  } catch (_) { return false }
}

function safe(fn) {
  try { return fn() } catch { return undefined }
}
