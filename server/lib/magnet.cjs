const { URLSearchParams } = require('node:url')

function sanitizeQuery(qs) {
  // Fix common HTML-escaped ampersands and mixed encodings
  // - "&amp;" -> "&"
  // - "&amp%3B" (seen in some upstreams) -> "&"
  // Also collapse any accidental double ampersands
  return String(qs || '')
    .replace(/&amp;|&amp%3B/gi, '&')
    .replace(/&&+/g, '&')
}

function normalizeMagnet(magnet) {
  try {
    const s = String(magnet || '')
    if (!s.startsWith('magnet:?')) return ''
    // Drop tracker params to dedupe on base
    const q = sanitizeQuery(s.slice(8))
    const parts = q.split('&').filter(kv => kv && !kv.startsWith('tr='))
    return 'magnet:?' + parts.join('&')
  } catch (_) { return '' }
}

function appendTrackers(magnet, trackers) {
  try {
    const base = String(magnet || '')
    if (!base.startsWith('magnet:?')) return base
    const params = new URLSearchParams(sanitizeQuery(base.slice(8)))
    // Append trackers preserving order; avoid duplicates
    const seen = new Set()
    // include existing tr values to avoid duplication
    for (const [k, v] of params.entries()) if (k === 'tr') seen.add(v)
    for (const t of (Array.isArray(trackers) ? trackers : [])) {
      const v = String(t || '')
      if (!v) continue
      if (seen.has(v)) continue
      params.append('tr', v)
      seen.add(v)
    }
    return 'magnet:?' + params.toString()
  } catch (_) { return magnet }
}

function buildMagnet(infoHash, name, trackers) {
  try {
    const params = new URLSearchParams()
    params.set('xt', `urn:btih:${String(infoHash || '').trim()}`)
    if (name) params.set('dn', String(name))
    const set = new Set()
    for (const t of (Array.isArray(trackers) ? trackers : [])) {
      const v = String(t || '')
      if (!v || set.has(v)) continue
      params.append('tr', v)
      set.add(v)
    }
    return 'magnet:?' + params.toString()
  } catch (_) { return '' }
}

module.exports = { normalizeMagnet, appendTrackers, buildMagnet }
