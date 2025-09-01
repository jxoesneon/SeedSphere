const addonBuilder = require("stremio-addon-sdk")
const axios = require("axios")
const { isTrackerUrl, unique, filterByHealth } = require("./lib/health.cjs")
const { setLastFetch } = require("./lib/trackers_meta.cjs")
const boosts = require("./lib/boosts.cjs")
const { aggregateStreams } = require('./lib/aggregate.cjs')
const torrentio = require('./providers/torrentio.cjs')
const yts = require('./providers/yts.cjs')
const eztv = require('./providers/eztv.cjs')
const nyaa = require('./providers/nyaa.cjs')
const x1337 = require('./providers/x1337.cjs')
const piratebay = require('./providers/piratebay.cjs')
const torrentgalaxy = require('./providers/torrentgalaxy.cjs')
const torlock = require('./providers/torlock.cjs')
const magnetdl = require('./providers/magnetdl.cjs')
const anidex = require('./providers/anidex.cjs')
const tokyotosho = require('./providers/tokyotosho.cjs')
const zooqle = require('./providers/zooqle.cjs')
const rutor = require('./providers/rutor.cjs')

// Docs: https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/responses/manifest.md
const manifest = {
	"id": "community.SeedSphere",
	"version": "0.0.9",
	"catalogs": [],
	"resources": [
		"stream"
	],
	"types": [
		"movie",
		"series"
	],
	"name": "SeedSphere",
	"logo": "https://seedsphere.fly.dev/assets/icon.png",
	"description": "Say goodbye to buffering. SeedSphere strengthens your stream connections by finding more sources, ensuring faster start times and a smoother playback experience, especially for less common content.",
	"idPrefixes": [
		"tt"
	],
	"stremioAddonsConfig": {
		"issuer": "https://stremio-addons.net",
		"signature": "eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0..0dhFNY0_5nxeA6QsQHVQAQ.RnUtICPP-vQdh3RH5lmmmFQsfllR6T8tV5gq6puxOICWuKCJlGKqQkhqc9JZwrPbgnnwNIup5xSpH7zfCtkTARkhexamJKe9brEF4Fhm2pHAVmo73yHctqzRbKoNTLYn.lYbSy2Rwzm_kLjcpzjy8dg"
	},
	"behaviorHints": {
		"configurable": true
	},
	"config": [
		{
			"key": "auto_proxy",
			"type": "select",
			"default": "on",
			"title": "Proxy upstream streams",
			"options": [
				{ "value": "on", "label": "On (aggregate and optimize)" },
				{ "value": "off", "label": "Off (addon emits only its own demo)" }
			]
		},
		{
			"key": "variant",
			"type": "select",
			"default": "all",
			"title": "Trackers list variant",
			"options": [
				{ "value": "all", "label": "All trackers (default)" },
				{ "value": "best", "label": "Best curated trackers" },
				{ "value": "all_udp", "label": "All UDP trackers" },
				{ "value": "all_http", "label": "All HTTP trackers" },
				{ "value": "all_ws", "label": "All WebSocket trackers" },
				{ "value": "all_ip", "label": "All trackers (IP only)" },
				{ "value": "best_ip", "label": "Best trackers (IP only)" }
			]
		},
		{
			"key": "trackers_url",
			"type": "text",
			"title": "Custom trackers URL (overrides variant)",
			"default": ""
		},
		{
			"key": "validation_mode",
			"type": "select",
			"title": "Validation mode",
			"default": "basic",
			"options": [
				{ "value": "off", "label": "Off (fastest)" },
				{ "value": "basic", "label": "Basic (DNS + HTTP HEAD)" },
				{ "value": "aggressive", "label": "Aggressive (more probes)" }
			]
		},
		{
			"key": "stream_label",
			"type": "text",
			"title": "Stream label (name shown in Stremio)",
			"default": "! SeedSphere"
		},
		{
			"key": "max_trackers",
			"type": "number",
			"title": "Max trackers to append (0 = unlimited)",
			"default": 0
		},
        {
            "key": "desc_append_original",
            "type": "select",
            "title": "Append original provider description",
            "default": "off",
            "options": [ { "value": "on", "label": "On" }, { "value": "off", "label": "Off" } ]
        },
        {
            "key": "desc_require_details",
            "type": "select",
            "title": "Use original description when no details parsed",
            "default": "on",
            "options": [ { "value": "on", "label": "On" }, { "value": "off", "label": "Off" } ]
        },
        {
            "key": "ai_descriptions",
            "type": "select",
            "title": "AI enhanced descriptions (requires external API key)",
            "default": "off",
            "options": [ { "value": "off", "label": "Off" }, { "value": "on", "label": "On" } ]
        },
        {
            "key": "ai_provider",
            "type": "text",
            "title": "AI provider (e.g., openai, anthropic, google, groq, mistral)",
            "default": "openai"
        },
        {
            "key": "ai_model",
            "type": "text",
            "title": "AI model (provider-specific)",
            "default": "gpt-4o"
        },
        {
            "key": "ai_timeout_ms",
            "type": "number",
            "title": "AI timeout (ms)",
            "default": 2500
        },
        {
            "key": "ai_cache_ttl_ms",
            "type": "number",
            "title": "AI cache TTL (ms)",
            "default": 60_000
        },
        {
            "key": "ai_user_id",
            "type": "text",
            "title": "AI user id (opaque)",
            "default": ""
        },
		{
			"key": "providers_torrentio",
			"type": "select",
			"default": "on",
			"title": "Provider: Torrentio",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_yts",
			"type": "select",
			"default": "on",
			"title": "Provider: YTS (Movies)",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_eztv",
			"type": "select",
			"default": "on",
			"title": "Provider: EZTV (Series)",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_nyaa",
			"type": "select",
			"default": "on",
			"title": "Provider: Nyaa (Anime)",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_1337x",
			"type": "select",
			"default": "on",
			"title": "Provider: 1337x",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_piratebay",
			"type": "select",
			"default": "on",
			"title": "Provider: Pirate Bay",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		}
		,
		{
			"key": "providers_torrentgalaxy",
			"type": "select",
			"default": "on",
			"title": "Provider: TorrentGalaxy",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_torlock",
			"type": "select",
			"default": "on",
			"title": "Provider: Torlock",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_magnetdl",
			"type": "select",
			"default": "on",
			"title": "Provider: MagnetDL",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_anidex",
			"type": "select",
			"default": "on",
			"title": "Provider: AniDex (Anime)",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_tokyotosho",
			"type": "select",
			"default": "on",
			"title": "Provider: TokyoTosho (Anime)",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_zooqle",
			"type": "select",
			"default": "on",
			"title": "Provider: Zooqle",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		},
		{
			"key": "providers_rutor",
			"type": "select",
			"default": "on",
			"title": "Provider: Rutor",
			"options": [
				{ "value": "on", "label": "On" },
				{ "value": "off", "label": "Off" }
			]
		}
	]
}
const builder = addonBuilder(manifest)

// Trackerslist integration
const VARIANT = (process.env.TRACKERS_VARIANT || "all").toLowerCase()
const VARIANT_URLS = {
    all: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt",
    best: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt",
    all_udp: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_udp.txt",
    all_http: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_http.txt",
    all_ws: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ws.txt",
    all_ip: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt",
    best_ip: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt",
}
const DEFAULT_TRACKERS_URL = process.env.TRACKERS_URL || VARIANT_URLS[VARIANT] || VARIANT_URLS.all
const CACHE_MS = 24 * 60 * 60 * 1000
// Variant-specific TTLs (defaults to 24h)
const VARIANT_TTLS = {
    all: 12 * 60 * 60 * 1000,
    best: 6 * 60 * 60 * 1000,
    all_udp: 12 * 60 * 60 * 1000,
    all_http: 12 * 60 * 60 * 1000,
    all_ws: 12 * 60 * 60 * 1000,
    all_ip: 24 * 60 * 60 * 1000,
    best_ip: 12 * 60 * 60 * 1000,
}
const trackersCacheByUrl = new Map() // url -> { list: string[], ts: number, ttl: number }
const inFlightByUrl = new Map() // url -> Promise<string[]>

function findVariantForUrl(url) {
    for (const [k, v] of Object.entries(VARIANT_URLS)) {
        if (v === url) return k
    }
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
        const list = res.data
            .split("\n")
            .map((t) => t.trim())
            .filter((t) => t && !t.startsWith("#") && isTrackerUrl(t))
        const deduped = unique(list)
        trackersCacheByUrl.set(url, { list: deduped, ts: now, ttl })
        try { setLastFetch(Date.now()) } catch (_) {}
        return deduped
    })()
    inFlightByUrl.set(url, task)
    try { return await task } finally { inFlightByUrl.delete(url) }
}

// Preload trackers on startup (non-blocking)
Promise.allSettled(Object.values(VARIANT_URLS).map((u) => fetchTrackers(u))).then(() => {
    // noop
}).catch((e) => console.warn("Initial trackers prefetch failed:", e && e.message ? e.message : String(e)))

builder.defineStreamHandler(async (args, cb) => {
  try {
  const { type, id, extra } = args || {}
  console.log("request for streams:", type, id)
  // Determine effective URL based on user config (SDK provides extra)
  const cfg = extra || {}
  const selectedVariant = (cfg.variant || VARIANT).toLowerCase()
  const labelName = String(cfg.stream_label || '! SeedSphere')
  const descAppendOriginal = String(cfg.desc_append_original || 'off').toLowerCase() === 'on'
  const descRequireDetails = String(cfg.desc_require_details || 'on').toLowerCase() === 'on'
  const aiConfig = {
    enabled: String(cfg.ai_descriptions || 'off').toLowerCase() === 'on',
    provider: String(cfg.ai_provider || 'openai'),
    model: String(cfg.ai_model || 'gpt-4o'),
    timeoutMs: Number(cfg.ai_timeout_ms) || 2500,
    cacheTtlMs: Number(cfg.ai_cache_ttl_ms) || 60_000,
    userId: String(cfg.ai_user_id || ''),
  }
  const selectedUrl = (cfg.trackers_url && cfg.trackers_url.trim()) || VARIANT_URLS[selectedVariant] || DEFAULT_TRACKERS_URL

  let trackers = []
  try {
    trackers = await fetchTrackers(selectedUrl)
  } catch (e) {
    console.warn("Falling back to empty trackers due to fetch error:", e.message)
  }

  // Apply health filtering and limits
  const mode = (cfg.validation_mode || "basic").toLowerCase()
  let maxTrackers = Number(cfg.max_trackers)
  if (!Number.isFinite(maxTrackers) || maxTrackers < 0) maxTrackers = 0 // 0 means unlimited
  let effective = trackers
  try {
    effective = await filterByHealth(trackers, mode, maxTrackers)
  } catch (e) {
    console.warn("Health filtering failed:", e.message)
    effective = maxTrackers > 0 ? trackers.slice(0, maxTrackers) : trackers
  }

  // Aggregate upstream streams and augment with optimized trackers (if enabled)
  const autoProxy = String(cfg.auto_proxy || 'on').toLowerCase() !== 'off'
  if (autoProxy) {
    try {
      // Select providers based on config toggles
      const providers = []
      const torrentioOn = String(cfg.providers_torrentio || 'on').toLowerCase() !== 'off'
      if (torrentioOn) providers.push(torrentio)
      const ytsOn = String(cfg.providers_yts || 'on').toLowerCase() !== 'off'
      if (ytsOn) providers.push(yts)
      const eztvOn = String(cfg.providers_eztv || 'on').toLowerCase() !== 'off'
      if (eztvOn) providers.push(eztv)
      const nyaaOn = String(cfg.providers_nyaa || 'on').toLowerCase() !== 'off'
      if (nyaaOn) providers.push(nyaa)
      const x1337On = String(cfg.providers_1337x || 'on').toLowerCase() !== 'off'
      if (x1337On) providers.push(x1337)
      const pirateOn = String(cfg.providers_piratebay || 'on').toLowerCase() !== 'off'
      if (pirateOn) providers.push(piratebay)
      const tgxOn = String(cfg.providers_torrentgalaxy || 'on').toLowerCase() !== 'off'
      if (tgxOn) providers.push(torrentgalaxy)
      const torlockOn = String(cfg.providers_torlock || 'on').toLowerCase() !== 'off'
      if (torlockOn) providers.push(torlock)
      const magnetdlOn = String(cfg.providers_magnetdl || 'on').toLowerCase() !== 'off'
      if (magnetdlOn) providers.push(magnetdl)
      const anidexOn = String(cfg.providers_anidex || 'on').toLowerCase() !== 'off'
      if (anidexOn) providers.push(anidex)
      const tokyotoshoOn = String(cfg.providers_tokyotosho || 'on').toLowerCase() !== 'off'
      if (tokyotoshoOn) providers.push(tokyotosho)
      const zooqleOn = String(cfg.providers_zooqle || 'on').toLowerCase() !== 'off'
      if (zooqleOn) providers.push(zooqle)
      const rutorOn = String(cfg.providers_rutor || 'on').toLowerCase() !== 'off'
      if (rutorOn) providers.push(rutor)
      const streams = await aggregateStreams({ type, id, providers, trackers: effective, bingeGroup: 'seedsphere-optimized', labelName, descAppendOriginal, descRequireDetails, aiConfig })
      if (Array.isArray(streams) && streams.length > 0) {
        // Log boost per aggregated response
        try {
          const source = 'aggregate: ' + providers.map(p => p.name).join(', ')
          boosts.push({ mode, limit: maxTrackers || 0, healthy: effective.length, total: trackers.length, source, type, id })
        } catch (_) { /* ignore */ }
        return cb(null, { streams })
      }
    } catch (e) {
      console.warn('Aggregation failed:', e && e.message ? e.message : String(e))
    }
  }

  // Demo stream for a known IMDb id
  if ((type === "movie" || type === "series") && id === "tt1254207") {
    const infoHash = "0000000000000000000000000000000000000000"
    const trParams = effective.map((t) => `tr=${encodeURIComponent(t)}`).join("&")
    const magnet = `magnet:?xt=urn:btih:${infoHash}${trParams ? "&" + trParams : ""}`

    const stream = {
      name: `${labelName}`,
      title: `Demo magnet with ${effective.length} trackers`,
      url: magnet,
      behaviorHints: {
        bingeGroup: "seedsphere-trackers",
      },
    }
    return cb(null, { streams: [stream] })
  }

  return cb(null, { streams: [] })
  } catch (e) {
    try { return cb(null, { streams: [] }) } catch (_) { /* ignore */ }
  }
})

module.exports = builder
