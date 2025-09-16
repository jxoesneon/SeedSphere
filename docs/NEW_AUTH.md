# SeedSphere Auth v2 (1.1.0)

Status: Draft for dev-1.1.0
Date: 2025-09-08
Owner: Auth/Gardener/Seedling WG

## Summary (Paradigm Shift)

- Login is required for all meaningful interactions, including installing the addon (seedling) and accessing the site beyond marketing info.
- The server (Greenhouse) persists users, gardeners, seedlings; correlates incoming seedling traffic to a healthy gardener (selection by health/load).
- The addon operates with a per-install identity (`seedling_id`), and routes are per-seedling.
- Manifest declares configuration is required, and routes users to the onboarding page `/#/start`.
- The Gardener PWA (executor) is the data-plane: it performs tracker traffic; the Greenhouse orchestrates and returns results back to seedlings.
- After linking the seedling to the account, users are guided to install the Gardener PWA executor.

## Definitions

- **Greenhouse**: Central backend (this repository's server) that stores user/gardener/seedling entities and routes requests.
- **Gardener (PWA executor)**: PWA installed on a user device that performs tracker fetches. Multiple gardeners can exist per user.
- **Seedling (Addon)**: Stremio addon "installation"; each seedling has a unique identity used by Stremio to request addon endpoints.

## Goals

- **Require authentication** to initiate Install flow and to access any authenticated pages.
- **Per-seedling routing** so each install is addressable and correlatable.
- **Option A security model** adapted to Stremio constraints (see below).
- **Simple UX**: `/start` onboarding, streamlined homepage, analytics surfaced from Greenhouse.

## Non-Goals (for 1.1.0)

- Microsoft/Apple OAuth (can revisit later; optional FB stubs only if trivial).
- Token rotation for seedlings without reinstall (Stremio manifest caching constraints).

---

## Finalized Decisions

- Auth enforcement
  - Login required for all non-marketing interactions, including Install.
  - Seedlings retain access regardless of website logout (no token revocation on web logout).

- Routing and security
  - Per-seedling URL prefix: `/s/:seedling_id/:sk` (Option A path-secret).
  - `sk` is 128-bit random, base64url (unpadded, ~22 chars). Stored only as `SHA-256(salt || sk)` with per-seedling 16-byte salt. Constant-time compare.
  - All logs must mask `sk` as a fixed placeholder (e.g., `sk=xxxxx`).

- Manifest
  - `id` is constant: `community.SeedSphere`.
  - `version` tracks release (e.g., `1.1.0-dev.0`).
  - Keep `config` array and `behaviorHints.configurable: true`.
  - Strip `stremioAddonsConfig` wherever we serve dynamic manifests.
  - Serve dynamic manifest at `/s/:seedling_id/:sk/manifest.json` and place SDK router under the same prefix.

- Manifest personalization
  - Dynamic manifest includes `seedsphere: { seedling_id, config_scope: 'seedling' }`.
  - Server pre-fills `config[].default` using stored per-seedling defaults.
  - Store Stremio `extras` from requests server-side and reuse them as future defaults when regenerating the manifest.

- Root `/manifest.json`
  - When fetched by Stremio without seedling context, attempt to look up a recently minted seedling from the current authenticated session and return its per-seedling manifest directly (no redirect), to avoid caching a root link.
  - If no seedling is available or when opened in a browser, redirect to `/#/start`.
  - Recently minted window: 10 minutes by default (configurable via `RECENT_SEEDLING_WINDOW_MS`).

- Gardener selection and health
  - Server selects a healthy Gardener per request based on a scoreboard (recent heartbeat, low error rate, round-robin).
  - Heartbeat fields: `queue`, `success_1m`, `fail_1m`, optional `healthscore` in [0.0, 1.0].
  - Server derives rolling health/error rates and audits ~1/10 samples to validate PWA-reported healthscore. Sampling ratio is configurable via env.

- Active caches (180 minutes)
  - In-memory TTL caches with 180-minute TTL for active users, gardeners, seedlings.
  - LRU cap of 50k entries per cache to control memory.
  - Use caches to maintain ephemeral associations; no DB binding of gardener↔seedling.

- Limits and caps
  - Soft cap: at most 20 seedlings per user by default (configurable via `MAX_SEEDLINGS_PER_USER`).
  - Rotation of `sk` requires reinstall.

- Device fingerprint (analytics)
  - Deterministic hash over `user-agent`, `accept-language`, and coarse IP bucket (/24 IPv4, /64 IPv6). X-Forwarded-For aware.

- UI/UX
  - Homepage simplified; Install is login-first; analytics tiles with 5-minute updates (SSE optional for realtime).
  - Remove Live Boost from homepage.
  - New `/#/start` page with blocking login modal and auto-dismiss on success.
  - Remove Activity from navbar and disable deep linking (keep code in repo for future).
  - Remove Configure and Pair pages (flow replaced by login-first Install and Start onboarding).
  - Replace “Theme” with HeroIcons outline palette icon; audit to ensure HeroIcons-only.
  - Developer-only controls in `Home.vue` remain gated behind `?dev=1` (manifest variant dropdown and variant Install/Update button).
  - Install action triggers `stremio://` deep link to the per-seedling manifest URL.

- Domains and dynamic origin
  - Production: `https://seedsphere.fly.dev`.
  - Dev: `https://seedsphere-dev.fly.dev`.
  - Use `baseUrl(req)` to compute absolute asset URLs and configuration targets.
  - For `Origin` of `https://web.strem.io` or `https://web.stremio.com`, force asset base to `https://seedsphere.fly.dev` to avoid mixed-content.

- Schema and storage
  - No separate migration files; override/ensure-tables logic will extend schemas as needed (e.g., add `gardeners`, extend `installations` with `key_hash`, `salt`, `status`, optionally `config_json`).

- Signed manifest reference
  - Keep `server/manifest.signed.json` as a reference file only; dynamic manifests remove signatures.

## Security Model (Option A — confirmed)

Given Stremio calls addon endpoints using only the URLs provided in the manifest and we cannot reliably inject custom headers, the per-seedling shared secret is carried within the URL path itself.

- **Seedling Key (sk)**: A random, high-entropy secret generated at install time.
  - Stored hashed in DB on the server.
  - Embedded once in all addon URLs as a path segment.
  - Rotation requires reinstall.

- **Authentication Mechanism**: The Greenhouse authenticates seedling requests by validating:
  - `seedling_id` exists and is active, and
  - `sk` path segment hashes to the stored `key_hash` for that seedling.
  - Website logout does NOT revoke seedling access; seedlings retain access and continue to be routed server-side.

- **URL Form** (example):
  - Base prefix: `/s/:seedling_id/:sk`
  - Manifest: `/s/:seedling_id/:sk/manifest.json`
  - Other addon endpoints follow the same prefix: `/s/:seedling_id/:sk/<addon-routes...>`

- **Revocation**:
  - Mark seedling inactive or rotate `key_hash` (reinstall required for new `sk`).

Rationale: This preserves Option A's per-install secret while complying with Stremio's URL-only control. It is equivalent to a bearer token in path, with server-side hashing and no headers.

---

## Data Model

Existing in `server/migrations/0001_initial.sql`:

- `users(id, provider, email, created_at)`
- `sessions(sid, user_id, created_at, expires_at)`
- `devices(device_id, user_id, agent, last_seen, created_at)`
- `installations(install_id, user_id, platform, created_at, last_seen)` (we will treat this as seedlings)
- `pairings(...)` (deprecated in 1.1.0)

New/extended (no data migration needed as there are no active users):

- `gardeners` (NEW)
  - `gardener_id TEXT PRIMARY KEY`
  - `user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE`
  - `label TEXT`
  - `created_at INTEGER`
  - Index: `gardeners_user (user_id)`

- `gardener_seedlings` (NEW) — if we need many-to-many; otherwise bind directly on `installations`
  - `gardener_id TEXT REFERENCES gardeners(gardener_id)`
  - `seedling_id TEXT REFERENCES installations(install_id)`
  - `created_at INTEGER`
  - Primary key `(gardener_id, seedling_id)`

- `installations` (EXTEND)
  - Add `key_hash TEXT` (hash of `sk`)
  - Add `status TEXT` (e.g., `active`, `revoked`)
  - Ensure index on `(user_id)` exists

- `devices` (EXTEND)
  - Treat `device_id` as Stremio device fingerprint for analytics; add indices as needed.

Planned migration: `server/migrations/0003_auth_v2.sql`

---

## Routing & Endpoints

- **Per-Seedling Mount**: Mount a router at `/s/:seedling_id/:sk`.
  - Auth middleware validates `seedling_id` and `sk` → loads user context → chooses a healthy gardener for fulfillment.

- **Manifest**: `GET /s/:seedling_id/:sk/manifest.json`
  - `configurationRequired: true`
  - `configuration: "{baseUrl}/#/start?sid={seedling_id}"` (computed using `baseUrl(req)` to support dev/prod domains)
  - `id`: constant (keep `community.SeedSphere`)
  - `version`: linked to release version (e.g., `1.1.0-dev.0`)

- **Addon endpoints** (example structure — adapt to current addon capability):
  - `/s/:seedling_id/:sk/stream/:type/:id.json` (current Stremio resource: `stream` only)
  - Any SeedSphere-specific endpoints (e.g., analytics) should also live under this prefix.

- **Dev-only endpoints**
  - Legacy `manifest.variant.*` endpoints are retained for internal testing and are visible only when the homepage is opened with `?dev=1`. These will be deprecated after per-seedling flow fully ships.

- **Internal API** (authenticated website session):
  - `POST /api/seedlings` → creates a new seedling (returns `seedling_id` and `sk` and the ready-to-use addon URL)
  - `POST /api/gardeners` → create default gardener if missing
  - `GET /api/analytics/tracker-health` → 5-minute aggregated metrics from Greenhouse

---

## Flows

### A) Login-First Install (homepage Install)
1. If `auth.state.user == null`, show login modal.
2. On success, call `POST /api/seedlings` → server creates `{ seedling_id, sk, addonUrl }` and persists `installations`
3. Client triggers `stremio://{addonUrl}`
4. Seedling is bound to the user; Greenhouse selects a healthy gardener on each request.

### B) Manifest Configuration Flow
1. Manifest includes `configurationRequired: true` and links to `/#/start?sid={seedling_id}`
2. `/#/start` shows login modal if needed; on success, shows success then auto-dismiss
3. Server binds `seedling_id` → user; ensures default gardener exists
4. CTA: Go to `/#/activity` (scoped to user/gardener) or manage gardeners

### C) Gardener PWA Onboarding
1. After binding the seedling, guide the user to install the Gardener PWA
2. The PWA registers itself to the user (creates `gardener_id`) and periodically reports health
3. Greenhouse routes seedling requests to a healthy gardener (server-determined per request based on health)

---

## Frontend UX Changes

- **Homepage**: Simplify; keep Install & Utilities with the new login-first flow. Remove Live Boost. Show tracker health analytics (from Greenhouse) refreshed every 5 minutes.
- **Routes**: Keep `/#/activity` route available (repurposed for Gardener content later) but remove it from the homepage navigation. Remove `/#/configure` and pairing pages.
- **Theme**: Replace the word "Theme" with a color palette icon. Keep dropdown behavior. Login button uses primary color.
- **Start Page**: New `src/pages/Start.vue` with blocking login modal; success auto-dismiss pattern.
- **Route Guards**: Enforce login for Install and Start (post-enter). If `/#/activity` resurfaces later, apply the same gate.

---

## Operational

- **Domains**: Production `https://seedsphere.fly.dev`; Dev `https://seedsphere-dev.fly.dev`. Manifest `configuration` and base URLs computed via `baseUrl(req)`.
- **Secrets**: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `AUTH_JWT_SECRET`, mailer creds for Magic Link. FB stubs deferred.
- **Caching**: Accept that Stremio caches the manifest; rotation requires reinstall.

### Google OAuth setup (dev and prod)

Add the following in Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client IDs → Your client → Edit:

- Authorized redirect URIs:
  - `http://localhost:8080/api/auth/google/callback`
  - `http://127.0.0.1:8080/api/auth/google/callback`
  - `http://localhost:5173/api/auth/google/callback`
  - `https://seedsphere.fly.dev/api/auth/google/callback`

- Authorized JavaScript origins:
  - `http://localhost:8080`
  - `http://127.0.0.1:8080`
  - `http://localhost:5173`
  - `https://seedsphere.fly.dev`

Environment variables (set in `.env.local` for development):

```bash
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
```

The dev server loads `.env.local` automatically (via `node -r dotenv/config`) when running `npm run dev`. Restart the server after changes.

Troubleshooting:

- Error 400 `redirect_uri_mismatch`: ensure the exact host you are using (e.g., `127.0.0.1` vs `localhost`) is present in your Google configuration.
- Error 400 `invalid_request` / `Missing required parameter: client_id`: verify the server is picking up env vars and that you restarted after editing `.env.local`. Check `GET /api/auth/google/status` for `configured: true`.

## Gardener Selection (Health-based)

- Maintain a health table or in-memory scoreboard updated by PWA heartbeats.
- Selection strategy (example): prefer gardeners with recent heartbeat (< 60s), lowest error rate, then round-robin.
- Fallback if none healthy: 503 with guidance to install or wake a Gardener PWA.

## Active Entity Cache (180 minutes)

- Maintain an in-memory TTL cache (180 minutes) for active users, gardeners, and seedlings.
- Use this cache to keep ephemeral associations between seedlings and gardeners without persisting explicit bindings in the database.
- On each request, refresh TTL for the relevant entries.

---

## Open Items / Questions

1. **Manifest `id` per release**: You requested linking `id` to release version. Please confirm you accept the trade-off that each release appears as a new addon in Stremio (fresh install required), and specify the exact `id` format you prefer (e.g., `seedsphere.addon@1.1.0`).
2. **Gardener association**: Since the server dynamically selects a healthy gardener, do we need the `gardener_seedlings` join, or is a simple `gardeners` table plus server-side selection sufficient (no explicit binding)?
3. **Per-seedling URL secret**: We will use `/s/:seedling_id/:sk/...` for all addon routes. Confirm path layout for current addon endpoints (catalog/stream/etc.).
4. **Revocation UX**: If a seedling is compromised, we can revoke it server-side; the user would reinstall. Do you want a UI to manage/revoke seedlings on the website?
5. **Analytics cadence**: We will refresh every 5 minutes. Would you like browser-side SSE for immediate updates, or stick to polling?
6. **Schema approach**: You prefer no migration files and overriding old schemas. I will update the initial schema definition (and the startup ensure-tables logic) rather than adding `0003_auth_v2.sql`. Confirm this approach is acceptable for both dev and prod environments.

## Seedling Secret Details (finalized defaults)

- `sk` length/encoding: 128-bit random → base64url (unpadded) → 22 chars, compact and URL-safe.
- Hashing: SHA-256 of `salt || sk` with per-seedling 16-byte random salt; constant-time compare; minimal CPU.
- Logging: Never log real `sk`; always log masked placeholder, for example `sk=xxxxx`.

---

## Next Steps (when authorized)

- Update DB init ensure-tables logic to add `gardeners` and extend `installations` with `key_hash` and `status` (override old schemas; no separate migration file).
- Implement per-seedling mount and auth middleware at `/s/:seedling_id/:sk`.
- Implement `POST /api/seedlings` and UI wiring in `Home.vue` and new `Start.vue`.
- Add route guards and UX updates (palette icon, login primary button, remove pages).
- Implement Greenhouse → Gardener dispatch with health-based selection; aggregate tracker analytics for the homepage.
