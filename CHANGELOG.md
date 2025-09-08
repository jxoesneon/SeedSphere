# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to semantic versioning.

## [1.0.1] - 2025-09-08

### Added

- Early theme bootstrap (`public/assets/theme-boot.js`) to set `data-theme` before CSS loads.
- Minimal pre-style (`public/assets/prestyle.css`) to avoid grey/white flash on first paint.
- TV/remote improvements:
  - Coarse input detection sets `data-input="coarse"` on `<html>`.
  - Skip link and stronger `:focus-visible` rings.
  - Larger hit targets and reduced hover tooltips for coarse input.

### Changed

- Default theme set to `seedsphere` on `<html>` in `index.html`.
- `src/App.vue`: initial focus to Home link on coarse input to improve remote navigation.
- SEO and PWA polish (OG/Twitter meta, canonical, favicon; refined manifest name/icons).

### Security

- Additional hardening headers in production (`server/index.js`): HSTS, X-Content-Type-Options,
  Referrer-Policy, Permissions-Policy, X-Frame-Options.

### Maintenance

- Community health: Code of Conduct, Contributing, Security policy, issue/PR templates, CODEOWNERS, FUNDING.
- CI: Node 22, dev branch coverage, markdownlint workflow.

## [1.0.0] - 2025-09-07

### Added

- Ko‑fi integration:
  - Programmatic overlay load with theme-friendly overrides and fade-in.
  - Persistent, draggable fallback button; position saved to localStorage.
- Central spacing tokens and helpers in `src/assets/main.css`:
  - `--space-card-x`, `--space-card-y`, `--space-section-gap`, `--space-grid-gap`.
  - `.page-section` and `.app-grid` utilities.
- Toast offset helpers:
  - `.with-nav-offset` and `.with-tabs-offset` for top toasts positioned under sticky bars.

### Changed

- Configure page layout polish in `src/pages/Configure.vue`:
  - Optimization card stacked layout for all controls; increased spacing for readability.
  - Swarm scraping and probe/timeouts sections converted to single-column stacks.
  - Flash/Toast notifications positioned below navbar and sticky tabs.
  - Toggles standardized to be label‑less with tooltips; `toggle-success` for green on-state.
- Home page sections now use `.page-section` and `.app-grid`; removed per-card ad-hoc paddings.
- `Home.vue` install UI gated by `?dev=1` (dev-only variant controls hidden otherwise).

### Security

- Added production `Content-Security-Policy` in `server/index.js` to allow Ko‑fi overlay and app assets while keeping defaults restrictive.

### Maintenance

- Ignored local SQLite databases under `server/data/`.
- Removed duplicate `src/pages/Configure copy.vue`.
- Ignored backup `node_modules/` and `package-lock.json` to reduce Dependabot noise.

[1.0.0]: https://github.com/jxoesneon/SeedSphere/releases/tag/v1.0.0
