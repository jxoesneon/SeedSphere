const { URLSearchParams } = require('node:url')

function getMagnetName(magnet) {
  try {
    if (!magnet || !String(magnet).startsWith('magnet:?')) return ''
    const params = new URLSearchParams(String(magnet).slice(8))
    return decodeURIComponent(params.get('dn') || '')
  } catch (_) { return '' }
}

function normalizeCodec(s) {
  const x = s.toLowerCase()
  if (/(hevc|x265|h\.265)/i.test(x)) return 'HEVC x265'
  if (/(x264|h\.264)/i.test(x)) return 'x264'
  if (/av1/i.test(x)) return 'AV1'
  return s
}

function parseSize(str) {
  try {
    const m = String(str || '').match(/(\d+(?:\.\d+)?)\s*(TB|TiB|GB|GiB|MB|MiB|KB|KiB)\b/i)
    if (!m) return { sizeStr: null, sizeBytes: null }
    const num = parseFloat(m[1])
    const unit = m[2].toUpperCase()
    const mult = unit === 'TB' || unit === 'TIB' ? 1024 ** 4
      : unit === 'GB' || unit === 'GIB' ? 1024 ** 3
      : unit === 'MB' || unit === 'MIB' ? 1024 ** 2
      : 1024
    const sizeBytes = Math.round(num * mult)
    return { sizeStr: `${num} ${unit.replace('IB','B')}`, sizeBytes }
  } catch (_) { return { sizeStr: null, sizeBytes: null } }
}

function parseLanguages(str) {
  const s = String(str || '').toLowerCase()
  const langs = new Set()
  const add = (x) => { if (x) langs.add(x) }
  if (/\b(multi|multi[-_. ]lang|multi[-_. ]audio)\b/i.test(s)) add('Multi')
  if (/\bdual\b/i.test(s)) add('Dual')
  if (/\b(eng|english)\b/i.test(s)) add('English')
  if (/\b(spa|spanish|español|latino|castellano)\b/i.test(s)) add('Spanish')
  if (/\b(fre|fra|french|francais|français)\b/i.test(s)) add('French')
  if (/\b(ita|italian|italiano)\b/i.test(s)) add('Italian')
  if (/\b(ger|deu|german|deutsch)\b/i.test(s)) add('German')
  if (/\b(ru|rus|russian|русский)\b/i.test(s)) add('Russian')
  if (/\b(pt|por|portuguese|português|brazil|br)\b/i.test(s)) add('Portuguese')
  if (/\b(pol|polish|polski)\b/i.test(s)) add('Polish')
  if (/\b(tur|turkish|türkçe)\b/i.test(s)) add('Turkish')
  if (/\b(ar|ara|arabic|عربى)\b/i.test(s)) add('Arabic')
  if (/\b(hin|hi|hindi)\b/i.test(s)) add('Hindi')
  if (/\b(jpn|jp|japanese|日本語)\b/i.test(s)) add('Japanese')
  if (/\b(kor|ko|korean|한국어)\b/i.test(s)) add('Korean')
  if (/\b(chi|zho|chinese|中文|国配|國語)\b/i.test(s)) add('Chinese')
  return Array.from(langs)
}

function parseReleaseInfo(magnet, fallbackTitle = '') {
  const name = getMagnetName(magnet) || String(fallbackTitle || '')
  const out = { name, resolution: null, source: null, codec: null, hdr: null, audio: null, group: null, sizeStr: null, sizeBytes: null, languages: [] }
  const s = name

  // Resolution
  const res = (s.match(/(2160p|1080p|720p|480p)/i) || [])[1]
  if (res) out.resolution = res.toUpperCase()

  // Source
  const src = (s.match(/(WEB[-_. ]?DL|WEB[-_. ]?Rip|BluRay|BDRip|BRRip|HDRip|DVDRip)/i) || [])[1]
  if (src) out.source = src.replace(/[_.]/g, '').toUpperCase()

  // Codec
  const codec = (s.match(/(HEVC|x265|H\.265|x264|H\.264|AV1)/i) || [])[1]
  if (codec) out.codec = normalizeCodec(codec)

  // HDR / DV
  if (/HDR10\+?/i.test(s)) out.hdr = 'HDR10+'
  else if (/Dolby[ \-.]?Vision|\bDV\b/i.test(s)) out.hdr = 'Dolby Vision'
  else if (/\bHDR\b/i.test(s)) out.hdr = 'HDR'

  // Audio
  const audio = (s.match(/(DDP(?:\.?5\.1)?|E-?AC-?3|AC3|DTS(?:-HD)?(?: MA)?|TrueHD|AAC|Opus)/i) || [])[1]
  if (audio) out.audio = audio.replace(/_/g, ' ').toUpperCase()

  // Group (after last '-') or bracketed
  const groupDash = (s.match(/-(\w+)(?:\.[a-z0-9]+)?$/i) || [])[1]
  const groupBrk = (s.match(/\[(\w+)\]$/i) || [])[1]
  out.group = groupBrk || groupDash || null

  // Size
  const { sizeStr, sizeBytes } = parseSize(s)
  out.sizeStr = sizeStr
  out.sizeBytes = sizeBytes

  // Languages
  out.languages = parseLanguages(s)

  return out
}

module.exports = { parseReleaseInfo, getMagnetName, parseLanguages, parseSize }
