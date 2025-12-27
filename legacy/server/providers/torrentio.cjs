const axios = require('axios')

const NAME = 'Torrentio'
// Public endpoints commonly used (fallback list)
const BASES = [
  'https://torrentio.strem.fun',
  'https://torrentio.devkds.workers.dev',
]

async function probe(timeoutMs = 800) {
  for (const base of BASES) {
    try {
      const url = base + '/manifest.json'
      const res = await axios.get(url, { timeout: timeoutMs })
      if (res && res.data) return { ok: true, base }
    } catch (_) { /* try next */ }
  }
  return { ok: false }
}

function pickBase() { return BASES[Math.floor(Math.random() * BASES.length)] }

async function fetchStreams(type, id, timeoutMs = 1800) {
  const base = pickBase()
  const url = `${base}/stream/${encodeURIComponent(type)}/${encodeURIComponent(id)}.json`
  try {
    const res = await axios.get(url, { timeout: timeoutMs, validateStatus: () => true })
    const data = res && res.data ? res.data : null
    const arr = Array.isArray(data && data.streams) ? data.streams : []
    // Normalize basic fields
    const streams = arr.map(s => ({
      provider: NAME,
      title: String(s.title || s.name || NAME),
      url: s.url || '',
      infoHash: s.infoHash || '',
      behaviorHints: s.behaviorHints || {},
      // Extra fields for enhanced descriptions (best-effort)
      description: s.description || s.overview || '',
      seeds: s.seeds ?? s.seeders ?? null,
      leechers: s.peers ?? s.leechers ?? null,
      size: s.sizeStr || s.size || null,
      sizeBytes: typeof s.sizeBytes === 'number' ? s.sizeBytes : null,
      languages: Array.isArray(s.languages) ? s.languages : (typeof s.language === 'string' ? [s.language] : []),
    }))
    return { ok: true, provider: NAME, streams }
  } catch (e) {
    return { ok: false, error: e && e.message ? e.message : 'request_failed' }
  }
}

module.exports = { name: NAME, probe, fetchStreams }
