# SeedSphere

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
  - Production: https://seedsphere.fly.dev (set via CI variable; used in landing deep links).
  - Development: http://127.0.0.1:8080 or http://localhost:8080.

- Local development
  - Build and run server in Docker:
    - docker build -t seedsphere:local .
    - scripts/docker-run-local.sh
  - App served on port 8080 by default.

- Stremio deep link (example)
  - stremio://seedsphere.fly.dev/manifest.json?gardener_id=... or with a link token during first install.

## API

- See docs/openapi.yaml for the latest Greenhouse API (link-token endpoints, SSE rooms, stream bridge, signing headers).

## Terminology

- Greenhouse = backend bridge and registry
- Gardener = app/PWA executor and UI
- Seedling = Stremio addon
