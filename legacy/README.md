# SeedSphere

[![Latest Release](https://img.shields.io/github/v/release/jxoesneon/SeedSphere?display_name=release)](https://github.com/jxoesneon/SeedSphere/releases/latest)
[![CI](https://github.com/jxoesneon/SeedSphere/actions/workflows/ci.yml/badge.svg)](https://github.com/jxoesneon/SeedSphere/actions/workflows/ci.yml)
[![Release Workflow](https://github.com/jxoesneon/SeedSphere/actions/workflows/release.yml/badge.svg)](https://github.com/jxoesneon/SeedSphere/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## Quick links

- Latest Release: [github.com/jxoesneon/SeedSphere/releases/latest](https://github.com/jxoesneon/SeedSphere/releases/latest)
- Changelog: [CHANGELOG.md](https://github.com/jxoesneon/SeedSphere/blob/main/CHANGELOG.md)

![SeedSphere banner](public/assets/background-1024.jpg)

## Install

- Addon (Stremio): open the SeedSphere page and click Install
  - Production: [https://seedsphere.fly.dev](https://seedsphere.fly.dev)
  - Dev-gated install UI in `Home.vue` appears only with the `?dev=1` query.

## Quick start (development)

```sh
npm install
npm run dev
```

- Build production assets: `npm run build`
- Preview production server: `npm run preview`
- Run tests: `npm test`

## Docs

- Configure UI Canon: [`docs/CONFIGURE_UI_CANON.md`](docs/CONFIGURE_UI_CANON.md)
- Greenhouse API: [`docs/openapi.yaml`](docs/openapi.yaml)

## Project overview

SeedSphere is composed of three parts:

- Greenhouse (backend): HTTP API, SSE rooms, link-token binding, stream bridge, rate limits, cache.
- Gardener (app/PWA): Frontend for landing, pair, configure, executor; runs tracker/execution in the browser; maintains gardener_id.
- Seedling (Stremio addon): Stateless addon that links to a Gardener and requests streams.

## Architecture overview

- Identities
  - gardener_id: identifies a Gardener PWA instance (stored in LocalStorage).
  - seedling_id: identifies a Stremio addon installation.
  - Many-to-many bindings supported between gardeners and seedlings.

- Linking
  - Primary: link tokens.
    - POST /api/link/start (PWA) → { token, gardener_id, expires_at }
    - POST /api/link/complete (Addon) → { ok, gardener_id, seedling_id, secret }
  - Fallback Pair page: /pair?seedling_id=... → redirects to /configure?gardener_id=... if already linked.
  - Dynamic manifest: manifest.json?gardener_id=... so Stremio retains the id on addon URL.

- Streams bridge
  - Seedling → Greenhouse → Gardener (SSE rooms) → result to Seedling.
  - Attempts: 3 tries with budgets 4s, 6s, 8s selecting next-best Gardener by health. On failure, return last cached.
  - Addon receives a single final JSON (Stremio does not consume SSE/chunked partials).

- Cache policy
  - Prefer fresh; fallback to last cached.
  - Weekly write cap: at most 1 cache write per (stream_key + gardener_id) per 7 days; reads unthrottled within TTL (7 days).
  - stream_key = hash(provider + id + filters).

- Signing
  - Per-binding secret minted at link-complete.
  - HMAC-SHA256 over canonical string: ts\nnonce\nmethod\npath\nsortedQuery\nbodySha256.
  - Headers: X-SeedSphere-G, X-SeedSphere-Id, X-SeedSphere-Ts, X-SeedSphere-Nonce, X-SeedSphere-Sig.
  - Replay protection: ±120s window; nonces cached 5 minutes.

## Routes (Gardener UI)

- / (landing: Install PWA, Install Addon)
- /pair (fallback pairing)
- /configure (addon config target; redirects if not linked)
- /executor (debug/status)

## Dev vs Prod configuration

- Addon base URL
  - Production: [https://seedsphere.fly.dev](https://seedsphere.fly.dev) (set via CI variable; used in landing deep links).
  - Development: [http://127.0.0.1:8080](http://127.0.0.1:8080) or [http://localhost:8080](http://localhost:8080).

- Local development
  - Build and run server in Docker:
    - docker build -t seedsphere:local .
    - scripts/docker-run-local.sh
  - App served on port 8080 by default.

- Stremio deep link (example)
  - stremio://seedsphere.fly.dev/manifest.json?gardener_id=... or with a link token during first install.

## Community & Support

- Code of Conduct: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- Contributing Guide: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Security Policy: [`SECURITY.md`](SECURITY.md)
- Discussions: [github.com/jxoesneon/SeedSphere/discussions](https://github.com/jxoesneon/SeedSphere/discussions)

## License

This project is licensed under the [MIT License](LICENSE).

## API

- See docs/openapi.yaml for the latest Greenhouse API (link-token endpoints, SSE rooms, stream bridge, signing headers).

## Stremio stream formatting

- __Torrent streams must use `infoHash`__.
  - Optional: `fileIdx` (if not set, Stremio auto-selects the largest file).
  - Optional: `sources`: array of tracker endpoints in the form `tracker:<protocol>://host:port` where protocol is `http`, `https`, or `udp`.
  - Do __not__ set `url` to a magnet. Using a magnet in `url` can trigger playback errors in some Stremio clients.
  - Optional: `behaviorHints.bingeGroup` to support auto-selecting the same group for next episodes.
  - Optional: `description` for rich multiline info (resolution, codec, HDR, audio, group, seeds/peers, size, languages, and for series: Season/Episode lines).

- __Direct streams__ may use `url` (mp4 over https) with `behaviorHints.notWebReady` when appropriate.

- __Where implemented__:
  - `server/lib/aggregate.cjs`: builds final torrent streams with `{ infoHash, fileIdx?, sources?, behaviorHints }` and omits `url` for torrents.
  - `server/addon.cjs`: demo stream uses `{ infoHash, sources }` for consistency.

- __Example__

```json
{
  "name": "! SeedSphere",
  "title": "Sample 1080p",
  "description": "🎬 WEB • x265 • HDR10\n🔊 5.1 • EN\n📦 2.1 GiB\n🌱 120 • 👥 40\n🗣️ EN\n📺 Season 01\n🎞️ Episode 05",
  "infoHash": "0123456789abcdef0123456789abcdef01234567",
  "fileIdx": 1,
  "sources": [
    "tracker:https://tracker.example.org:443/announce",
    "tracker:udp://tracker.openbittorrent.com:80/announce"
  ],
  "behaviorHints": {
    "bingeGroup": "seedsphere-optimized"
  }
}
```

## Terminology

- Greenhouse = backend bridge and registry
- Gardener = app/PWA executor and UI
- Seedling = Stremio addon
