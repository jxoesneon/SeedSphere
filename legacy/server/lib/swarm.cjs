// Swarm scraping helper for seeds/leechers via HTTP/HTTPS tracker scrape
// CommonJS module

const https = require('https')
const http = require('http')

function toHexInfoHash(v) {
  if (!v) return ''
  const s = String(v).trim()
  // Accept 40-char hex or 32-char base32
  if (/^[a-fA-F0-9]{40}$/.test(s)) return s.toLowerCase()
  if (/^[A-Z2-7]{32}$/.test(s)) {
    // base32 to hex
    try {
      // Node has no built-in base32; do a minimal conversion
      const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
      let bits = ''
      for (const ch of s) {
        const idx = alphabet.indexOf(ch)
        if (idx < 0) return ''
        bits += idx.toString(2).padStart(5, '0')
      }
      // drop padding bits to 160 bits
      const wanted = 160
      bits = bits.slice(0, wanted)
      let hex = ''
      for (let i = 0; i < bits.length; i += 4) {
        const chunk = bits.slice(i, i + 4)
        hex += parseInt(chunk, 2).toString(16)
      }
      if (hex.length === 40) return hex
      return ''
    } catch (_) { return '' }
  }
  return ''
}

function normalizeAnnounce(announce) {
  const urls = Array.isArray(announce) ? announce : []
  // Only HTTP(S) trackers support simple scrape via GET; skip UDP here
  return urls.filter(Boolean).map(String).filter((u) => /^https?:\/\//i.test(u))
}

function hexToPctEncodedBytes(hex) {
  const buf = Buffer.from(hex, 'hex')
  let out = ''
  for (const b of buf) out += '%' + b.toString(16).padStart(2, '0').toUpperCase()
  return out
}

function toScrapeUrl(announceUrl) {
  try {
    const u = new URL(announceUrl)
    const path = u.pathname
    // Replace /announce with /scrape per spec; if not present, try appending
    if (path.includes('/announce')) {
      u.pathname = path.replace('/announce', '/scrape')
    } else {
      u.pathname = (path.endsWith('/') ? path : path + '/') + 'scrape'
    }
    return u.toString()
  } catch (_) {
    return ''
  }
}

function fetchScrape(scrapeUrl, ihHex, timeoutMs) {
  return new Promise((resolve) => {
    try {
      const pct = hexToPctEncodedBytes(ihHex)
      const urlObj = new URL(scrapeUrl)
      urlObj.searchParams.set('info_hash', pct)
      const lib = urlObj.protocol === 'https:' ? https : http
      const req = lib.get(urlObj, { timeout: Math.max(500, timeoutMs) }, (res) => {
        if (res.statusCode !== 200) { res.resume(); return resolve(null) }
        const chunks = []
        res.on('data', (c) => chunks.push(c))
        res.on('end', () => {
          try {
            const buf = Buffer.concat(chunks)
            const decoded = decodeBencode(buf)
            const files = decoded && decoded.files
            if (!files) return resolve(null)
            // files keys are 20-byte buffers; find matching infohash
            let rec = null
            for (const k in files) {
              if (!Object.prototype.hasOwnProperty.call(files, k)) continue
              const v = files[k]
              const keyBuf = Buffer.isBuffer(k) ? k : Buffer.from(k, 'binary')
              const keyHex = keyBuf.toString('hex')
              if (keyHex.toLowerCase() === ihHex.toLowerCase()) { rec = v; break }
            }
            if (!rec) return resolve(null)
            const seeds = Number(rec.complete || rec.seeders || 0) || 0
            const leechers = Number(rec.incomplete || rec.leechers || 0) || 0
            resolve({ seeds, leechers })
          } catch (_) { resolve(null) }
        })
      })
      req.on('timeout', () => { try { req.destroy() } catch (_) {} resolve(null) })
      req.on('error', () => resolve(null))
    } catch (_) { resolve(null) }
  })
}

async function scrapeOnce({ announce, infoHash, timeoutMs = 2500 }) {
  const scrapeUrl = toScrapeUrl(announce)
  if (!scrapeUrl) return null
  return await fetchScrape(scrapeUrl, infoHash, timeoutMs)
}

async function scrapeSwarm(infoHash, sources = [], timeoutMs = 2500) {
  const ih = toHexInfoHash(infoHash)
  if (!ih) return { ok: false, seeds: null, leechers: null }
  const announce = normalizeAnnounce(
    sources
      .filter((s) => typeof s === 'string' && s.startsWith('tracker:'))
      .map((s) => s.replace(/^tracker:/, ''))
  )
  if (!announce.length) return { ok: false, seeds: null, leechers: null }
  // Try trackers one by one until one responds
  for (const a of announce) {
    const res = await scrapeOnce({ announce: a, infoHash: ih, timeoutMs })
    if (res) return { ok: true, seeds: res.seeds, leechers: res.leechers }
  }
  return { ok: false, seeds: null, leechers: null }
}

module.exports = { scrapeSwarm }

// --- Minimal bencode decoder (integers, byte strings, lists, dicts) ---
function decodeBencode(buf) {
  const b = Buffer.isBuffer(buf) ? buf : Buffer.from(buf)
  let i = 0

  function parse() {
    const ch = String.fromCharCode(b[i])
    if (ch === 'i') return parseIntVal()
    if (ch === 'l') return parseList()
    if (ch === 'd') return parseDict()
    if (ch >= '0' && ch <= '9') return parseBytes()
    throw new Error('invalid bencode at ' + i)
  }

  function parseIntVal() {
    // i<digits>e
    i++ // skip 'i'
    let s = ''
    while (i < b.length) {
      const ch = String.fromCharCode(b[i++])
      if (ch === 'e') break
      s += ch
    }
    return parseInt(s, 10)
  }

  function parseBytes() {
    // <len>:<bytes>
    let lenStr = ''
    while (i < b.length) {
      const ch = String.fromCharCode(b[i++])
      if (ch === ':') break
      lenStr += ch
    }
    const len = parseInt(lenStr, 10)
    const out = b.slice(i, i + len)
    i += len
    return out
  }

  function parseList() {
    // l<items>e
    i++ // skip 'l'
    const arr = []
    while (i < b.length && String.fromCharCode(b[i]) !== 'e') {
      arr.push(wrap(parse()))
    }
    i++ // skip 'e'
    return arr
  }

  function parseDict() {
    // d<key><val>e, keys are byte strings
    i++ // skip 'd'
    const obj = {}
    while (i < b.length && String.fromCharCode(b[i]) !== 'e') {
      const kBuf = parseBytes()
      const key = Buffer.from(kBuf) // keep Buffer key semantics
      const val = wrap(parse())
      obj[key] = val
    }
    i++ // skip 'e'
    return obj
  }

  function wrap(val) {
    // Convert Buffers that look like text digits to numbers for scrape keys
    if (Buffer.isBuffer(val)) return val
    if (Array.isArray(val)) return val
    return val
  }

  return parse()
}
