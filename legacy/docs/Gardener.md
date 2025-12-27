# SeedSphere: Greenhouse · Seedling · Gardener (Authoritative Design)

This document supersedes `docs/PWA_EXECUTOR_DESIGN.md` terminology where “Executor” is now “Gardener,” the client-side agent. The server is “Greenhouse,” and the addon is “Seedling.” Internal IDs (e.g., `executor_id`) may remain until code refactors; UI/Docs should use the new names.

## 1) Purpose

Design a low-cost, privacy-aware system where Seedling requests are fulfilled by Gardener (paired PWA) while Greenhouse orchestrates, caches, and safeguards. Target Web/Desktop/Android/iOS and TV via pairing.

### 1.1 Goals

- Minimal server CPU/bandwidth on Fly.io.
- Simple, privacy-aware, abuse-resistant design.
- Works across Web/Desktop/Android/iOS; supports TV via pairing.
- Maintain stateless addon URL; keep durable state server-side.

## 2) Roles

- Greenhouse (server): Orchestrates tasks, normalizes/caches results, enforces policy, emits SSE.
- Seedling (addon): Presents streams to Stremio, pairs accounts/devices, receives room events.
- Gardener (PWA): Performs outbound provider fetches from user’s device/network and returns results.

## 3) Key Decisions

- Identity: `install_id` per device; persisted in PWA LocalStorage.
- Pairing: QR code + short code flow; strict rate limits and expiry.
- Selection: Single-target dispatch to best-health Gardener (no multicast), with hysteresis and fallbacks.
- Privacy: Gardener contacts third parties directly; no content hosted by SeedSphere.
- Rate limits: Device/IP/User buckets with bursts; 429 + Retry-After; pairing endpoints stricter.
- Caching: Per-provider TTLs, SWR/Stale-If-Error, dynamic TTL floors, circuit breakers.
- Entropy: Local crypto plus ≥3 external sources with pseudorandom selection and secure mixing.
- Storage: SQLite with nightly prune window and 24h retention beyond `expires_at`.
- TV: QR-first onboarding with strong QR ergonomics.
- iOS: Foreground needed for reliability; banner + auto-reconnect on resume.
- PWA origin: use `https://seedsphere.fly.dev` for PWA and QR URLs.
- Browser extension track: none planned; PWA-only covers platforms.
- TV executors: TV requires a paired Gardener (phone/desktop) for outbound fetches.
- CORS/mixed-content: attempt direct client fetch; if blocked, proxy-on-demand (strict quotas) or skip.
- CDN TTL audit: maintain a small audit task to monitor TTLs and adjust dynamically.
- Network egress differences: acceptable; surface geo/ISP variability hints to users.
- Extension store policies: if a browser extension track is ever pursued, document least‑privilege permissions; avoid over‑broad host permissions.

## 4) Components

- Greenhouse core: HTTP API, SSE rooms, ratelimits, task dispatch, normalization, cache.
- Seedling: HTTP client to Greenhouse, room subscription, UI for pairing and status.
- Gardener: PWA app with pairing, task execution, SSE, telemetry, and device management.
- Edge cache: Cloudflare Worker/Cache/KV from the start; plus SQLite and in-memory LRU on server.

## 5) Flows

- __Register Gardener__: Gardener (PWA) starts and establishes presence by joining `rooms/:gardener_id` and sending periodic heartbeats.
- __Link (primary)__: Gardener → `POST /api/link/start` → `{ token, gardener_id }`; Seedling (on install via manifest with token) → `POST /api/link/complete` → binds `{ seedling_id, gardener_id, secret }`.
- __Link (fallback)__: Seedling "Configure" opens `/pair?seedling_id=...`; if already bound, redirect to `/configure?gardener_id=...`.
- __Streams__: Seedling → `GET /stream/*` (to Greenhouse). Greenhouse selects best Gardener by health and issues task via SSE. Up to 3 attempts (4s→6s→8s) across next-best Gardeners; on failure, return last cached. Seedling receives a single final JSON payload.

## 5Z) PWA-as-Executor and Addon Linking (Vertical Slice)

This section defines a simplified, production-ready path where the PWA runs the executor logic in the browser and the addon links to a specific PWA installation.

- __Landing page (website)__
  - Primary CTAs: “Install PWA” and “Install Addon”.
  - Clicking “Install Addon” mints a short-lived link token and opens the Stremio deep link with `?token=...`.

- __Linking endpoints (Greenhouse)__
  - `POST /api/link/start` body `{ install_id }` → `{ ok, token, install_id, expires_at }`
    - Called by PWA to mint a token bound to its `install_id` (10 min TTL).
  - `POST /api/link/complete` body `{ token }` → `{ ok, install_id }`
    - Called by the addon on first request (e.g., from `manifest.json` or `stream/*`).
    - Stores a durable mapping `addon_binding(token_used_once) → install_id`.
  - Optional: `GET /api/link/status?install_id=...` → `{ ok, linked: boolean }` to surface in PWA UI.

- __Addon bridge behavior__
  - For `GET /stream/*` requests: resolve `install_id` via binding; emit a task to room `install_id` and await result up to N seconds. If no executor online or timeout, return fallback (e.g., empty list or cached sample) with cache-control hints.

- __PWA executor behavior__
  - PWA stores `install_id` in LocalStorage.
  - Subscribes to `GET /api/rooms/:install_id/events` (SSE).
  - On `task` event, executes provider queries (direct fetch or backend proxy) and replies via `/api/tasks/result` (or room `result` event), then idles.

- __Deep link shape__
  - `stremio://<host>/manifest.json?token=<link_token>`
  - On first addon hit, the backend completes link with `{ token }`.

- __Migration notes__
  - The existing pairing code (`/api/pair/start`, `/api/pair/complete`, `/api/pair/status`) can be aliased to or superseded by link tokens. For the vertical slice, prefer link tokens for addon↔PWA binding while retaining pairing endpoints for TV/secondary devices if needed.

Rationale: avoids entering codes inside Stremio and ties the addon to the user’s PWA instance cleanly, with strong UX on the landing page and bounded server work.

### 5Z.1 Confirmed specifics

- __Identities__
  - `gardener_id` (formerly `install_id`) identifies a Gardener PWA instance; stored in LocalStorage.
  - `seedling_id` identifies a Stremio addon install.
  - Many-to-many supported: one Seedling can bind to many Gardeners and vice versa.

- __Linking & fallback__
  - Primary: link tokens (`POST /api/link/start`, `POST /api/link/complete`).
  - Fallback Pair page: `/pair?seedling_id=...` (and optional `gardener_id`). If already linked, redirect to `/configure?gardener_id=...`.

- __Dynamic manifest__
  - `GET /manifest.json` accepts `?gardener_id=...`. Stremio retains query params on addon URL, enabling automatic linking.

- __Bridge semantics__
  - Addon makes `/stream/*` to Greenhouse. Greenhouse selects the best Gardener by health and issues a task via rooms/SSE.
  - Retries: up to 3 attempts with budgets 4s → 6s → 8s. Prefer next-best Gardener each attempt; apply hysteresis (≥5-point delta to switch) and a 60s penalty after failures.
  - Addon receives a single final JSON result (Stremio does not consume SSE); internal PWA↔Greenhouse streaming is allowed.

- __Cache policy__
  - Prefer fresh. Fallback to last cached if all attempts fail.
  - Weekly write cap: at most 1 cache write per `stream_key + gardener_id` per 7 days. Reads are not rate-limited and follow TTL (7 days) semantics.
  - `stream_key = hash(provider + id + filters)`.

- __Signing & rate limits__
  - On link-complete, Greenhouse issues a per-binding secret.
  - All addon↔Greenhouse and PWA↔Greenhouse requests are HMAC-SHA256 signed over a canonical string: `ts\nnonce\nmethod\npath\nsortedQuery\nbodySha256`.
  - Headers: `X-SeedSphere-G` (gardener_id), `X-SeedSphere-Id` (seedling_id), `X-SeedSphere-Ts`, `X-SeedSphere-Nonce`, `X-SeedSphere-Sig` (base64url HMAC).
  - Replay window ±120s; nonce cache 5 minutes. Anonymous use allowed; authenticated users can receive higher quotas later.

- __Presence & health__
  - PWA connects to `rooms/:gardener_id` and emits heartbeats; Greenhouse tracks `last_seen`, latency, success %, jitter; selection uses these metrics.

- __Routes (Gardener UI)__
  - Direct routes: `/` (landing with Install PWA/Add-on), `/pair`, `/configure`, `/executor` (debug/status). Gardener shows sections by role.

- __Environment & URLs__
  - Dynamic addon base URL: CI sets production to `https://seedsphere.fly.dev`; Docker/dev use `http://127.0.0.1:8080` or `http://localhost:8080`.

### 5Z.2 Defaults and limits

- __Token__
  - TTL: 10 minutes. Size: 32 random bytes (base64url, no padding).

- __Identifiers__
  - `gardener_id`, `seedling_id`: UUID v4 (lowercase, hyphenated).
  - Max bindings: 10 per seedling, 10 per gardener (hard cap; 429 if exceeded).

- __Signing__
  - Canonical query: RFC 3986 percent-encoding, sort by key then value.
  - Body hash: SHA‑256 of raw body bytes; empty body = SHA‑256(""). Max signed body: 1 MB.
  - Secret rotation: mint new secret on each successful link‑complete; revoke old.

- __Link status__
  - `GET /api/link/status?gardener_id=...` returns linked seedlings.
  - A sibling variant MAY return linked gardeners by `seedling_id`.

- __Retries & timeout__
  - Attempts: 4s → 6s → 8s (~18s total budget + small overhead).
  - Selection: next‑best Gardener per attempt; hysteresis ≥5 points; 60s penalty after failure.
  - Health weights: success 50%, latency 30%, freshness 20%.

- __Partial events (internal)__
  - `task:start`, `task:partial`, `task:final`, `task:error` (payloads are implementation-defined).

- __Cache normalization__
  - `stream_key = hash(type + provider + id + season + episode + normalized_filters)`.
  - Normalize filter ordering and trim whitespace before hashing.

- __Presence__
  - Heartbeat every 15s; offline after 45s of silence.
  - Rooms named `rooms/:gardener_id`.

- __Rate limits (indicative)__
  - `POST /api/link/start`: per‑IP 3/min, 30/hour; per‑gardener 5/10min.
  - `POST /api/link/complete`: per‑IP 10/10min; per‑seedling 10/10min.
  - `POST /api/stream/*`: per‑seedling 60/min (burst 10); per‑IP 120/min.

- __CORS__
  - Allowlist: production addon host; dev `http://127.0.0.1:8080`, `http://localhost:8080`.

- __Config (env)__
  - `ADDON_BASE_URL` (CI/dev). Optional: `CACHE_TTL_DAYS=7`, `HMAC_NONCE_TTL_MIN=5`.

- __Migration__
  - Rename `installations.install_id` → `gardeners.gardener_id`.
  - Create `seedlings`, `bindings(secret)`; keep `pairings` for fallback.
  - Backfill: convert existing pairs into bindings when possible.

- __Bindings management__
  - Provide endpoints to list and delete bindings; secrets are per‑binding.

- __Telemetry & retention__
  - Log anonymized counts/latency keyed by hashed ids; retain 30 days. Cache TTL 7 days.

- __Error handling__
  - If attempts fail and no cache exists, return empty array to Stremio.
  - Pair page shows a "Re‑link" CTA if token expired or linking fails.

## 5A) Data Model (SQLite)

- users: user_id, email, created_at.
- gardeners: gardener_id (UUID), user_id (nullable), platform, created_at, last_seen.
- seedlings: seedling_id (UUID), user_id (nullable), created_at, last_seen.
- bindings: seedling_id, gardener_id, secret, created_at.
- pairings (fallback): pair_code, gardener_id (nullable), seedling_id (nullable), expires_at, status (pending/linked/expired), created_at.
- rooms: room_id (derived from gardener_id), last_activity.
- cache: stream_key, gardener_id, payload_json (gzip/json), created_at, expires_at, hits, last_write_at.
- audit: event, at, meta_json (for TTL tuning, abuse hints, RL decisions).

## 5B) Security Model

- __HMAC signing (per-binding secret)__
  - Secret is minted on `link/complete` for each `{ seedling_id, gardener_id }` binding.
  - Canonical string: `ts\nnonce\nmethod\npath\nsortedQuery\nbodySha256`.
  - Headers:
    - `X-SeedSphere-G`: gardener_id
    - `X-SeedSphere-Id`: seedling_id
    - `X-SeedSphere-Ts`: unix ms
    - `X-SeedSphere-Nonce`: unique 16+ chars
    - `X-SeedSphere-Sig`: base64url(HMAC-SHA256(secret, canonical))
  - Replay window ±120s; nonces cached 5 minutes. Anonymous + rate limiting by default; authenticated users may receive higher quotas later.
- Pair codes: 6 alphanumeric (A–Z, 0–9), 2‑minute expiry.
  - `/api/pair/start` limits: Per‑IP 3/min, 10/10min, 30/hour, 100/day. Per‑install_id 5/10min, 15/hour, 50/day. Max 1 pending per install.
  - `/api/pair/complete` limits: Per‑IP 10/10min, 30/hour, 100/day. Per‑install_id 10/10min. Invalid attempts cooldowns as in original design.
- Pairing security: IP throttling and entropy quality enforced; short expiry codes.
- Rate limiting: per device_id, per user_id (if signed), and per IP on pairing/task issuance.
- No public executors: execution only on user Gardener.
- Entropy: server crypto + external APIs (see §15) with rotation.
- Auth gating: anonymous allowed; server-stored features require signed users.
- Anonymous usage: allowed; rely on device_id + IP limits.
- JWT verification: audience checks, jti uniqueness, and clock-skew tolerant verification.

## 5C) APIs (v1)

- POST `/api/executor/register` → `{ device_id }`
- POST `/api/pair/start` body `{ install_id }` → `{ pair_code, room_id, expires_at }`
- POST `/api/pair/complete` body `{ pair_code, device_id }` → `{ ok, room_id }`
- GET  `/api/rooms/:room_id/events` → SSE stream
  - Envelope: `{ type, room_id, ts, seq, payload, retry_after_ms?, task_jti? }`
  - Event types
    - `status`: `{ state: "connected"|"reconnecting"|"idle"|"active"|"cooldown"|"proxy_quota_exhausted", note? }`
    - `result`: normalized result (see §8.2)
    - `stale`: last cached result with `stale: true` and TTL hints
    - `pairing_prompt`: `{ code, install_id, expires_at }`
    - `error`: `{ code, message, provider? }`
- POST `/api/tasks/request` body `{ install_id, query }` → `{ task } | { status: 'waiting' }`
- POST `/api/tasks/result` body `{ task_jti, install_id, data }` → `{ ok }`
- GET  `/api/cache/:key` → cached result if fresh

Notes

- Abuse protections: add Turnstile/CAPTCHA for suspicious bursts.
- QR payload: `https://seedsphere.fly.dev/pair?code=XXXXXX&install_id=...`.
- Rooms transport: SSE in v1; WS optional later.

## 6) Gardener Selection (Health-Based)

- Single-target dispatch: Greenhouse computes a 0–100 health score; sends task to the top Gardener only.
- Health inputs: latency p50/p95 (decayed 15m), success rate (timeouts weighted), SSE jitter/RTT/reconnects, foreground/availability (iOS background penalized), device/network hints, staleness >30s heartbeat penalty.
- Selection: highest score wins; require ≥5-point delta to switch (hysteresis); −15 penalty for 60s after failures; degraded mode if all <30.
- Fallbacks: if no ack in 1s, reselect next candidate; if none online, queue up to 30s then error.
- Observability: `executor_health_score` gauge; `executor_selection_total` counter; hashed IDs in logs.

## 7) Rate Limits and Observability

- Buckets (initial):
  - per device 60/10min (burst 20)
  - per IP 120/10min (burst 30)
  - per user 240/10min (burst 40)
- Algorithm: token bucket + sliding window. 429 with `Retry-After`.
- Overrides: pairing endpoints stricter; abuse heuristics may halve limits.
- Headers: `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`; `Retry-After` on 429.
- Metrics: `rl_allowed_total`, `rl_blocked_total` with labels `{bucket, route, provider?}`; sampled `rl_tokens_remaining`; `rl_window_usage_ratio` histogram.
- Alerts: 429 rate >1% global (5m), >5% route (5m); warn p95 usage >0.9 for 15m.

## 8) Caching, Invalidation, and Outages

- TTLs: Appendix C.2 baseline per provider.
- Health signals: upstream 5xx/timeout %, p95/p99 latency, schema/checksum anomalies, user reports.
- Dynamic TTL: during degradation (>5% 5xx+timeouts over 5m), floor TTL to 60–120s; restore after 15m healthy.
- SWR: serve last good for up to 10m with in-app banner; background re-fetch.
- Stale-If-Error: serve stale up to 30m per key, then error with retry guidance.
- Circuit breaker: per provider; exponential backoff; jittered cool-down 1–5m.
- Quarantine: invalidate keys on anomaly; block until clean fetch.
- Negative caching: 60s for empty/404; no SWR on negatives.
- Headers: `Cache-Status`; `Warning: 110/112`; `X-Provider-Backoff`.

### 8.1 Cache behavior

- Key: `hash(normalized_query + provider + page + filters)`
- TTLs: 60–600s depending on provider volatility; track hit/miss in `audit` for tuning.
- On request: serve fresh cache; if miss, issue task; on result, store and publish to room.
- Fallbacks: if no Gardener online, return 202 and prompt pairing; also serve last cached result if present.
- Stale policy: if cache is stale but present, include `stale: true` and trigger a background update.

### 8.2 Normalization (Natural schema — authoritative)

Preserve human-friendly titles; extract machine-usable details into separate fields. Natural schema supersedes legacy rules below.

#### 8.2.0 Fields

- title_natural (string)
  - Unicode NFC; preserve casing, diacritics, and punctuation.
  - Derived from original by stripping non-title decorations (year, edition, remaster tags), then trim and collapse internal spaces.
- year (int|null)
  - Best-candidate 4-digit year 1900–2099 (prefer (YYYY) then trailing YYYY).
- edition (string|null)
  - Canonical display values (case-preserving): Director’s Cut, Extended Edition, Ultimate Edition, Theatrical Cut, Unrated, IMAX, Special Edition.
- remaster (object|null)
  - { flag: boolean, note?: string } e.g., { flag: true, note: "4K" }.
- version_tag (string|null)
  - Release markings like PROPER, REPACK, RERIP, v2, FINAL (display as-is).
- quality (enum)
  - One of: 480p | 720p | 1080p | 2160p.
- languages_display (array of strings)
  - If unspecified: ["Multi"]. Else: full names (with region), e.g., English; Spanish (Spain); Spanish (Latino).
- languages_flags (array of strings)
  - Visual flags aligned to languages_display. Policy example: English → 🇬🇧; Spanish (Spain) → 🇪🇸; Spanish (Latino) → 🇲🇽.
- provider_display (string)
  - Acronyms (letters only) → UPPERCASE (YTS, EZTV). Names → natural casing (Torrentio, The Pirate Bay).
- provider_url (string)
  - Canonical provider homepage/API URL when public.
- infohash (string)
  - Uppercase 40-hex.
- internal (object)
  - provider_slug (e.g., yts, eztv, torrentio), language_codes (e.g., ["en","es-ES","es-419"]) for logic only.

#### 8.2.1 Extraction rules

- Title extraction
  - Working copy of original: remove (YYYY), edition suffixes (— or - `Edition`), and [Remastered ...] bracket tags.
  - Trim, collapse spaces; assign to title_natural (preserve casing/diacritics/punctuation).
- Year
  - Prefer (YYYY); else rightmost plausible YYYY near end.
- Edition
  - Match tolerant aliases then map to canonical display (see mapping).
- Remaster
  - Match "[Remastered ...]" or suffix tokens (Remastered 4K/HDR/1080p) → remaster.flag=true, note if present.
- Version tag
  - Tokens: PROPER, REPACK, RERIP, v\d+, FINAL.
- Quality
  - Apply alias map to {480p,720p,1080p,2160p} (see mapping).
- Languages
  - If none → ["Multi"], ["🌐"]. Else expand ISO codes/aliases to full names with region; derive flags (see mapping).
- Provider
  - Map slug/host to display + URL (see mapping). Set internal.provider_slug accordingly.
- Infohash
  - Validate 40-hex and uppercase.

#### 8.2.2 Example

Input (raw)

- title: Harry Potter and the Order of the Phoenix (2007) — Director’s Cut [Remastered 4K]
- provider: yts.mx
- quality: UHD 4K
- language: en, es-ES, es-419
- infohash: a1b2c3d4e5f6070890abcdef1234567890abcdef
- extras: BluRay x265

Output

```json
{
  "title_natural": "Harry Potter and the Order of the Phoenix",
  "year": 2007,
  "edition": "Director’s Cut",
  "remaster": { "flag": true, "note": "4K" },
  "version_tag": null,
  "quality": "2160p",

  "languages_display": ["English", "Spanish (Spain)", "Spanish (Latino)"],
  "languages_flags": ["\uD83C\uDDEC\uD83C\uDDE7", "\uD83C\uDDEA\uD83C\uDDF8", "\uD83C\uDDF2\uD83C\uDDFD"],

  "provider_display": "YTS",
  "provider_url": "https://yts.mx",

  "infohash": "A1B2C3D4E5F6070890ABCDEF1234567890ABCDEF",

  "extras": { "source": "BluRay", "codec": "x265" },

  "internal": {
    "provider_slug": "yts",
    "language_codes": ["en", "es-ES", "es-419"]
  }
}
```

#### 8.2.3 Mappings (authoritative)

- Quality aliases → canonical
  - 2160p: "2160p", "4k", "uhd", "ultra hd"
  - 1080p: "1080p", "fhd", "fullhd", "full hd"
  - 720p:  "720p", "hd"
  - 480p:  "480p", "sd", "dvd"

- Edition aliases → canonical display
  - Director’s Cut: "directors cut", "director's cut"
  - Extended Edition: "extended", "extended edition"
  - Ultimate Edition: "ultimate", "ultimate edition"
  - Theatrical Cut: "theatrical", "theatrical cut"
  - Unrated: "unrated"
  - IMAX: "imax"
  - Special Edition: "special", "special edition"

- Version tags (preserve case as given)
  - PROPER, REPACK, RERIP, FINAL, v2, v3, v4

- Provider slug → display + URL (subset; expand as needed)
  - torrentio → Torrentio → <https://torrentio.strem.fun/>
  - eztv → EZTV → <https://eztv.re/>
  - yts → YTS → <https://yts.mx/>
  - 1337x → 1337x → <https://www.1377x.to/> (mirror)
  - anidex → AniDex → <https://anidex.info/>
  - magnetdl → MagnetDL → <https://www.magnetdl.com/>

- Language codes/aliases → display + flag (subset; expand via CLDR for full list)
  - en → English → 🇬🇧 (or 🇺🇸 per policy)
  - es-ES → Spanish (Spain) → 🇪🇸
  - es-419 → Spanish (Latino) → 🇲🇽 (policy-driven)
  - fr → French → 🇫🇷
  - de → German → 🇩🇪
  - it → Italian → 🇮🇹
  - pt-PT → Portuguese (Portugal) → 🇵🇹
  - pt-BR → Portuguese (Brazil) → 🇧🇷
  - nl → Dutch → 🇳🇱
  - sv → Swedish → 🇸🇪
  - no → Norwegian → 🇳🇴
  - da → Danish → 🇩🇰
  - fi → Finnish → 🇫🇮
  - pl → Polish → 🇵🇱
  - cs → Czech → 🇨🇿
  - ro → Romanian → 🇷🇴
  - hu → Hungarian → 🇭🇺
  - el → Greek → 🇬🇷
  - tr → Turkish → 🇹🇷
  - ru → Russian → 🇷🇺
  - uk → Ukrainian → 🇺🇦
  - he → Hebrew → 🇮🇱
  - ar → Arabic → 🇸🇦
  - hi → Hindi → 🇮🇳
  - id → Indonesian → 🇮🇩
  - th → Thai → 🇹🇭
  - vi → Vietnamese → 🇻🇳
  - ja → Japanese → 🇯🇵
  - ko → Korean → 🇰🇷
  - zh-CN → Chinese (Simplified) → 🇨🇳
  - zh-TW → Chinese (Traditional) → 🇹🇼

Note: For exhaustive language/flag coverage, adopt Unicode CLDR mappings and a fixed flag policy for ambiguous cases.

#### Legacy normalization (compatibility)

- Title: lowercase → NFKD diacritics strip → remove punctuation `[.,_\\/\-:;!?\'\"()\[\]{}]` → collapse internal whitespace → trim.
- Episode index: accept `SxxEyy` or `{season, episode}`; canonical output `SxxEyy`; movies may include `year`.
- Provider id: stable slug per tracker (Appendix C.1).
- Quality: `{480p, 720p, 1080p, 2160p}`.
- Language: ISO‑639‑1 two‑letter lowercase; allow `multi`.
- Sort options: normalize to a canonical subset (provider‑specific mapping).
- Magnet/infohash: lowercase 40‑hex when extracted.

#### 8.2.4 Legacy examples

- Title normalization
  - “La Casa de Papel: Part 2 — Episode 01” → “la casa de papel part 2 episode 01”
  - “Amélie (2001)” → “amelie 2001”
  - “Spider-Man: No Way Home” → “spider man no way home”
  - “Kiki’s Delivery Service – 4K” → “kikis delivery service 4k”
  - “Tôi Thấy Hoa Vàng Trên Cỏ Xanh” → “toi thay hoa vang tren co xanh”

- Whitespace collapse
  - “  The   Lord   of  the Rings  ” → “the lord of the rings”

- Episode canonicalization
  - season=1, episode=2 → “S01E02”
  - “s1e10” → “S01E10”
  - “S03E7” → “S03E07”

- Movie vs series keys
  - Movie: include year when available
  - Series: include `SxxEyy`

- Provider slug examples
  - “TorrentIO”, “Torrent.io” → “torrentio”
  - “EZTV”, “EZTV.re” → “eztv”

- Quality normalization
  - “HD 1080P”, “1080”, “FULLHD” → “1080p”
  - “UHD”, “4K” → “2160p”

- Language normalization
  - “EN”, “Eng”, “English” → “en”
  - “MULTI”, “Multi-Audio” → “multi”

- Magnet/infohash
  - “ABCDEF1234…” → “abcdef1234…” (40‑hex)

## 9) iOS Background Policy

- Foreground requirement during playback/active tasks.
- Home Screen install recommended; Low Power Mode may suspend; advise disabling during playback.
- Optional mitigation: lawful silent/low-volume audio session.
- Suspension fallback: show banner “iOS paused background activity — reopen SeedSphere to resume”; auto-reconnect SSE on foreground; optional local notification if permitted.

### 9.1 Battery Saver (Gardener)

- Never fully stop: maintain minimal residency so users do not need to reopen the app.
- Enter when: no active playback and no user interaction for >2 minutes, or app backgrounded.
- Exit when: playback starts/resumes, a new task arrives, user foregrounds the PWA, or a pairing event occurs.
- Minimal residency: keep an SSE connection to each active room with low‑frequency heartbeats; no tracker fetches unless tasks arrive.
- Idle backoff schedule (heartbeats/reconnects): 5s → 10s → 20s → 40s → 60s (cap), ±10% jitter; maintain max 60s while idle.
- Grace window: after playback stops, keep full‑power listening for 2 minutes before entering saver.

## 10) Telemetry & Privacy

- Default ON (opt-out surfaced on first run). No PII; anonymized aggregates only.
- Scope: latency, cache hit/miss/stale, upstream error codes, served TTL, proxy triggers/outcomes, SSE reconnect counts, platform.
- Redaction: never log titles/queries/URLs; hash long keys; store only HMACs of `install_id`/`device_id` with rotating server secret.
- Controls: Settings toggle; respect Do-Not-Track; feature-flag server-wide disable.

## 11) Legal/ToS Summary

- 4th party; no content hosting.
- Client networking: Gardener connects from user device to third parties; IP/UA visible to them.
- Geo/ISP variability; show in-app notice where applicable; user must comply with local laws and third-party ToS.
- Flow-down obligations: third-party terms bind users when accessed via Gardener.
- Implied acceptance: using SeedSphere implies acceptance of SeedSphere ToS/Privacy Policy and applicable third-party terms.
- “As is”; no endorsement; no warranties.

## 12) Storage & Pruning (SQLite)

- Cap: 100k rows. Retain expired rows for 24h beyond `expires_at` for audits/metrics; never serve expired.
- Prune: delete `expires_at < now()-24h` and `stale = 1` in 2k–5k chunks with small yields.
- Schedule: nightly 03:00 UTC ±30m; skip under load; WAL checkpoint (TRUNCATE) afterwards; `ANALYZE` each prune; weekly `VACUUM`+`ANALYZE` Sunday 03:30 UTC when safe.
- Telemetry: pruned count, duration, chunk count, DB size; warn >20m or >1.5× median size.

## 13) TV Onboarding (QR)

- Prompt: “Pair your device to fetch results faster and privately. Scan the QR with your phone’s camera.”
- Alternatives: “Scan to pair this TV with your phone…”, “Pair with your phone to continue…”.
- Visuals: contrast ≥4:1 dark-on-light; quiet zone ≥4 modules; size 320–400 px on 1080p (module ≥6 px); error correction M/Q (H if center logo ≤30%).
- States: Generating → Active (countdown) → Expired (refresh) → Busy/limit (retry countdown).
- Fallbacks: short link + 6-char code under QR; Accessibility: high contrast, text alternative, focusable “Open link on phone.”

## 14) Unpairing UX (Gardener)

- Placement: `src/pages/Configure.vue` → “Account & Devices”. List paired devices (name, platform, last seen, health badge).
- Actions: per-row “Unpair” (destructive), global “Unpair all”.
- Confirm dialog: Title “Unpair this device?” Body “This will disconnect ‘<device_name>’…”. Buttons: “Unpair device” (destructive), “Cancel” (default focus). Focus trap; Esc/Enter; 4.5:1 contrast.
- Success: toast “Device unpaired” with Undo 10s (if reversible) or “Pair again” link. Empty state copy provided.
- Cross-device: SSE `pairing_update` to other devices; banner copy on others and on unpaired device upon foreground.
- Safeguards: re-auth for “Unpair all”; rate-limit unpair actions.

## 15) Entropy Strategy

- Local: Node.js `crypto.randomBytes` always present.
- External (enable ≥3): ANU QRNG, Random.org (API key), drand; optional Cloudflare Beacon v2.
- Selection: per-request pseudorandom choice seeded locally; per-source timeout ~800 ms; overall budget ~1.5 s.
- Mixing: HKDF-SHA256 over `[local || externals...]` in arrival order; proceed local-only if externals fail; record telemetry.
- Resilience: circuit breakers with 5–15m jittered cool-down; background pooling; never block past budget.

## 16) Proxy-on-Demand (Safety)

- When to proxy: DNS/TLS/connect errors; mixed-content blocked; timeouts (no headers in 4s or >10s cap); 5xx/520–526/408.
- Never proxy: 401, 403, 404, 409, 429, 451.
- Quota: 5 proxied tasks per device per rolling 24h; counted at first proxy attempt per `task_jti`.
- Backoff: if ≥3 proxied failures for a provider in 10m on a device, disable proxy for 30m for that device.
- Safety/telemetry: strip cookies, normalize UA, rate-limit proxy; log `{provider, status, trigger, proxied, duration_ms, quota_remaining}`.

## 17) Operational Plan

- Volume: mount `/app/server/data` for SQLite (see Fly config).
- Observability: structured logs for tasks/cache/ratelimits; client telemetry per Appendix D.
- Dashboards: per-bucket 429 rate; p95/p99 window usage; provider 5xx; cache hit/miss/stale; SSE disconnect spikes.
- Alerts: 429 thresholds; provider 5xx >2% (5m); SSE spikes > baseline + 3σ.

## 19) Cloudflare Edge (Worker/KV/Cache)

- Namespaces & responsibilities
  - Cache API (edge HTTP cache): provider GET responses; key = normalized absolute URL; honor Appendix C.2 TTLs.
  - KV: single binding `SEEDSPHERE_KV` with prefixes
    - `result`: normalized query → JSON blob when not suitable for Cache API
    - `quota`: per‑device proxy quota counters (24h TTL)
    - `backoff`: per device+provider backoff entries (30m TTL)

- Key format & TTLs
  - Key shape: `v1:<namespace>:<fields>`; if `<fields>` >256 chars, use `sha1(<fields>)` hex
    - Primary: `v1:<namespace>:<hash>`; optional shadow index `v1:<namespace>:idx:<fields>` → `<hash>` (TTL 1h)
  - Examples
    - Result: `v1:result:streams:<provider>:<norm_key>` (sha1 if long)
    - Quota: `v1:quota:device:<device_id>` TTL 24h rolling
    - Backoff: `v1:backoff:<device_id>:<provider>` TTL 30m
  - TTLs: Results per Appendix C.2; Quota 24h from last update; Backoff 30m from last failure window.

- Environment variables / bindings
  - Worker (wrangler.toml):
    - KV: `SEEDSPHERE_KV` → namespace `seedsphere_kv`
    - Vars: `ORIGIN_URL`, `FEATURE_PROXY_ON_DEMAND`, `FEATURE_CACHE_ONLY`, `TELEMETRY_URL`, `TELEMETRY_KEY`
  - Server (Fly.io): `CF_WORKER_URL`, `JWT_PUBLIC_KEY`, `RATE_LIMIT_*` (future tuning)

Note: Adopt Worker/KV/Cache from the start.

## 20) Roadmap

- Phase 1 (Vertical Slice)
  - DB tables for devices/installations/pairings/cache.
  - Endpoints: register, pair start/complete, rooms (SSE), tasks/request, tasks/result.
  - PWA skeleton with register, pair, Gardener toggle; one provider integration.
  - Deploy Cloudflare Worker/KV/Cache for results.

- Phase 2 (Platform reach)
  - Improve normalization/caching; add 2–3 providers; TV pairing UX polish.

- Phase 3 (Scaling)
  - Tune quotas/rate limits; global cache tuning; harden breaker logic.

- Phase 4 (Hardening)
  - Abuse protections, telemetry polish (opt‑out UX), optional Litestream→R2 backups.

## 21) Open Items to Revisit

- Finalize normalization constants aligned with Torrentio.
- Proxy‑on‑demand thresholds and quotas (tuning values).
- Pair code length vs UX; QR payload hints.
- Battery‑saver thresholds copy in UI.
- TV onboarding screens and recovery flows.

---
This document is authoritative for implementation. Track revisions via PRs and version in `docs/Gardener.md`.

## Appendix D: Telemetry Schema v1

### D.1 Principles

- No PII, no content (no titles, queries, magnets, provider URLs).
- Pseudonymous IDs: HMAC(SHA‑256) of `install_id`/`device_id` with server‑side secret rotated daily; store only HMACs.
- Minimal operational fields; allow sampling under load.
- Opt‑out enabled by default and surfaced; honor DNT.

### D.2 Common Fields

- `ts`: ISO8601
- `app_version`: PWA semver
- `executor_platform`: `{ os, browser, form: "pwa"|"standalone"|"browser" }`
- `install_id_hmac`?: string
- `device_id_hmac`?: string
- `trace_id`?: string
- `net`: `{ type?: "wifi"|"cellular"|"ethernet"|"unknown", downlink_mbps?: number }`

### D.3 Event Types and Fields

- `task_request`
  - `provider`: slug (Appendix C.1)
  - `timeout_ms`: number
  - `cache_mode`: `"cache_only"|"prefer_cache"|"bypass"`

- `task_result`
  - `provider`: slug
  - `duration_ms`: number
  - `cache`: `{ status: "hit"|"miss"|"stale", served_ttl_s?: number }`
  - `upstream_status`?: number (coarse buckets or exact for 5xx/520–526/408)
  - `count`: `{ results: number }`

- `proxy_attempt`
  - `provider`: slug
  - `trigger`: `"network_error"|"mixed_content"|"timeout_header"|"timeout_total"|"status_5xx"|"status_52x"|"status_408"`
  - `outcome`: `"ok"|"failed"|"quota_exhausted"|"backoff"`
  - `duration_ms`?: number
  - `quota_remaining`?: number

- `sse_connect`
  - `room_id_hmac`: HMAC of room_id
  - `reconnect_count`: number
  - `backoff_bucket`: `"active"|"idle"`

- `sse_disconnect`
  - `room_id_hmac`: string
  - `reason`: `"network"|"server"|"client"|"idle_prune"`

- `cache_serve`
  - `provider`: slug
  - `status`: `"hit"|"stale"`
  - `served_ttl_s`: number

### D.4 Sampling and Limits

- Default 100% collection; may sample to 10% via server flag during high load.
- Rate‑limit telemetry POSTs per device to avoid bursts.

## 18) Wiring Points (Repo Map)

- Greenhouse (server)
  - `server/index.js`: routing, SSE rooms, task dispatch (health selection), ratelimits, headers.
  - `server/lib/health.cjs`: scoring, RL metrics, gauges/histograms.
  - `server/lib/aggregate.cjs`: caching, SWR/Stale-If-Error, circuit breakers, headers.
  - `server/lib/db.cjs`: cache schema, pruning queries, stats tables.
  - `server/lib/crypto.cjs`: entropy fetchers and HKDF mix.
  - `server/providers/*.cjs`: provider adapters exposing status/latency.
  - `server/routes/pair.cjs` (to add): pair start/complete/list/unpair endpoints.
- Seedling (addon)
  - `server/addon.cjs`: integrate health hints and room handling; expose pairing deep link.
- Gardener (PWA)
  - `src/pages/Configure.vue`: Account & Devices, pairing QR, unpair actions.
  - `src/App.vue`: SSE banners (pairing updates, iOS suspend), global toasts.
  - `src/lib/auth.js` or `src/lib/api.js`: pairing/unpairing API.
  - `src/lib/qr.js` (new): QR generation with guidelines.
  - `src/lib/telemetry.js` (new or reuse `public/assets/app.js`): client metrics.

## Appendix A: Event Envelopes (SSE)

- Rooms events: `{type, room_id, ts, seq, payload, retry_after_ms?, task_jti?}`
- Types: `status`, `result`, `stale`, `pairing_update`, `pairing_prompt`, `error`
- Reconnects: active 1→2→4→8s (cap 15s), idle 5→10→20→40→60s (cap) with jitter; unlimited; prune room after 30m.

## Appendix B: Legal Summary (Locked)

- Gardener connects to third parties from user device; SeedSphere hosts no content.
- Geo/ISP notice may appear; user responsible for laws/ToS.
- Flow-down applies; use implies acceptance; “as is”; no endorsement.

## Appendix C: Tables

### C.1 Provider Slugs (v1)

- torrentio, anidex, eztv, yts, 1337x, magnetdl

### C.2 TTLs (Initial)

- torrentio 300s; eztv 300s; yts 600s; 1337x 300s; anidex 600s; magnetdl 300s
- Dynamic behavior: TTL floor 60–120s on degradation; SWR up to 10m; Stale-If-Error up to 30m.

### C.3 Cache/Storage Limits

- Max payload 256 KB; Memory LRU 5,000 keys; SQLite cap 100k rows; retention 24h beyond `expires_at`.

### C.4 TV Onboarding Copy

- As specified in §13, with alternatives and states.

### C.5 Entropy Sources

- As specified in §15.

### C.6 Deep-link Scheme

- `https://seedsphere.fly.dev/pair?code=...&install_id=...`

### C.7 Unpairing UX

- As specified in §14.

## Appendix J: Pre-implementation Decisions (Fully Expanded)

### J.1 Language Policy

- Flag selection
  - If a region is present, use that region’s flag (e.g., en-US → 🇺🇸; es-ES → 🇪🇸; pt-BR → 🇧🇷).
  - For generic codes (no region), use a single canonical flag per language for consistency:
    - en → 🇬🇧, es → 🇪🇸, pt → 🇵🇹, zh → 🇨🇳, fr → 🇫🇷, de → 🇩🇪, it → 🇮🇹.
- Display defaults
  - If languages are unspecified: languages_display = ["Multi"], languages_flags = ["🌐"].
- Names source
  - Use Unicode CLDR as the authoritative source for language and region display names.

### J.2 Machine-readable Mappings

- Location: `server/lib/mappings/`
  - `quality.json`: canonical qualities and alias arrays.
  - `editions.json`: canonical display strings and tolerant aliases.
  - `version_tags.json`: allowed tags with normalization notes.
  - `providers.json`: `{ slug, display, url }` list (aligned with Appendix C.1 and §8.2.3).
  - `languages.json`: common codes and display/flag policy hints; defer exhaustive coverage to CLDR at runtime.
- Policy
  - Mappings are authoritative for normalization (§8.2). Code must not diverge from these JSONs.

### J.3 API Specification

- File: `docs/openapi.yaml`
  - Endpoints: register, pair start/complete, SSE rooms, tasks/request, tasks/result, cache get.
  - Schemas: SSE envelope (Appendix A), normalized result (Natural schema §8.2), error object `{ code, message }`.
  - Headers: `RateLimit-*`, `Retry-After`, cache headers.
  - Security: JWT examples for executor/result, audience and expiry notes.

### J.4 Database Migrations

- Directory: `server/migrations/` with incremental `.sql` files.
- Coverage
  - Create schema for users, devices, installations, pairings, rooms, cache, audit (§5A).
  - Indices for frequent lookups (device_id, install_id, pair_code, cache_key, expires_at).
  - Prune/retention procedures per §12 (24h beyond `expires_at`).
- Runner
  - Boot-time migrator in Node: idempotent, logs applied version, fails fast on checksum mismatch.

### J.5 Secrets and Environment

- `.env.example` (repo root)
  - `AUTH_JWT_SECRET`, `CF_WORKER_URL`, `RATE_LIMIT_*`, `TELEMETRY_URL`, `TELEMETRY_KEY`, `DB_PATH`.
- Practices
  - Document rotation policy for JWT secret and small clock-skew tolerance.
  - Keep production secrets in Fly/Worker configs; never commit real secrets.

### J.6 Normalization Module

- File: `server/lib/normalize.cjs`
  - Implements Natural schema (§8.2) using mapping JSONs.
  - Validates and uppercases 40-hex infohash.
  - Extracts title/year/edition/remaster/version_tag/quality/languages/provider.
- Tests: `server/lib/__tests__/normalize.test.cjs`
  - Use Node’s `node:test` runner.
  - Include the worked example from §8.2.2 and edge cases (no year, multiple tags, unknown aliases).

### J.7 Pairing Routes and Limits

- File: `server/routes/pair.cjs`
  - POST `/api/pair/start`: body `{ install_id }` → `{ pair_code, room_id, expires_at }`.
  - POST `/api/pair/complete`: body `{ pair_code, device_id }` → `{ ok, room_id }`.
- Limits
  - Enforce per-IP and per-install limits/cooldowns per §5B.
  - Return 429 with `Retry-After` on limit; include backoff hints.

### J.8 SSE Rooms

- Implementation in `server/index.js`
  - SSE endpoint `/api/rooms/:room_id/events` emits envelopes from Appendix A.
  - Reconnect/backoff schedules (active vs idle), prune after 30 minutes idle.
- Testing
  - Integration test validating reconnect timing and envelope integrity.

### J.9 Gardener Health Selection

- Logic in `server/lib/health.cjs`
  - Score based on latency, success rate, SSE jitter/RTT, availability, and heartbeat staleness (§6).
  - Hysteresis: require ≥5-point delta to switch; apply failure penalties.
- Observability
  - Gauges/counters for selection decisions; hashed IDs only.

### J.10 Cloudflare Worker/KV/Cache

- Directory: `worker/` with `wrangler.toml`.
- Namespaces
  - `SEEDSPHERE_KV` with prefixes `result`, `quota`, `backoff` per §19.
- Config
  - Vars: `ORIGIN_URL`, `FEATURE_PROXY_ON_DEMAND`, `FEATURE_CACHE_ONLY`, `TELEMETRY_URL`, `TELEMETRY_KEY`.
- Key formats and TTLs
  - Follow §19 key shapes and TTLs; hash long keys.

### J.11 Telemetry

- Server collector route per Appendix D.
- Client library `src/lib/telemetry.js` with opt-out setting surfaced on first run.
- Sampling and rate limits as in Appendix D.4.

### J.12 Tooling and CI

- Python-specific tooling (Pipenv, Ruff) deferred until Python code exists per project rules.
- Keep current GitHub Actions; consider adding markdownlint later.
