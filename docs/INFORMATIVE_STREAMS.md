# Informative (Fallback) Streams

SeedSphere guarantees the addon returns at least one stream entry for every request.
When no playable streams are available (due to provider timeouts, zero results, or account/setup issues), the addon emits an "informative" stream that explains why and what to do.

These streams are non-playable. They appear in Stremio as a single row with a clear reason and next steps, so users never see an empty list without context.

## When a fallback stream is emitted

- Providers list is empty (all providers disabled).
- Providers are unreachable when probing is enabled.
- Provider requests errored or returned unexpected data.
- Providers returned successfully but with zero streams.
- Trackers list is empty (no trackers configured or fetch failed), and no providers yielded results.
- Stream bridge exhausted retry budgets (global timeout), e.g., Gardener not responding fast enough.

## Reason codes and meanings

- no_providers_enabled — No providers are enabled in configuration.
- providers_unreachable — All configured providers failed probe checks within the probe timeout.
- providers_zero_results — Providers responded successfully but returned zero streams.
- providers_error — One or more providers returned an error or invalid payload.
- providers_request_failed — One or more provider requests failed to execute (e.g., network errors).
- trackers_list_empty — No trackers are configured; change variant or provide a custom trackers URL.
- global_timeout — The stream bridge exceeded its retry/time budget.
- no_results — Generic fallback when none of the more specific conditions apply.

Additional scenarios you may see in the future (not all are currently auto-detected by the server):

- account_missing_key:<provider> — Required key is missing.
- account_invalid_key:<provider> — Saved key rejected or invalid format.
- account_banned — Account has been banned; contact support.
- seedling_revoked — Your installation was revoked; reinstall from Home.
- filters_excluded_all — Local filters (allow/block, language) excluded all candidates.
- unsupported_type — Title type is not supported by the addon.

## What the informative stream contains

- name: SeedSphere
- title: short message, e.g., "No providers enabled — Configure SeedSphere"
- description: multi-line details with the reason, provider/timeouts summary, trackers count, and a short action hint
- behaviorHints: contains `bingeGroup: "seedsphere-info"`

Note: the fallback stream does not include `url` or `infoHash` to ensure Stremio does not attempt playback.

## Where it is implemented

- `server/lib/aggregate.cjs`
  - Exports `buildInformativeStream()` used to construct informative streams.
  - `aggregateStreams()` now returns a fallback informative stream when upstream providers produce no results or are unreachable.
- `server/addon.cjs`
  - The addon’s `defineStreamHandler()` uses `aggregateStreams()`. It returns the aggregator’s result directly; since the aggregator now guarantees a fallback, the addon always returns at least one stream.
- `server/index.js` (stream bridge)
  - The `/api/stream/:type/:id` endpoint returns an informative stream when all retry budgets are exhausted.
  - The per‑seedling SDK validator also emits informative streams when the installation is missing, revoked, or has an invalid signature.
  - Diagnostics and metrics endpoints (see below) are also defined here.

## Configure link

The informative stream description includes a "Configure:" line pointing to the app’s Configure page. When a seedling context is available on the server (via request context), the link is scoped with `?seedling_id=...`.

## Diagnostics and troubleshooting

To understand “why no streams?” for a specific installation, use the diagnostics API and the built‑in Configure panel.

### API: Recent fallback reasons

`GET /api/diagnostics/fallbacks`

Query parameters:

- `seedling_id` (optional) — filters to a specific installation.
- `gardener_id` (optional) — filters to a specific device/browser.
- `limit` (optional, default 10, max 50) — number of items to return.
- `minutes` (optional, default 1440) — time window to consider.

Response:

```json
{
  "ok": true,
  "items": [
    { "at": 1726000000000, "reason": "providers_unreachable", "where": "aggregate", "seedling_id": "abc", "gardener_id": "g-..." }
  ]
}
```

Example:

```sh
curl 'http://127.0.0.1:8080/api/diagnostics/fallbacks?seedling_id=YOUR_SEEDLING&limit=10'
```

### UI: Configure diagnostics panel

- The `Configure` page (`src/pages/Configure.vue`) includes a “Why no streams? (Diagnostics)” panel.
- It fetches from `/api/diagnostics/fallbacks` and lists the recent reasons and timestamps for the current context.

## Admin metrics (fallback reasons)

Admins can view aggregated fallback reasons over a recent window for system‑wide monitoring.

`GET /api/admin/metrics/fallbacks?minutes=60`

Response:

```json
{
  "ok": true,
  "minutes": 60,
  "reasons": {
    "providers_unreachable": 12,
    "no_providers_enabled": 4,
    "global_timeout": 2
  }
}
```

UI:

- The `Admin` page (`src/pages/Admin.vue`) shows a “Fallback reasons” card with a selectable time window.

## Performance knobs

You can tune provider probing and request concurrency/timeouts. These map to `aggregateStreams()` options and can be exercised via the `Executor` page or programmatically:

- `probe_providers` (`on`|`off`) — whether to probe providers before fetching.
- `probe_timeout_ms` (number) — timeout for probe checks.
- `provider_fetch_timeout_ms` (number) — per‑provider fetch timeout.
- `max_provider_concurrency` (number) — max number of providers fetched in parallel.

Example payload sent to `/api/stream/:type/:id` (internally by the Executor page or by clients):

```json
{
  "filters": {
    "probe_providers": "on",
    "probe_timeout_ms": 600,
    "provider_fetch_timeout_ms": 3000,
    "max_provider_concurrency": 4
  }
}
```

### Forcing an informative fallback (for testing)

- Open `/executor` and toggle “Force fallback”.
- This disables all providers and sets tiny timeouts, so the response returns a single informative stream.

## Testing

Node tests validate that `aggregateStreams()` returns at least one stream when:

- there are no providers enabled;
- providers return zero results;
- providers error out.

Run tests:

```sh
npm test
```

Playwright E2E tests:

```sh
npm run dev &  # in one terminal
npm run test:e2e  # in another terminal
```
