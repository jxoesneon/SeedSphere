'use strict'

const path = require('node:path')
const fs = require('node:fs')
const { parseReleaseInfo } = require('./parse.cjs')

function loadJson(p) {
  const raw = fs.readFileSync(p, 'utf8')
  return JSON.parse(raw)
}

// Load mappings once at module load
const mappingsDir = path.join(__dirname, 'mappings')
const qualityMap = loadJson(path.join(mappingsDir, 'quality.json'))
const editionsMap = loadJson(path.join(mappingsDir, 'editions.json'))
const versionTags = loadJson(path.join(mappingsDir, 'version_tags.json'))
const providersList = loadJson(path.join(mappingsDir, 'providers.json'))
const languagesMap = loadJson(path.join(mappingsDir, 'languages.json'))

const providerBySlug = new Map(providersList.map((p) => [String(p.slug), p]))

function toTitleNatural(title) {
  const s = String(title || '')
  // Remove (YYYY)
  let t = s.replace(/\(\s*(19|20)\d{2}\s*\)/g, '').trim()
  // Remove [Remastered ...] brackets anywhere
  t = t.replace(/\[\s*Remaster(?:ed)?[^\]]*\]/ig, '').trim()
  // Remove trailing edition segments introduced by — or - or : (Director's Cut, Extended, etc.)
  t = t.replace(/[\s]*[\u2014\-:][\s]*(Director(?:’|')s Cut|Extended(?: Edition)?|Ultimate(?: Edition)?|Theatrical(?: Cut)?|Unrated|IMAX|Special(?: Edition)?)(?:.*)?$/i, '').trim()
  // Remove trailing quality/resolution tokens
  t = t.replace(/\b(2160p|1080p|720p|480p|4k)\b\s*$/i, '').trim()
  // Collapse spaces
  t = t.replace(/\s+/g, ' ').trim()
  return t
}

function extractYear(title) {
  const s = String(title || '')
  const mParen = s.match(/\((19|20)\d{2}\)/)
  if (mParen) return parseInt(mParen[0].slice(1, -1), 10)
  const mTrail = s.match(/(?:^|[^0-9])(19|20)\d{2}(?!.*(19|20)\d{2})/) // rightmost
  if (mTrail) return parseInt(mTrail[0].match(/(19|20)\d{2}/)[0], 10)
  return null
}

function mapEdition(title) {
  const s = String(title || '').toLowerCase()
  for (const canonical of editionsMap.canonical) {
    const aliases = editionsMap.aliases[canonical] || []
    for (const a of aliases) {
      const r = new RegExp(`(^|[\\s\u2014\-])${a.replace(/[-/\\^$*+?.()|[\]{}]/g, r=>`\\${r}`)}($|[\\s])`, 'i')
      if (r.test(s)) return canonical
    }
  }
  return null
}

function extractRemaster(title) {
  const s = String(title || '')
  const br = s.match(/\[\s*Remaster(?:ed)?\s*([^\]]*)\]/i)
  if (br) {
    const note = (br[1] || '').trim()
    return { flag: true, note: note || undefined }
  }
  const suf = s.match(/Remaster(?:ed)?\s*(4K|1080p|2160p|HDR10\+?|DV|Dolby Vision)?/i)
  if (suf) return { flag: true, note: (suf[1] || '').toUpperCase() || undefined }
  return null
}

function extractVersionTag(extras, title) {
  const sources = [String(extras || ''), String(title || '')]
  for (const src of sources) {
    for (const pat of versionTags.patterns) {
      const re = new RegExp(pat, 'i')
      const m = src.match(re)
      if (m) return m[0]
    }
  }
  return null
}

function mapQuality(q) {
  const s = String(q || '').toLowerCase()
  // direct match
  for (const canon of qualityMap.canonical) {
    if (canon.toLowerCase() === s) return canon
  }
  // alias match
  for (const canon of qualityMap.canonical) {
    const aliases = qualityMap.aliases[canon] || []
    if (aliases.some((a) => a.toLowerCase() === s)) return canon
  }
  // tolerant: numbers
  if (/\b4k\b|2160/.test(s)) return '2160p'
  if (/\b1080\b/.test(s)) return '1080p'
  if (/\b720\b/.test(s)) return '720p'
  if (/\b480\b/.test(s)) return '480p'
  return null
}

function mapProvider(providerInput) {
  let slug = ''
  let display = null
  let url = null
  const s = String(providerInput || '').toLowerCase().trim()
  // if already a known slug
  if (providerBySlug.has(s)) {
    const p = providerBySlug.get(s)
    return { provider_display: p.display, provider_url: p.url, slug: p.slug }
  }
  // host mapping: try to map known hosts to slug
  if (s.includes('yts')) slug = 'yts'
  else if (s.includes('eztv')) slug = 'eztv'
  else if (s.includes('torrentio')) slug = 'torrentio'
  else if (s.includes('1377x') || s.includes('1337x')) slug = '1337x'
  else if (s.includes('anidex')) slug = 'anidex'
  else if (s.includes('magnetdl')) slug = 'magnetdl'
  if (slug && providerBySlug.has(slug)) {
    const p = providerBySlug.get(slug)
    return { provider_display: p.display, provider_url: p.url, slug: p.slug }
  }
  return { provider_display: s || null, provider_url: null, slug: slug || null }
}

function expandLanguages(codes) {
  const items = Array.isArray(codes) ? codes : String(codes || '').split(/[,;\s]+/)
  const displays = []
  const flags = []
  const internalCodes = []

  const aliasEntries = Object.entries(languagesMap.aliases || {})
  const langIndex = new Map(languagesMap.languages.map((l) => [l.code.toLowerCase(), l]))

  for (let raw of items) {
    raw = String(raw || '').trim()
    if (!raw) continue
    const low = raw.toLowerCase()

    // MULTI special
    if (aliasEntries.some(([k, arr]) => k === 'multi' && arr.some((a) => a.toLowerCase() === low))) {
      continue // handled by default if nothing else
    }

    // find canonical code by alias
    let code = null
    for (const [canon, arr] of aliasEntries) {
      if (canon === 'multi') continue
      if (canon.toLowerCase() === low || (arr || []).some((a) => String(a).toLowerCase() === low)) {
        code = canon
        break
      }
    }
    if (!code) code = raw

    internalCodes.push(code)
    const rec = langIndex.get(String(code).toLowerCase())
    if (rec) {
      displays.push(rec.display)
      flags.push(rec.flag)
    } else {
      // derive display and flag policy for unknowns: use code itself and default flag for base lang
      const base = String(code).split('-')[0].toLowerCase()
      const defFlag = languagesMap.policy?.default_flags?.[base] || languagesMap.policy?.unspecified_flags?.[0] || '🌐'
      displays.push(code)
      flags.push(defFlag)
    }
  }

  if (!displays.length) {
    return { languages_display: languagesMap.policy.unspecified_display, languages_flags: languagesMap.policy.unspecified_flags, internal_codes: [] }
  }
  return { languages_display: displays, languages_flags: flags, internal_codes: internalCodes }
}

function normalize(input) {
  const title = String(input.title || '')
  const providerIn = input.provider || ''
  const qualityIn = input.quality || (input.extras || '')
  const languageIn = input.language || input.languages || []
  const infohashIn = input.infohash || ''
  const extrasIn = input.extras || ''

  const title_natural = toTitleNatural(title)
  const year = extractYear(title)
  const edition = mapEdition(title)
  const remaster = extractRemaster(title)
  const version_tag = extractVersionTag(extrasIn, title)
  const quality = mapQuality(qualityIn)
  const prov = mapProvider(providerIn)
  const { languages_display, languages_flags, internal_codes } = expandLanguages(languageIn)

  // Parse extras using existing parseReleaseInfo for source/codec/hdr/audio/size/group
  const parsed = parseReleaseInfo(extrasIn, title)

  // Infohash validation
  let infohash = null
  const m = String(infohashIn || '').trim().match(/^[a-fA-F0-9]{40}$/)
  if (m) infohash = m[0].toUpperCase()

  const out = {
    title_natural,
    year,
    edition,
    remaster,
    version_tag,
    quality,
    languages_display,
    languages_flags,
    provider_display: prov.provider_display,
    provider_url: prov.provider_url,
    infohash,
    extras: {
      source: parsed.source,
      codec: parsed.codec,
      hdr: parsed.hdr,
      audio: parsed.audio,
      group: parsed.group,
      sizeStr: parsed.sizeStr,
      sizeBytes: parsed.sizeBytes,
    },
    internal: {
      provider_slug: prov.slug,
      language_codes: internal_codes,
    },
  }
  return out
}

module.exports = { normalize }
