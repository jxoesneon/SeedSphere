const { normalizeMagnet, appendTrackers, buildMagnet } = require('./magnet.cjs')
const { parseReleaseInfo } = require('./parse.cjs')
const { enhanceDescription } = require('./ai_descriptions.cjs')

// Simple in-memory cache: key -> { ts, ttl, streams }
const CACHE = new Map()
const DEFAULT_TTL_MS = 90 * 1000

function getCache(key) {
  const e = CACHE.get(key)
  if (!e) return null
  if (Date.now() - e.ts > (e.ttl || DEFAULT_TTL_MS)) { CACHE.delete(key); return null }
  return e.streams
}

function setCache(key, streams, ttl = DEFAULT_TTL_MS) {
  CACHE.set(key, { ts: Date.now(), ttl, streams })
}

function dedupeStreams(items) {
  const out = []
  const seenHash = new Set()
  const seenMagnet = new Set()
  for (const s of items) {
    const ih = (s.infoHash || '').toLowerCase()
    const url = String(s.url || '')
    if (ih) {
      if (seenHash.has(ih)) continue
      seenHash.add(ih)
      out.push(s)
      continue
    }
    if (url.startsWith('magnet:?')) {
      const key = normalizeMagnet(url)
      if (!key) continue
      if (seenMagnet.has(key)) continue
      seenMagnet.add(key)
      out.push(s)
      continue
    }
    // Unknown type, include once
    out.push(s)
  }
  return out
}

function formatBytes(bytes) {
  const n = Number(bytes)
  if (!Number.isFinite(n) || n <= 0) return null
  const units = ['B','KB','MB','GB','TB']
  let b = n, i = 0
  while (b >= 1024 && i < units.length - 1) { b /= 1024; i++ }
  return `${b.toFixed(b >= 10 ? 0 : 1)} ${units[i]}`
}

function buildDescriptionMultiline(magnetUrl, fallbackTitle, providerName, trackersAdded, upstream, opts) {
  const info = parseReleaseInfo(magnetUrl, fallbackTitle)
  const lines = []
  // First line: optimization + provider
  if (trackersAdded > 0) lines.push(`⚡ SeedSphere +${trackersAdded} trackers`)
  else lines.push(`⚡ SeedSphere optimized`)
  if (providerName) lines.push(`📦 Provider: ${providerName}`)

  // Second block: technicals
  const tech = []
  if (info.source) tech.push(info.source)
  if (info.codec) tech.push(info.codec)
  if (info.hdr) tech.push(info.hdr)
  if (info.audio) tech.push(info.audio)
  if (tech.length) lines.push(`⚙️ ${tech.join(' • ')}`)

  if (info.resolution) lines.push(`🖥️ Resolution: ${info.resolution}`)
  if (info.group) lines.push(`🏷️ Group: ${info.group}`)

  // Peers (best-effort): seeds/leechers/peers
  const seeds = upstream && (upstream.seeds || upstream.seeders || upstream.peers || upstream.seed || null)
  const leech = upstream && (upstream.leechers || upstream.leech || null)
  if (Number.isFinite(Number(seeds)) || Number.isFinite(Number(leech))) {
    const parts = []
    if (Number.isFinite(Number(seeds))) parts.push(`Seeds: ${Number(seeds)}`)
    if (Number.isFinite(Number(leech))) parts.push(`Peers: ${Number(leech)}`)
    if (parts.length) lines.push(`🌱 ${parts.join(' • ')}`)
  }

  // Size
  const sizePref = upstream && (upstream.sizeStr || upstream.size || null)
  const sizeAuto = info.sizeStr || (formatBytes(upstream && upstream.sizeBytes) || null)
  const sizeDisplay = sizePref || sizeAuto
  if (sizeDisplay) lines.push(`🗜️ Size: ${sizeDisplay}`)

  // Languages
  const langs = (Array.isArray(upstream && upstream.languages) ? upstream.languages : []).concat(Array.isArray(info.languages) ? info.languages : [])
  const uniqueLangs = Array.from(new Set(langs)).filter(Boolean)
  if (uniqueLangs.length) lines.push(`🈶 Languages: ${uniqueLangs.join(', ')}`)

  // Final line: benefit
  lines.push('🌐 Faster peer discovery and startup time')
  const enhanced = lines.join('\n')

  // Determine if details are meaningful
  const detailCount = tech.length + (info.resolution ? 1 : 0) + (info.group ? 1 : 0) + (uniqueLangs.length ? 1 : 0) + (sizeDisplay ? 1 : 0) + ((Number(seeds) || Number(leech)) ? 1 : 0)
  const original = (upstream && upstream.description) ? String(upstream.description) : ''

  if (!detailCount && opts && opts.descRequireDetails) {
    // fallback entirely to original (if any)
    return original || ''
  }

  if (opts && opts.descAppendOriginal && original) {
    return enhanced + (enhanced ? '\n\n' : '') + `— Original —\n` + original
  }
  return enhanced
}

async function filterAvailableProviders(providers, timeoutMs = 800) {
  const tests = await Promise.allSettled(providers.map(async (p) => {
    try {
      if (typeof p.probe === 'function') {
        const r = await p.probe(timeoutMs)
        return r && r.ok ? p : null
      }
      return p
    } catch (_) { return null }
  }))
  return tests.map(t => (t.status === 'fulfilled' ? t.value : null)).filter(Boolean)
}

async function aggregateStreams({ type, id, providers, trackers, bingeGroup = 'seedsphere-optimized', cacheTtlMs = DEFAULT_TTL_MS, labelName = '! SeedSphere', descAppendOriginal = false, descRequireDetails = true, aiConfig = { enabled: false } }) {
  const key = `agg:${providers.map(p => p.name || 'N').join(',')}:${type}:${id}`
  const cached = getCache(key)
  if (cached) return cached

  const available = await filterAvailableProviders(providers)
  const results = await Promise.allSettled(available.map(p => p.fetchStreams(type, id)))
  const collected = []
  for (const r of results) {
    if (r.status !== 'fulfilled') continue
    const res = r.value
    if (!res || !res.ok || !Array.isArray(res.streams)) continue
    for (const s of res.streams) {
      collected.push({ ...s, provider: res.provider || s.provider || 'Upstream' })
    }
  }
  if (collected.length === 0) return []

  const merged = dedupeStreams(collected)
  const trackersList = Array.isArray(trackers) ? trackers : []

  const final = []
  for (const s of merged) {
    let magnet = ''
    if (s.url && String(s.url).startsWith('magnet:?')) {
      const before = s.url
      magnet = appendTrackers(before, trackersList)
    } else if (s.infoHash) {
      magnet = buildMagnet(s.infoHash, s.title || s.name, trackersList)
    } else {
      // Not a torrent stream; skip
      continue
    }
    const trAdded = trackersList.length
    // Build enhanced description
    let description = buildDescriptionMultiline(magnet, s.title || s.name, s.provider, trAdded, s, { descAppendOriginal, descRequireDetails })
    // Optionally enhance via AI
    let aiUsed = false
    if (aiConfig && aiConfig.enabled) {
      try {
        const info = parseReleaseInfo(magnet, s.title || s.name)
        const aiResult = await enhanceDescription({ baseDescription: description, title: s.title || s.name, releaseInfo: info, providerName: s.provider, trackersAdded: trAdded, magnet, meta: { type, id }, aiConfig })
        if (aiResult) { description = String(aiResult); aiUsed = true }
      } catch (_) { /* ignore AI errors */ }
    }
    // Append badge to distinguish AI-enhanced descriptions
    if (aiUsed) {
      description = (description ? description + '\n\n' : '') + '🧠 AI enhanced'
    }
    final.push({
      name: labelName || '! SeedSphere',
      // Keep the original upstream title for Stremio UI
      title: s.title || s.name,
      // Move extra details into a rich, multiline description
      description,
      url: magnet,
      behaviorHints: {
        ...(s.behaviorHints || {}),
        bingeGroup,
      },
    })
  }
  setCache(key, final, cacheTtlMs)
  return final
}

module.exports = { aggregateStreams, filterAvailableProviders }
