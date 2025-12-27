const axios = require('axios')

const NAME = 'Nyaa'
const BASE = 'https://nyaa.si'

async function probe(timeoutMs = 1000) {
  try {
    const res = await axios.get(BASE, { timeout: timeoutMs })
    if (res && res.status >= 200 && res.status < 400) return { ok: true }
  } catch (_) { /* ignore */ }
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

async function fetchStreams(type, id, timeoutMs = 4000) {
  // Works best for anime titles; fall back to empty if no title
  const info = await fetchTitle(type, id)
  if (!info || !info.title) return { ok: true, provider: NAME, streams: [] }
  try {
    const q = encodeURIComponent(`${info.title}`)
    const url = `${BASE}/?f=0&c=0_0&q=${q}`
    const res = await axios.get(url, { timeout: timeoutMs, validateStatus: () => true })
    const html = (res && res.data) ? String(res.data) : ''
    const magnets = parseMagnetsFromHtml(html).slice(0, 40)
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
