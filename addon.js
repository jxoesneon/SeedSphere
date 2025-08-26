const { addonBuilder } = require("stremio-addon-sdk")
const axios = require("axios")
const { isTrackerUrl, unique, filterByHealth } = require("./lib/health")
const boosts = require("./lib/boosts")

// Docs: https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/responses/manifest.md
const manifest = {
	"id": "community.SeedSphere",
	"version": "0.0.1",
	"catalogs": [],
	"resources": [
		"stream"
	],
	"types": [
		"movie",
		"series"
	],
	"name": "SeedSphere",
	"description": "Say goodbye to buffering. SeedSphere strengthens your stream connections by finding more sources, ensuring faster start times and a smoother playback experience, especially for less common content.",
	"idPrefixes": [
		"tt"
	],
	"behaviorHints": {
		"configurable": true
	},
	"config": [
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
			"key": "max_trackers",
			"type": "number",
			"title": "Max trackers to append (0 = unlimited)",
			"default": 0
		}
	]
}
const builder = new addonBuilder(manifest)

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
const trackersCacheByUrl = new Map() // url -> { list: string[], ts: number }

async function fetchTrackers(url) {
    const now = Date.now()
    const entry = trackersCacheByUrl.get(url)
    if (entry && now - entry.ts < CACHE_MS) return entry.list
    const res = await axios.get(url)
    const list = res.data
        .split("\n")
        .map((t) => t.trim())
        .filter((t) => t && !t.startsWith("#") && isTrackerUrl(t))
    const deduped = unique(list)
    trackersCacheByUrl.set(url, { list: deduped, ts: now })
    return deduped
}

// Preload trackers on startup (non-blocking)
fetchTrackers(DEFAULT_TRACKERS_URL).catch((e) => console.warn("Initial trackers fetch failed:", e.message))

builder.defineStreamHandler(async ({ type, id, config }) => {
    console.log("request for streams:", type, id)
    // Docs: https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/requests/defineStreamHandler.md

    // Demo: for a known IMDb id, return a magnet with appended trackers
    // Big Buck Bunny IMDb id is tt1254207; we will serve a demo magnet for illustration only
    if ((type === "movie" || type === "series") && id === "tt1254207") {
        // Determine effective URL based on user config (if any)
        // Stremio passes user configuration in args.config
        // We support either a custom URL or a variant selection
        const cfg = config || {}
        const selectedVariant = (cfg.variant || VARIANT).toLowerCase()
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

        // Log recent boost (for visibility in /configure)
        try {
            const source = selectedUrl || selectedVariant
            boosts.push({ mode, limit: maxTrackers || 0, healthy: effective.length, total: trackers.length, source })
        } catch (_) { /* ignore */ }

        // Example infoHash (not an actual copyrighted content hash); replace with real hashes in real sources
        const infoHash = "0000000000000000000000000000000000000000"
        const trParams = effective.map((t) => `tr=${encodeURIComponent(t)}`).join("&")
        const magnet = `magnet:?xt=urn:btih:${infoHash}${trParams ? "&" + trParams : ""}`

        const stream = {
            name: "SeedSphere Trackers (demo)",
            title: `Demo magnet with ${effective.length} trackers`,
            url: magnet,
            behaviorHints: {
                bingeGroup: "seedsphere-trackers",
            },
        }
        return { streams: [stream] }
    }

    // Otherwise return no streams (this addon does not scrape content; it augments magnets)
    return { streams: [] }
})

module.exports = builder.getInterface()