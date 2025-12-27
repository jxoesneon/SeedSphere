const axios = require('axios')

const NAME = 'EZTV'
const BASE = 'https://eztv.re/api'

async function probe(timeoutMs = 800) {
  try {
    const url = `${BASE}/get-torrents?limit=1`
    const res = await axios.get(url, { timeout: timeoutMs })
    if (res && res.data) return { ok: true }
  } catch (_) { /* ignore */ }
  return { ok: false }
}

function imdbFromId(type, id) {
  if (!id) return ''
  const s = String(id)
  const m = s.match(/tt\d{7,8}/i)
  return m ? m[0].toLowerCase() : ''
}

async function fetchStreams(type, id, timeoutMs = 3000) {
  const imdb = imdbFromId(type, id)
  // EZTV focuses on TV series; if not series or no imdb, return empty
  if (type !== 'series' || !imdb) return { ok: true, provider: NAME, streams: [] }
  try {
    const url = `${BASE}/get-torrents?imdb_id=${encodeURIComponent(imdb)}&limit=100`
    const res = await axios.get(url, { timeout: timeoutMs, validateStatus: () => true })
    const data = res && res.data ? res.data : null
    const torrents = Array.isArray(data && data.torrents) ? data.torrents : []
    const streams = torrents.map(t => ({
      provider: NAME,
      title: `${t.title || NAME}`.trim(),
      url: t.magnet_url || '',
      behaviorHints: {},
      // Extra fields
      seeds: typeof t.seeds === 'number' ? t.seeds : null,
      leechers: typeof t.peers === 'number' ? t.peers : null,
      size: t.size || null,
      sizeBytes: typeof t.size_bytes === 'number' ? t.size_bytes : null,
      languages: [],
      description: '',
    })).filter(s => s.url && s.url.startsWith('magnet:?'))
    return { ok: true, provider: NAME, streams }
  } catch (e) {
    return { ok: false, error: e && e.message ? e.message : 'request_failed' }
  }
}

module.exports = { name: NAME, probe, fetchStreams }
