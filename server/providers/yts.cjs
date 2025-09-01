const axios = require('axios')

const NAME = 'YTS'
const BASE = 'https://yts.mx/api/v2'

async function probe(timeoutMs = 800) {
  try {
    const url = `${BASE}/list_movies.json?limit=1`
    const res = await axios.get(url, { timeout: timeoutMs })
    if (res && res.data && res.data.status === 'ok') return { ok: true }
  } catch (_) { /* ignore */ }
  return { ok: false }
}

function imdbFromId(type, id) {
  if (!id) return ''
  // Stremio movie ids are often imdb like 'tt1234567'
  const s = String(id)
  const m = s.match(/tt\d{7,8}/i)
  return m ? m[0].toLowerCase() : ''
}

async function fetchStreams(type, id, timeoutMs = 2500) {
  const imdb = imdbFromId(type, id)
  if (type !== 'movie' || !imdb) return { ok: true, provider: NAME, streams: [] }
  try {
    const url = `${BASE}/list_movies.json?limit=1&query_term=${encodeURIComponent(imdb)}`
    const res = await axios.get(url, { timeout: timeoutMs, validateStatus: () => true })
    const data = res && res.data && res.data.data ? res.data.data : null
    const movies = (data && Array.isArray(data.movies)) ? data.movies : []
    if (!movies.length) return { ok: true, provider: NAME, streams: [] }
    const movie = movies[0]
    const title = movie.title || NAME
    const torrents = Array.isArray(movie.torrents) ? movie.torrents : []
    const streams = torrents.map(t => ({
      provider: NAME,
      title: `${title} ${t.quality || ''} ${t.type || ''}`.trim(),
      infoHash: (t.hash || '').toLowerCase(),
      behaviorHints: {},
      // Extra fields for description enrichment
      seeds: typeof t.seeds === 'number' ? t.seeds : null,
      leechers: typeof t.peers === 'number' ? t.peers : null,
      size: t.size || null,
      sizeBytes: typeof t.size_bytes === 'number' ? t.size_bytes : null,
      languages: [],
      description: '',
    })).filter(s => s.infoHash)
    return { ok: true, provider: NAME, streams }
  } catch (e) {
    return { ok: false, error: e && e.message ? e.message : 'request_failed' }
  }
}

module.exports = { name: NAME, probe, fetchStreams }
