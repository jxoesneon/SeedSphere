const axios = require('axios')

const NAME = '1337x'
// Prefer multiple mirrors; sites often rotate or rate limit
const MIRRORS = [
  'https://www.1377x.to',
  'https://www.1337x.to',
  'https://1337x.to',
]
const DEFAULT_BASE = MIRRORS[0]

function makeHeaders() {
  return {
    // Use a common browser UA to avoid simplistic blocks
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  }
}

async function probe(timeoutMs = 2000) {
  for (const base of MIRRORS) {
    try {
      const res = await axios.get(base + '/', {
        timeout: timeoutMs,
        maxRedirects: 2,
        validateStatus: () => true,
        headers: makeHeaders(),
      })
      // Consider 2xx/3xx reachable; many mirrors front with CF and return 403, and some serve 404 for '/home' — both indicate reachability
      if (res && ((res.status >= 200 && res.status < 400) || res.status === 403 || res.status === 404)) return { ok: true }
    } catch (_) { /* try next mirror */ }
  }
  return { ok: false }
}

async function fetchTitle(type, id, timeoutMs = 2000) {
  try {
    const url = `https://v3-cinemeta.strem.io/meta/${encodeURIComponent(type)}/${encodeURIComponent(id)}.json`
    const res = await axios.get(url, { timeout: timeoutMs, validateStatus: () => true })
    const meta = res && res.data && res.data.meta ? res.data.meta : null
    if (!meta) return null
    const title = meta.name || meta.title || ''
    const year = meta.year || ''
    return { title, year }
  } catch (_) { return null }
}

function parseMagnetsFromHtml(html) {
  const magnets = []
  const re = /href=("|')(magnet:\?xt=[^"']+)(\1)/gi
  let m
  while ((m = re.exec(html))) {
    const u = m[2]
    if (u && u.startsWith('magnet:?')) magnets.push(u)
  }
  return Array.from(new Set(magnets))
}

async function fetchStreams(type, id, timeoutMs = 5000) {
  const info = await fetchTitle(type, id)
  if (!info || !info.title) return { ok: true, provider: NAME, streams: [] }
  try {
    const q = encodeURIComponent(`${info.title}`)
    const url = `${DEFAULT_BASE}/search/${q}/1/` // page 1 (best-effort default mirror)
    const res = await axios.get(url, { timeout: timeoutMs, validateStatus: () => true, headers: makeHeaders() })
    const html = (res && res.data) ? String(res.data) : ''
    // We need to follow result pages to get magnets; attempt to extract some detail links and fetch them in parallel (limited)
    const detailLinks = Array.from(new Set(Array.from(html.matchAll(/href="(\/torrent\/[^\"]+)"/gi)).map(m => m[1]))).slice(0, 5)
    const pages = await Promise.all(detailLinks.map(async (p) => {
      try {
        const r = await axios.get(`${DEFAULT_BASE}${p}`, { timeout: 4000, validateStatus: () => true, headers: makeHeaders() })
        return String(r && r.data ? r.data : '')
      } catch (_) { return '' }
    }))
    const magnets = pages.flatMap(parseMagnetsFromHtml).slice(0, 30)
    const streams = magnets.map((u) => ({
      provider: NAME,
      title: `${info.title}`,
      url: u,
      behaviorHints: {},
      description: '',
      seeds: null,
      leechers: null,
      size: null,
      sizeBytes: null,
      languages: [],
    }))
    return { ok: true, provider: NAME, streams }
  } catch (e) {
    return { ok: false, error: e && e.message ? e.message : 'request_failed' }
  }
}

module.exports = { name: NAME, probe, fetchStreams }
