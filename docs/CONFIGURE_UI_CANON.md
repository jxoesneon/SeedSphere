# SeedSphere Configure UI Canon

Date: 2025-09-05 18:58:44-06:00
Scope: `src/pages/Configure.vue` only (full inventory + Basic/Advanced tagging + gaps for advanced users)

## Goals

- Provide a single source of truth listing every element on the Configure page so we do not lose anything during the revamp.
- Tag each element as Basic or Advanced (progressive disclosure). Advanced options live inside collapsible groups with clear dividers.
- Capture missing advanced customization ideas aligned with SeedSphere’s purpose (augment bitTorrent magnets with trackers, provider orchestration, AI descriptions, optimization and sweep tooling).
- Define 2025-forward UI/UX guard-rails for the revamp: collapsible cards, responsive grid sizing in discrete viewport-based increments, dynamic heights, accessible interactions.

## Audience and Design Tenets (2025)

- Curiosity-first newcomers: “just works” defaults; minimal surface at first glance.
- Power users: comprehensive control surfaces, tucked into collapsible Advanced groups.
- No separate Basic/Advanced view switch. Use progressive disclosure inside each card.
- Collapsible everything: every card is a `<details>` with a `<summary>`.
- Consistency: DaisyUI + Tailwind; tooltips with global 4s hover delay; strong keyboard support; semantic labels.

## Global Conventions

- Tooltips: DaisyUI `tooltip` + `data-tip`, with accessible `title` when appropriate. 4s hover delay per `src/assets/main.css`.
- Collapse pattern: native `<details>/<summary>` for accessibility. Divider sections inside Advanced blocks when many controls.
- Toggles vs Pills: up to 3 adjacent toggles is fine; 4 or more related binary settings should become pill/segmented controls.
- Card widths: discrete increments based on viewport width.
  - 1/1 (full viewport width) for very wide content.
  - 1/2 for standard controls (two side-by-side on desktop).
  - 1/4 for compact controls (four across, or pair with one 1/2 and two 1/4).
- Card height: always dynamic (auto) based on visible content; grows or shrinks as collapses open/close.

## Inventory and Tagging (Basic/Advanced)

Source: `src/pages/Configure.vue`

### 1) Install (Hero header)

- Basic: Install / Update button (link to `manifestProtocol`).
- Basic: Home button (router link).
- Advanced (Missing): "Copy manifest URL" quick action; show current backend version and addon version; optional variant preview text.

### 2) Toast notifications

- Basic: Single toast message region (`toastMsg`, `toastType`).

### 3) Update banner

- Basic: Update available text.
- Basic: Install (link) and Dismiss (button).
- Advanced (Missing): “Release notes” link; “Remind me later” snooze; “Auto check for updates” toggle.

### 4) Quick Navigation (tabs)

- Basic: Anchored tabs for all sections. “Upstream” tab scrolls to Preferences since Upstream Proxy is merged there.
- Advanced (Missing): Horizontally scroll hint on small screens; “Collapse/Expand all cards” global control.

### 5) Recent Boosts (Telemetry)

- Basic: SSE status dot; boosts table (time, type, id, title, healthy, total, mode).
- Advanced (Missing): Pause/resume live stream; filter by type; retention length; export CSV/JSON; autosize columns; copy row; clear buffer; reconnection backoff config; cap max rows; keyboard navigation within table.

### 6) Upstream Proxy (merged into Preferences)

- Basic: Status text and explanation shown within Preferences, next to the Upstream auto‑proxy toggle.
- Advanced (Missing): Per-provider auto-proxy override; max trackers appended per stream; append mode policy (prepend/append/replace); dedupe strategy.

### 7) Preferences

- Basic: Upstream auto-proxy toggle (`autoProxy`).
- Advanced (Missing): “Max trackers per stream” number; “Only add if magnet has `<N>` trackers”; “Prefer encrypted trackers” toggle; “Normalize to https when possible” toggle.

### 8) Descriptions

- Basic: Append original provider description (`descAppendOriginal`).
- Basic: Use original description when details not parsed (`descRequireDetails`).
- Advanced: “Now with AI” pill reveals an Advanced AI subsection with core AI controls (Enable, Provider, Model/Deployment) and a Manage Keys shortcut.
- Advanced (Missing): Language selection; maximum characters; include technical metadata (codec, size) in generated copy; styling presets (concise, narrative, bullet); media-type specific rules (movie vs episode).

### 9) AI Descriptions

- Basic: Full management UI: Enable AI; mode presets (fast/balanced/rich); provider select; model/deployment select; timeout; cache TTL; provider key management; login overlay.
- Advanced (Missing): Temperature/top_p; max tokens; stop sequences; streaming output toggle; fallback provider chain; cost preview; rate limit per minute; safe content filter; per-title caching controls; language override; redact PII toggle; retry/backoff policy; parallelism cap per request.

### 10) Credentialed Providers (Local)

- Torznab (Jackett/Prowlarr)
  - Basic: Enable; list endpoints; add/test/remove; url + api key inputs; test status.
  - Advanced (Missing): Per-endpoint weight; retry policy; rate limit; caps categories mapping; request timeout; backoff; max results; filters (categories, min seeders); query templating; header overrides.
- Real-Debrid
  - Basic: Enable; API token input.
  - Advanced (Missing): Rate limit; concurrency; domain whitelist; prefer cached; fallback order with AllDebrid.
- AllDebrid
  - Basic: Enable; API key input.
  - Advanced (Missing): Same as Real-Debrid; success thresholds; error budget.
- Orion
  - Basic: Enable; API key; user id.
  - Advanced (Missing): Request timeout; domain allowlist; preferred providers for Orion; logging verbosity.

### 11) Tracker Sources

- Basic: Variant select; custom trackers URL input; Validate button; preset buttons; validation result alert.
- Advanced (Missing): Auto-refresh schedule; merge policy with NGO list; protocol filters (udp/http/https/ws/i2p); dedupe + normalization (case, trailing slash, announce path); TLD filters; IP-only toggle; “drop non-routable” toggle; bad tracker blacklist; backup URL if primary fails; cache TTL for fetched list.

### 12) Detected Providers

- Basic: Refresh; provider groups; enable/disable provider pill buttons with availability indicator.
- Advanced (Missing): Per-provider priority weight; auto-disable on error threshold; per-provider timeout override; grouping preferences; show last probe time; “disable unavailable” bulk action; pin favorites.

### 13) Stream Sorting

- Basic: Order toggle (asc/desc); drag-reorder selected criteria; reset; add/remove chips; select all; clear.
- Advanced (Missing): Per-field ascending/descending; field weights; different presets per content type (movies vs series); custom comparator pattern; pin provider; duplicate demotion rules; tie-breakers sequence editor.

### 14) Optimization

- Basic: Validation mode (off/basic/aggressive); health cache check (metrics + advanced copy diagnostics); probe upstream providers; probe timeout; provider fetch timeout; swarm enable + top N + missing only + timeout; Quick sweep (with progress + advanced copy diagnostics); boosts metrics; recent boosts with refresh.
- Advanced: Health cache diagnostics copy implemented via collapsible group; additional controls remain planned (Health cache TTL; revalidation cadence; DNS resolution strategy; concurrency caps; per-provider fetch timeouts; jitter; circuit breaker; error budget; sampling rate; swarm backoff strategy; partial results threshold; telemetry verbosity).

### 15) Sweep Tools

- Basic: Sweep; Validate; Quick sweep; Download merged; streaming progress; final stats; merged and filtered downloads; filtered preview (copy and download).
- Advanced: Diagnostics copy implemented via collapsible group; additional controls remain planned (Concurrency parameter; limit sample size; server-side sweep toggle; save sweep profile; schedule sweep; log level; export JSON result with health reasoning; resume partial; include dedupe and normalization options).

### 16) Allow / Block Lists

- Basic: Allowlist textarea; Blocklist textarea; Apply button.
- Advanced (Missing): Wildcards and regex; comment lines `#`; import/export lists; test rule on sample host; priority between allow vs block; shared presets; normalization (strip protocol, lower-case, trim trailing slash); copy canonicalized preview; cloud sync via account; rule groups with labels.

### 17) Manual Trackers

- Basic: Add a tracker (input + add button); table of trackers with edit and remove; strict validation toggle; sweep merge (append/replace); auto-save after sweep; import/export; save/revert/cancel.
- Advanced: Collapsible Advanced group implemented (strict validation, merge mode, auto-save, import/export in one place). Additional features remain planned (Bulk paste; dedupe; sort; validate selection; normalize schemes; annotate sources/labels; staged vs saved diff viewer; undo history; per-row comment; grouping; tagging; partial enable/disable per row; per-row last validated status).

### 18) Steps and About

- Basic: Usage steps; About text.
- Advanced (Missing): Current server version; build metadata; license; privacy/telemetry link; data retention note; links to docs and FAQ.

## Layout and Responsive Grid Rules

- Use a responsive grid that composes only 1/1, 1/2, 1/4 width cards at desktop breakpoints.
  - 1/1: Telemetry table, Sweep streaming, dense configuration groups.
  - 1/2: Most cards (Tracker Sources, Detected Providers, Sorting, Optimization, Allow/Block, Manual Trackers, AI Descriptions).
  - 1/4: Small status and quick actions (Update banner, tiny utility cards if we split), or sub-cards nested inside a 1/2 container.
- Card height: always dynamic (auto) based on visible content; grows or shrinks as collapses open/close.
- Avoid masonry; prefer consistent rows for scanning.

### Assigned card widths (md col spans)

- 1/1 (md:col-span-12): `Recent Boosts` (Telemetry), `Steps and About` wrapper (two internal columns).
- 1/2 (md:col-span-6): `AI Descriptions`, `Credentialed Providers (Local)`, `Tracker Sources`, `Detected Providers`, `Stream Sorting`, `Optimization`, `Sweep Tools`, `Allow / Block Lists`, `Manual Trackers`.
- 1/4 (md:col-span-3): `Preferences`, `Descriptions`.

## Accessibility and Interaction

- Follow WCAG 2.2 Content on Hover/Focus (1.4.13) for tooltips and hover content; ensure hoverable and dismissible behavior.
- `<details>/<summary>`: keyboard-accessible toggling; summary clearly labeled; do not replace with custom divs.
- All inputs labeled via `<label>` or `aria-label`; ensure `for`/`id` binding or wrapping label pattern.
- Maintain focus rings and focus order within collapsible regions.

## 2025-forward References (selected)

- NN/g: Progressive Disclosure — defers complexity, reduces error risk.
- IxDF: Progressive Disclosure — simplify interfaces.
- UXPin + Mouseflow: Dashboard and SaaS best practices — progressive disclosure and grouping.
- W3C APG: Tooltip pattern; WCAG 1.4.13 Content on Hover/Focus.
- Material 3: Cards guidance; Inclusive Components: Cards; Berkeley DAP: Accessible cards.

## Implementation Notes for the Revamp

- Keep element redesigns minimal; move elements into their most related card; add Advanced collapses and dividers.
- Convert clusters of 4+ binary toggles into segmented pill controls.
- Add missing Advanced groups per section (as listed) but hide behind collapsible details.
- Apply consistent DaisyUI components and spacing; ensure tab order remains logical when collapses are closed/open.
- Consider microcopy improvements for explanations; all actions have tooltips.

## Next Steps (work plan)

1) Add Advanced sub-sections with `<details>` inside each major card; move existing advanced-like controls into them.
2) Implement segmented pill controls where 4+ toggles appear in a row.
3) Normalize card widths to 1/1, 1/2, 1/4 at md+ breakpoints; test stacking order on sm.
4) Introduce missing Advanced options iteratively (section-by-section), gated behind Advanced collapses.
5) Preserve current functionality; do not regress.
6) Accessibility QA (keyboard navigation, focus rings, tooltip behavior with 4s delay, `<summary>` discoverability).
7) Visual QA in light/dark themes; verify discrete widths feel balanced.
8) Usability test with basic and advanced flows.

## Tagging Legend

- Basic: Visible by default within the card; essential for common flows.
- Advanced: Hidden in an Advanced collapse; power-user controls; safe defaults when untouched.

---
Document owner: Engineering
File: `docs/CONFIGURE_UI_CANON.md`
Source file: `src/pages/Configure.vue`
