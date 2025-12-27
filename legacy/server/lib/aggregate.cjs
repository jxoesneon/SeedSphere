const { normalizeMagnet, appendTrackers, buildMagnet } = require('./magnet.cjs')
const { parseReleaseInfo } = require('./parse.cjs')
const { enhanceDescription } = require('./ai_descriptions.cjs')
const { scrapeSwarm } = require('./swarm.cjs')
const boosts = require('./boosts.cjs')

// Simple in-memory cache: key -> { ts, ttl, streams }
const CACHE = new Map()
const DEFAULT_TTL_MS = 90 * 1000
const STALE_TTL_MS = 10 * 60 * 1000 // allow serving stale results up to 10 minutes

function getCache(key, allowStale = false) {
  const e = CACHE.get(key)
  if (!e) return null
  const age = Date.now() - e.ts
  const ttl = e.ttl || DEFAULT_TTL_MS
  if (age <= ttl) return e.streams // fresh
  if (allowStale && age <= ttl + STALE_TTL_MS) return e.streams // stale acceptable
  // too old
  CACHE.delete(key)
  return null
}

function parseSeriesId(rawId) {
  const parts = String(rawId || '').split(':')
  if (parts.length >= 3) {
    const season = parseInt(parts[1], 10)
    const episode = parseInt(parts[2], 10)
    if (Number.isFinite(season) && Number.isFinite(episode)) {
      return { season, episode }
    }
  }
  return null
}

function extractSeasonEpisode(rawTitle) {
  const norm = String(rawTitle || '').replace(/[._]+/g, ' ')
  const m = norm.match(/\bS(\d{1,2})E(\d{1,2})\b/i)
  if (m) {
    const season = parseInt(m[1], 10)
    const episode = parseInt(m[2], 10)
    if (Number.isFinite(season) && Number.isFinite(episode)) return { season, episode }
  }
  return null
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

// Build a human-friendly series title according to spec guidance:
// "<Show Title> SxxEyy — <Episode Title>"
// Falls back to a cleaned version of the raw title if parsing fails.
function buildSeriesDisplayTitle(rawTitle) {
  const raw = String(rawTitle || '')
  if (!raw) return ''
  // Normalize separators
  const norm = raw.replace(/[._]+/g, ' ').replace(/\s+/g, ' ').trim()
  const m = norm.match(/\bS(\d{1,2})E(\d{1,2})\b/i)
  if (!m) return norm
  const s = m[1].padStart(2, '0')
  const e = m[2].padStart(2, '0')
  const pre = norm.slice(0, m.index).trim()
  let post = norm.slice(m.index + m[0].length).trim()
  // Trim leading separators from post
  post = post.replace(/^[\s:\-–—]+/, '').trim()
  // Cut off known technical tokens from episode tail
  const cutIdx = post.search(/\b(2160p|1080p|720p|480p|4K|UHD|WEB[- ]?DL|WEB[- ]?Rip|BluRay|BDRip|HDRip|DVDRip|DDP(?:\.\d+)?|E-?AC-?3|AC3|DTS(?:-HD)?(?: MA)?|TrueHD|HEVC|x265|H\.265|x264|H\.264|HDR10\+?|Dolby[ \-.]?Vision|DV|ENG|ENGLISH|ITA|ITALIAN|MULTI|SUBS?|VOSTFR|LATINO|CASTELLANO)\b/i)
  if (cutIdx > 0) post = post.slice(0, cutIdx).trim()
  // Avoid extremely long episode titles
  if (post.length > 120) post = post.slice(0, 120).trim()
  return `${pre} S${s}E${e}${post ? ' — ' + post : ''}`.replace(/\s+/g, ' ').trim()
}

function buildDescriptionMultiline(magnetUrl, fallbackTitle, providerName, trackersAdded, upstream, opts) {
  const info = parseReleaseInfo(magnetUrl, fallbackTitle)
  const lines = []
  // First line: optimization + provider
  if (trackersAdded > 0) lines.push(`⚡ SeedSphere +${trackersAdded} trackers`)
  else lines.push(`⚡ SeedSphere optimized`)
  if (providerName) lines.push(`📦 Provider: ${providerName}`)

  // Series: add Season/Episode lines when available
  try {
    const metaType = opts && opts.meta && String(opts.meta.type || '').toLowerCase()
    const metaId = opts && opts.meta && String(opts.meta.id || '')
    if (metaType === 'series') {
      const seFromId = parseSeriesId(metaId)
      const seFromTitle = seFromId ? null : extractSeasonEpisode(fallbackTitle)
      const se = seFromId || seFromTitle
      if (se && Number.isFinite(se.season)) lines.push(`📅 Season: ${se.season}`)
      if (se && Number.isFinite(se.episode)) lines.push(`🎬 Episode: ${se.episode}`)
    }
  } catch (_) { /* ignore */ }

  // Second block: technicals (each field on its own line)
  if (info.source) lines.push(`🧩 Source: ${info.source}`)
  if (info.codec) lines.push(`🎞️ Codec: ${info.codec}`)
  if (info.hdr) lines.push(`🌈 HDR: ${info.hdr}`)
  if (info.audio) lines.push(`🔊 Audio: ${info.audio}`)

  if (info.resolution) lines.push(`🖥️ Resolution: ${info.resolution}`)
  if (info.group) lines.push(`🏷️ Group: ${info.group}`)

  // Peers (best-effort): seeds/leechers/peers
  const seeds = upstream && (upstream.seeds || upstream.seeders || upstream.peers || upstream.seed || null)
  const leech = upstream && (upstream.leechers || upstream.leech || null)
  if (Number.isFinite(Number(seeds))) lines.push(`🌱 Seeds: ${Number(seeds)}`)
  if (Number.isFinite(Number(leech))) lines.push(`👥 Peers: ${Number(leech)}`)

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
  const detailCount =
    (info.source ? 1 : 0) +
    (info.codec ? 1 : 0) +
    (info.hdr ? 1 : 0) +
    (info.audio ? 1 : 0) +
    (info.resolution ? 1 : 0) +
    (info.group ? 1 : 0) +
    (uniqueLangs.length ? 1 : 0) +
    (sizeDisplay ? 1 : 0) +
    ((Number(seeds) ? 1 : 0) + (Number(leech) ? 1 : 0))
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

async function aggregateStreams({ type, id, providers, trackers, trackersTotal = null, mode = 'basic', maxTrackers = 0, bingeGroup = 'seedsphere-optimized', cacheTtlMs = DEFAULT_TTL_MS, labelName = 'SeedSphere', descAppendOriginal = false, descRequireDetails = true, aiConfig = { enabled: false }, probeProviders = 'off', probeTimeoutMs = 500, providerFetchTimeoutMs = 3000, swarm = { enabled: false, topN: 2, timeoutMs: 800, missingOnly: true }, sort = { order: 'desc', fields: ['resolution','peers','language'] } }) {
  // Normalize sort config
  const sortOrder = (sort && String(sort.order || 'desc').toLowerCase() === 'asc') ? 'asc' : 'desc'
  const sortFields = Array.isArray(sort && sort.fields) && (sort.fields.length > 0)
    ? sort.fields.map((s) => String(s || '').toLowerCase())
    : ['resolution','peers','language']

  const key = `agg:${providers.map(p => p.name || 'N').join(',')}:${type}:${id}:sort:${sortOrder}:${sortFields.join(',')}`
  const cached = getCache(key, true)
  if (cached) return cached

  const doProbe = (String(probeProviders || 'off').toLowerCase() === 'on') || (probeProviders === true)
  const available = doProbe ? await filterAvailableProviders(providers, probeTimeoutMs) : providers
  const results = await Promise.allSettled(available.map((p) => {
    try { return p.fetchStreams(type, id, providerFetchTimeoutMs) }
    catch (_) { return Promise.resolve({ ok: false, streams: [] }) }
  }))
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
  const trackersAll = Array.isArray(trackers) ? trackers : []
  // Use all trackers by default; allow optional cap via maxTrackers > 0
  const cap = (Number.isFinite(maxTrackers) && maxTrackers > 0) ? Math.floor(maxTrackers) : trackersAll.length
  const trackersList = cap > 0 ? trackersAll.slice(0, cap) : trackersAll

  const items = []
  const swarmCfg = swarm || {}
  const swarmEnabled = !!swarmCfg.enabled
  const swarmTopN = Number.isFinite(swarmCfg.topN) ? Math.max(0, swarmCfg.topN) : 0
  const swarmTimeout = Number(swarmCfg.timeoutMs) || 800
  const swarmMissingOnly = ('missingOnly' in swarmCfg) ? !!swarmCfg.missingOnly : true

  for (let idx = 0; idx < merged.length; idx++) {
    const s = merged[idx]
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
    // Determine infoHash for robustness (some players prefer it)
    let infoHash = ''
    if (s.infoHash) infoHash = String(s.infoHash).toLowerCase()
    else if (magnet) {
      const m = magnet.match(/xt=urn:btih:([a-fA-F0-9]{40}|[a-zA-Z0-9]{32})/)
      if (m && m[1]) infoHash = m[1].toLowerCase()
    }
    // Build sources array from supported tracker schemes
    const sources = trackersList
      .filter((t) => /^(?:https?:\/\/|udp:\/\/)/i.test(String(t)))
      .map((t) => `tracker:${t}`)
    // Optionally enrich upstream with real swarm stats (best-effort)
    let enriched = s
    try {
      if (
        swarmEnabled && (swarmTopN <= 0 || idx < swarmTopN) &&
        infoHash && sources && sources.length &&
        (!swarmMissingOnly || (!Number(enriched.seeds) && !Number(enriched.leechers) && !Number(enriched.peers) && !Number(enriched.seeders)))
      ) {
        const stats = await scrapeSwarm(infoHash, sources, swarmTimeout)
        if (stats && stats.ok) {
          const seedsNum = Number(stats.seeds)
          const leechNum = Number(stats.leechers)
          if (Number.isFinite(seedsNum) || Number.isFinite(leechNum)) {
            enriched = { ...s }
            if (Number.isFinite(seedsNum)) { enriched.seeds = seedsNum; enriched.seeders = seedsNum }
            if (Number.isFinite(leechNum)) { enriched.leechers = leechNum; enriched.peers = leechNum }
          }
        }
      }
    } catch (_) { /* ignore swarm errors */ }
    // Build enhanced description (using enriched values when available)
    let description = buildDescriptionMultiline(magnet, s.title || s.name, s.provider, trAdded, enriched, { descAppendOriginal, descRequireDetails, meta: { type, id } })
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
    // Collect sorting metadata
    const rInfo = parseReleaseInfo(magnet, s.title || s.name)
    const resolutionToken = rInfo && rInfo.resolution ? String(rInfo.resolution) : ''
    const resolutionScore = (() => {
      const m = resolutionToken.match(/(\d{3,4})p/i)
      if (m) return Number(m[1])
      const low = resolutionToken.toLowerCase()
      if (low.includes('4k') || low.includes('uhd')) return 2160
      return 0
    })()
    const seedsNum = Number(enriched && (enriched.seeds ?? enriched.seeders ?? enriched.peers ?? enriched.leechers))
    const peersScore = Number.isFinite(seedsNum) ? seedsNum : -1
    const langsArr = []
    try {
      if (Array.isArray(enriched && enriched.languages)) langsArr.push(...enriched.languages)
    } catch (_) { /* ignore */ }
    try {
      if (Array.isArray(rInfo && rInfo.languages)) langsArr.push(...rInfo.languages)
    } catch (_) { /* ignore */ }
    const primaryLang = (langsArr.find(Boolean) || '').toString().toLowerCase()

    // Additional sorting metadata
    const sizeScore = (() => {
      const n = Number((enriched && enriched.sizeBytes) || (rInfo && rInfo.sizeBytes))
      return Number.isFinite(n) ? n : -1
    })()
    const codecScore = (() => {
      const raw = (rInfo && rInfo.codec ? String(rInfo.codec) : '').toLowerCase()
      // Higher is better
      if (!raw) return -1
      if (/(av1)/i.test(raw)) return 6
      if (/(hevc|x265|h\.?265)/i.test(raw)) return 5
      if (/(x264|h\.?264)/i.test(raw)) return 4
      if (/(vp9)/i.test(raw)) return 3
      if (/(mpeg-?4)/i.test(raw)) return 2
      return 0
    })()
    const sourceScore = (() => {
      const src = (rInfo && rInfo.source ? String(rInfo.source) : '').toUpperCase()
      // Normalize common tokens from parse: WEBDL, WEBRIP, BLURAY, BDRIP, HDTV, DVDRIP, CAM, TS
      if (!src) return -1
      if (/BLURAY|BDRIP/.test(src)) return 6
      if (/WEBDL/.test(src)) return 5
      if (/WEBRIP/.test(src)) return 4
      if (/HDRIP/.test(src)) return 3
      if (/HDTV/.test(src)) return 2
      if (/DVDRIP/.test(src)) return 1
      if (/CAM|TS/.test(src)) return 0
      return 0
    })()
    const hdrScore = (() => {
      const hdr = (rInfo && rInfo.hdr ? String(rInfo.hdr) : '').toUpperCase()
      if (!hdr) return 0
      if (/DOLBY\s?VISION|\bDV\b/.test(hdr)) return 3
      if (/HDR10\+/.test(hdr)) return 2
      if (/HDR10|\bHDR\b/.test(hdr)) return 1
      return 1
    })()
    const audioScore = (() => {
      const a = (rInfo && rInfo.audio ? String(rInfo.audio) : '').toUpperCase()
      if (!a) return -1
      if (/ATMOS|TRUEHD/.test(a)) return 6
      if (/DTS-?HD|DTS\s?MA/.test(a)) return 5
      if (/DTS/.test(a)) return 4
      if (/E-?AC-?3|DDP/.test(a)) return 3
      if (/AC3/.test(a)) return 2
      if (/AAC/.test(a)) return 1
      return 0
    })()

    items.push({
      out: {
        name: labelName || '! SeedSphere',
        // Keep the original upstream title for Stremio UI
        title: s.title || s.name,
        // Move extra details into a rich, multiline description
        description,
        ...(infoHash ? { infoHash } : {}),
        ...(typeof s.fileIdx === 'number' ? { fileIdx: s.fileIdx } : {}),
        ...(sources && sources.length ? { sources } : {}),
        behaviorHints: {
          ...(s.behaviorHints || {}),
          bingeGroup,
        },
      },
      meta: {
        resolution: resolutionScore,
        peers: peersScore,
        language: primaryLang,
        size: sizeScore,
        codec: codecScore,
        source: sourceScore,
        hdr: hdrScore,
        audio: audioScore,
      }
    })
  }
  // Apply sorting according to preferences
  const fieldsToUse = sortFields.filter((f) => ['resolution','peers','language','size','codec','source','hdr','audio'].includes(f))
  const factor = (sortOrder === 'asc') ? 1 : -1
  items.sort((a, b) => {
    for (const f of fieldsToUse) {
      const av = a.meta[f]
      const bv = b.meta[f]
      if (f === 'language') {
        const as = (av || '').toString()
        const bs = (bv || '').toString()
        if (!as && !bs) continue
        if (!as && bs) return 1
        if (as && !bs) return -1
        const cmp = as.localeCompare(bs)
        if (cmp !== 0) return factor * cmp
      } else {
        const na = Number(av)
        const nb = Number(bv)
        const aValid = Number.isFinite(na)
        const bValid = Number.isFinite(nb)
        if (!aValid && !bValid) continue
        if (!aValid && bValid) return 1
        if (aValid && !bValid) return -1
        if (na !== nb) return factor * (na - nb)
      }
    }
    return 0
  })

  const final = items.map((it) => it.out)
  // Emit enriched boost event with a representative title for Configure UI
  try {
    if (final.length > 0) {
      const rawRepTitle = final[0]?.title || ''
      const isSeries = String(type).toLowerCase() === 'series'
      const representativeTitle = isSeries ? buildSeriesDisplayTitle(rawRepTitle) : rawRepTitle
      const source = 'aggregate: ' + providers.map(p => p.name || 'Upstream').join(', ')
      const seFromId = isSeries ? parseSeriesId(id) : null
      const seFromTitle = isSeries && !seFromId ? extractSeasonEpisode(rawRepTitle) : null
      boosts.push({
        mode: String(mode || 'basic').toLowerCase(),
        limit: Number.isFinite(maxTrackers) ? Number(maxTrackers) : 0,
        healthy: Array.isArray(trackers) ? trackers.length : 0,
        total: Number.isFinite(trackersTotal) ? Number(trackersTotal) : (Array.isArray(trackers) ? trackers.length : 0),
        source,
        type: String(type || ''),
        id: String(id || ''),
        title: representativeTitle,
        ...(isSeries && (seFromId || seFromTitle) ? { season: (seFromId || seFromTitle).season, episode: (seFromId || seFromTitle).episode } : {}),
      })
    }
  } catch (_) { /* ignore boost errors */ }

  setCache(key, final, cacheTtlMs)
  return final
}

module.exports = { aggregateStreams, filterAvailableProviders }
