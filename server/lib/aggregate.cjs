const { normalizeMagnet, appendTrackers, buildMagnet } = require('./magnet.cjs')
const { parseReleaseInfo } = require('./parse.cjs')
const { enhanceDescription } = require('./ai_descriptions.cjs')
const { scrapeSwarm } = require('./swarm.cjs')
const boosts = require('./boosts.cjs')
const reqctx = require('./reqctx.cjs')
const rolllog = require('./rolllog.cjs')

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

// Ensure every upstream stream has a consistent shape so downstream logic is predictable
function standardizeStream(s) {
  const out = {}
  const provider = String(s && s.provider ? s.provider : 'Upstream')
  const title = String(s && s.title ? s.title : provider)
  const infoHash = String(s && s.infoHash ? s.infoHash : '').toLowerCase()
  const url = String(s && s.url ? s.url : '')
  const behaviorHints = (s && typeof s.behaviorHints === 'object' && s.behaviorHints) ? s.behaviorHints : {}
  const description = String((s && s.description) || '')
  const seeds = (s && Number.isFinite(Number(s.seeds))) ? Number(s.seeds) : null
  const leechers = (s && Number.isFinite(Number(s.leechers))) ? Number(s.leechers) : null
  const size = (s && s.size !== undefined && s.size !== null) ? String(s.size) : null
  const sizeBytes = (s && Number.isFinite(Number(s.sizeBytes))) ? Number(s.sizeBytes) : null
  let languages = []
  try {
    if (Array.isArray(s.languages)) languages = s.languages.filter(Boolean).map(String)
    else if (typeof s.language === 'string') languages = [String(s.language)]
  } catch (_) {}
  out.provider = provider
  out.title = title
  if (infoHash) out.infoHash = infoHash
  if (url) out.url = url
  out.behaviorHints = behaviorHints
  out.description = description
  out.seeds = seeds
  out.leechers = leechers
  out.size = size
  out.sizeBytes = sizeBytes
  out.languages = languages
  return out
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

// Build an informative (non-playable) stream entry to ensure UI always shows at least one item
// reason: machine-readable code, e.g. 'no_providers_enabled', 'providers_unreachable', 'providers_zero_results', 'global_timeout', 'account_issue'
// details: optional metadata to surface in description (providers, timeouts, trackers count, etc.)
function buildInformativeStream({ reason = 'no_results', details = {}, labelName = '! SeedSphere', configureUrl = '/configure' }) {
  const reasonTitles = {
    no_providers_enabled: 'No providers enabled',
    providers_unreachable: 'Providers unreachable',
    providers_zero_results: 'No results from providers',
    providers_error: 'Provider errors',
    providers_request_failed: 'Provider requests failed',
    no_results: 'No results',
    trackers_list_empty: 'No trackers configured',
    account_missing_identities: 'Sign-in required',
    account_no_binding: 'Installation not linked',
    account_invalid_signature: 'Signature invalid',
    account_banned: 'Account banned',
    seedling_invalid_signature: 'Link invalid',
    seedling_revoked: 'Installation revoked',
    global_timeout: 'Timed out',
  }
  const titleBase = reasonTitles[reason] || 'SeedSphere'
  const lines = []
  // Primary reason
  lines.push(`Reason: ${titleBase}`)
  // Optional details block
  try {
    const prov = Array.isArray(details.providers) ? details.providers.filter(Boolean) : []
    if (prov.length) lines.push(`Providers: ${prov.join(', ')}`)
  } catch (_) {}
  try {
    if (Number.isFinite(details.probeTimeoutMs)) lines.push(`Probe timeout: ${details.probeTimeoutMs} ms`)
    if (Number.isFinite(details.providerFetchTimeoutMs)) lines.push(`Provider fetch timeout: ${details.providerFetchTimeoutMs} ms`)
  } catch (_) {}
  try {
    if (Number.isFinite(details.trackersCount)) lines.push(`Trackers configured: ${details.trackersCount}`)
  } catch (_) {}
  try {
    if (details.note) lines.push(String(details.note))
  } catch (_) {}
  // Action hint
  lines.push('Action: Open Configure to review providers, trackers, and preferences.')
  const seedlingId = String(reqctx.getSeedlingId() || '')
  let cfgLink = String(configureUrl || '/configure')
  try {
    if ((!configureUrl || configureUrl === '/configure') && seedlingId) {
      const u = new URL('/configure', 'http://local')
      u.searchParams.set('seedling_id', seedlingId)
      cfgLink = u.pathname + u.search
    }
  } catch (_) { /* ignore URL failures */ }
  lines.push(`Configure: ${cfgLink}`)

  return {
    name: labelName || '! SeedSphere',
    title: `${titleBase} — Configure SeedSphere`,
    description: lines.join('\n'),
    // Placeholder torrent to ensure Stremio renders an entry; not intended to be playable
    infoHash: '0000000000000000000000000000000000000000',
    behaviorHints: { bingeGroup: 'seedsphere-info', notWebReady: true },
  }
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

async function aggregateStreams({ type, id, providers, trackers, trackersTotal = null, mode = 'basic', maxTrackers = 0, bingeGroup = 'seedsphere-optimized', cacheTtlMs = DEFAULT_TTL_MS, labelName = 'SeedSphere', descAppendOriginal = false, descRequireDetails = true, aiConfig = { enabled: false }, probeProviders = 'off', probeTimeoutMs = 500, providerFetchTimeoutMs = 3000, maxProviderConcurrency = null, swarm = { enabled: false, topN: 2, timeoutMs: 800, missingOnly: true }, sort = { order: 'desc', fields: ['resolution','peers','language'] } }) {
  // Normalize sort config
  const sortOrder = (sort && String(sort.order || 'desc').toLowerCase() === 'asc') ? 'asc' : 'desc'
  const sortFields = Array.isArray(sort && sort.fields) && (sort.fields.length > 0)
    ? sort.fields.map((s) => String(s || '').toLowerCase())
    : ['resolution','peers','language']

  const key = `agg:${providers.map(p => p.name || 'N').join(',')}:${type}:${id}:sort:${sortOrder}:${sortFields.join(',')}`
  const cached = getCache(key, true)
  if (cached) return cached

  const trackersAll = Array.isArray(trackers) ? trackers : []
  const doProbe = (String(probeProviders || 'off').toLowerCase() === 'on') || (probeProviders === true)
  const available = doProbe ? await filterAvailableProviders(providers, probeTimeoutMs) : providers

  // Fallback cases before querying providers
  if (!Array.isArray(providers) || providers.length === 0) {
    const info = buildInformativeStream({
      reason: 'no_providers_enabled',
      details: { trackersCount: trackersAll.length },
      labelName,
    })
    try { require('./db.cjs').writeAudit('fallback_stream', { reason: 'no_providers_enabled', type, id, seedling_id: (reqctx && reqctx.getSeedlingId && reqctx.getSeedlingId()) || '' }) } catch (_) {}
    setCache(key, [info], cacheTtlMs)
    return [info]
  }
  if (doProbe && Array.isArray(available) && available.length === 0) {
    const info = buildInformativeStream({
      reason: 'providers_unreachable',
      details: { providers: providers.map(p => p.name || 'Upstream'), probeTimeoutMs, providerFetchTimeoutMs, trackersCount: trackersAll.length },
      labelName,
    })
    try { require('./db.cjs').writeAudit('fallback_stream', { reason: 'providers_unreachable', type, id, seedling_id: (reqctx && reqctx.getSeedlingId && reqctx.getSeedlingId()) || '' }) } catch (_) {}
    setCache(key, [info], cacheTtlMs)
    return [info]
  }

  // Optional provider concurrency bound
  const maxConcRaw = Number.isFinite(Number(maxProviderConcurrency)) ? Number(maxProviderConcurrency) : null
  const CONCURRENCY = (maxConcRaw && maxConcRaw > 0) ? Math.min(maxConcRaw, available.length || 1) : (available.length || 1)
  async function allSettledWithConcurrency(list, limit, taskFn) {
    const results = new Array(list.length)
    let i = 0
    async function next() {
      const idx = i++
      if (idx >= list.length) return
      try {
        const v = await taskFn(list[idx], idx)
        results[idx] = { status: 'fulfilled', value: v }
      } catch (e) {
        results[idx] = { status: 'rejected', reason: e }
      }
      return next()
    }
    const runners = Array.from({ length: Math.min(limit, list.length) }, () => next())
    await Promise.allSettled(runners)
    return results
  }
  const results = await allSettledWithConcurrency(available, CONCURRENCY, async (p) => {
    try { return await p.fetchStreams(type, id, providerFetchTimeoutMs) }
    catch (_) { return { ok: false, provider: p && p.name, streams: [] } }
  })
  const collected = []
  let anyOkEmpty = false
  let anyError = false
  let anyRejected = false
  const reasonProvidersZero = []
  const reasonProvidersError = []
  const reasonProvidersRejected = []
  const providerCounts = {}
  const exampleTitles = {}
  for (const r of results) {
    if (r.status !== 'fulfilled') { anyRejected = true; continue }
    const res = r.value
    const providerName = (res && (res.provider || res.name)) || 'Upstream'
    if (!res || res.ok !== true) { anyError = true; reasonProvidersError.push(providerName); continue }
    if (!Array.isArray(res.streams)) { anyError = true; reasonProvidersError.push(providerName); continue }
    if (res.streams.length === 0) { anyOkEmpty = true; reasonProvidersZero.push(providerName); continue }
    providerCounts[providerName] = (providerCounts[providerName] || 0) + res.streams.length
    if (!exampleTitles[providerName]) {
      const first = res.streams[0]
      exampleTitles[providerName] = first && (first.title || first.name || '') || ''
    }
    for (const s of res.streams) {
      const st = standardizeStream({ ...s, provider: res.provider || s.provider || 'Upstream' })
      collected.push(st)
    }
  }
  try {
    rolllog.log('stream_debug', {
      component: 'addon',
      stage: 'provider_counts',
      type,
      id,
      seedling_id: String(reqctx.getSeedlingId() || ''),
      counts: providerCounts,
      examples: exampleTitles,
    })
  } catch (_) { /* ignore logging errors */ }
  if (collected.length === 0) {
    let reason = 'no_results'
    if (trackersAll.length === 0) reason = 'trackers_list_empty'
    if (anyOkEmpty) reason = 'providers_zero_results'
    else if (anyError) reason = 'providers_error'
    else if (anyRejected) reason = 'providers_request_failed'
    const info = buildInformativeStream({
      reason,
      details: {
        providers: available.map(p => p.name || 'Upstream'),
        probeTimeoutMs,
        providerFetchTimeoutMs,
        trackersCount: trackersAll.length,
        note: trackersAll.length === 0 ? 'No trackers are configured; consider changing variant or custom URL.' : undefined,
      },
      labelName,
    })
    try { require('./db.cjs').writeAudit('fallback_stream', { reason, type, id, seedling_id: (reqctx && reqctx.getSeedlingId && reqctx.getSeedlingId()) || '' }) } catch (_) {}
    setCache(key, [info], cacheTtlMs)
    return [info]
  }

  const merged = dedupeStreams(collected)
  // Use all trackers by default; allow optional cap via maxTrackers > 0
  const cap = (Number.isFinite(maxTrackers) && maxTrackers > 0) ? Math.floor(maxTrackers) : trackersAll.length
  const trackersList = cap > 0 ? trackersAll.slice(0, cap) : trackersAll

  const items = []
  const swarmCfg = swarm || {}
  const swarmEnabled = !!swarmCfg.enabled
  const swarmTopN = Number.isFinite(swarmCfg.topN) ? Math.max(0, swarmCfg.topN) : 0
  const swarmTimeout = Number(swarmCfg.timeoutMs) || 800
  const swarmMissingOnly = ('missingOnly' in swarmCfg) ? !!swarmCfg.missingOnly : true

  // Determine requested S/E for series
  const seRequested = (String(type || '').toLowerCase() === 'series') ? parseSeriesId(id) : null

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

    // Surface normalized fields on the final stream for consistent shape
    const leechersNum = Number(enriched && (enriched.leechers ?? enriched.peers))
    const sizeBytesOut = Number((enriched && enriched.sizeBytes) || (rInfo && rInfo.sizeBytes))
    const languagesOut = Array.from(new Set(langsArr)).filter(Boolean)

    // Series exact-match hint: prefer entries with explicit SxxEyy or explicit fileIdx
    const seFromMagnet = (() => { try { return extractSeasonEpisode(rInfo && rInfo.name) } catch (_) { return null } })()
    const seMatches = !!(seRequested && (
      typeof s.fileIdx === 'number' ||
      (seFromMagnet && Number(seFromMagnet.season) === Number(seRequested.season) && Number(seFromMagnet.episode) === Number(seRequested.episode))
    ))

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
        // Provide standardized fields for downstream consumers and tests
        provider: s.provider || undefined,
        seeds: Number.isFinite(seedsNum) ? seedsNum : null,
        leechers: Number.isFinite(leechersNum) ? leechersNum : null,
        size: (s.size !== undefined && s.size !== null) ? String(s.size) : null,
        sizeBytes: Number.isFinite(sizeBytesOut) ? sizeBytesOut : null,
        languages: languagesOut,
      },
      meta: {
        sematch: seMatches ? 1 : 0,
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
    // Always prefer items that explicitly match requested S/E (sematch=1) when available
    const sa = Number(a.meta.sematch || 0)
    const sb = Number(b.meta.sematch || 0)
    if (sa !== sb) return sb - sa
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

  let final = items.map((it) => it.out)
  // Prefer Torrentio results first for all types; for series, EZTV second — helps avoid wrong-title scrapes overshadowing accurate providers
  try {
    if (Array.isArray(final) && final.length > 1) {
      const isSeries = String(type || '').toLowerCase() === 'series'
      const first = final.filter((s) => String(s.provider || '') === 'Torrentio')
      const second = isSeries ? final.filter((s) => String(s.provider || '') === 'EZTV') : []
      const rest = final.filter((s) => !['Torrentio', ...(isSeries ? ['EZTV'] : [])].includes(String(s.provider || '')))
      final = [].concat(first, second, rest)
    }
  } catch (_) { /* ignore reordering issues */ }
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
        seedling_id: String(reqctx.getSeedlingId() || ''),
        ...(isSeries && (seFromId || seFromTitle) ? { season: (seFromId || seFromTitle).season, episode: (seFromId || seFromTitle).episode } : {}),
      })
    }
  } catch (_) { /* ignore boost errors */ }

  setCache(key, final, cacheTtlMs)
  return final
}

module.exports = { aggregateStreams, filterAvailableProviders, buildInformativeStream }
