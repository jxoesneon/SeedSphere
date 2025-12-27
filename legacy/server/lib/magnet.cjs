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

// Serialize a decoded magnet parameter object while keeping xt raw (colon-preserved)
function serializeMagnetParams(params) {
  const parts = []
  const xt = params.get('xt') || params.xt
  if (xt) parts.push(`xt=${String(xt)}`) // keep as-is without encoding ':'
  const dn = params.get ? params.get('dn') : params.dn
  if (dn) parts.push(`dn=${encodeURIComponent(String(dn))}`)
  // multiple tr supported; gather all
  const trValues = []
  if (params.getAll) trValues.push(...params.getAll('tr'))
  else if (Array.isArray(params.tr)) trValues.push(...params.tr)
  for (const tr of trValues) {
    if (!tr) continue
    parts.push(`tr=${encodeURIComponent(String(tr))}`)
  }
  // include any other params conservatively URL-encoded
  if (params.forEach) {
    params.forEach((v, k) => {
      if (k === 'xt' || k === 'dn' || k === 'tr') return
      parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
    })
  } else {
    for (const [k, v] of Object.entries(params)) {
      if (k === 'xt' || k === 'dn' || k === 'tr') continue
      parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
    }
  }
  return 'magnet:?' + parts.join('&')
}

function appendTrackers(magnet, trackers) {
  try {
    const base = String(magnet || '')
    if (!base.startsWith('magnet:?')) return base
    const params = new URLSearchParams(sanitizeQuery(base.slice(8)))
    // Ensure xt is preserved in decoded form
    const xt = params.get('xt')
    // Track existing trackers to avoid duplicates
    const seen = new Set(params.getAll('tr').map(String))
    for (const t of (Array.isArray(trackers) ? trackers : [])) {
      const v = String(t || '')
      if (!v || seen.has(v)) continue
      params.append('tr', v)
      seen.add(v)
    }
    // Reconstruct while keeping xt raw (with colons)
    const bag = new URLSearchParams()
    if (xt) bag.set('xt', xt)
    const dn = params.get('dn')
    if (dn) bag.set('dn', dn)
    for (const tr of params.getAll('tr')) bag.append('tr', tr)
    return serializeMagnetParams(bag)
  } catch (_) { return magnet }
}

function buildMagnet(infoHash, name, trackers) {
  try {
    const hash = String(infoHash || '').trim()
    if (!hash) return ''
    const bag = new URLSearchParams()
    bag.set('xt', `urn:btih:${hash}`) // do not encode ':'
    if (name) bag.set('dn', String(name))
    const set = new Set()
    for (const t of (Array.isArray(trackers) ? trackers : [])) {
      const v = String(t || '')
      if (!v || set.has(v)) continue
      set.add(v)
      bag.append('tr', v)
    }
    return serializeMagnetParams(bag)
  } catch (_) { return '' }
}

module.exports = { normalizeMagnet, appendTrackers, buildMagnet }
