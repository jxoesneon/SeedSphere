# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to semantic versioning.

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
