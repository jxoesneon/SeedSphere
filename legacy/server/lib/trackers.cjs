const axios = require('axios')
const { isTrackerUrl, unique } = require('./health.cjs')
const { setLastFetch } = require('./trackers_meta.cjs')

const VARIANT_URLS = {
  all: 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt',
  best: 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt',
  all_udp: 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_udp.txt',
  all_http: 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_http.txt',
  all_ws: 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ws.txt',
  all_ip: 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt',
  best_ip: 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt',
}

const DEFAULT_TRACKERS_URL = process.env.TRACKERS_URL || VARIANT_URLS[(process.env.TRACKERS_VARIANT || 'all').toLowerCase()] || VARIANT_URLS.all
const CACHE_MS = 24 * 60 * 60 * 1000
const inFlightByUrl = new Map() // url -> Promise<string[]>
const trackersCacheByUrl = new Map() // url -> { list, ts, ttl }

const VARIANT_TTLS = {
  all: 12 * 60 * 60 * 1000,
  best: 6 * 60 * 60 * 1000,
  all_udp: 12 * 60 * 60 * 1000,
  all_http: 12 * 60 * 60 * 1000,
  all_ws: 12 * 60 * 60 * 1000,
  all_ip: 24 * 60 * 60 * 1000,
  best_ip: 12 * 60 * 60 * 1000,
}

function findVariantForUrl(url) {
  for (const [k, v] of Object.entries(VARIANT_URLS)) if (v === url) return k
  return null
}

async function fetchTrackers(url) {
  const now = Date.now()
  const entry = trackersCacheByUrl.get(url)
  if (entry && now - entry.ts < (entry.ttl || CACHE_MS)) return entry.list
  if (inFlightByUrl.has(url)) return inFlightByUrl.get(url)
  const ttl = VARIANT_TTLS[findVariantForUrl(url) || 'all'] || CACHE_MS
  const task = (async () => {
    const res = await axios.get(url, { timeout: 10000 })
    const list = String(res.data)
      .split('\n')
      .map((t) => t.trim())
      .filter((t) => t && !t.startsWith('#') && isTrackerUrl(t))
    const deduped = unique(list)
    trackersCacheByUrl.set(url, { list: deduped, ts: now, ttl })
    try { setLastFetch(Date.now()) } catch (_) {}
    return deduped
  })()
  inFlightByUrl.set(url, task)
  try { return await task } finally { inFlightByUrl.delete(url) }
}

module.exports = { fetchTrackers, VARIANT_URLS, DEFAULT_TRACKERS_URL }
