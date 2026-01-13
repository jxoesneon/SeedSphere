# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.2] - 2026-01-13

- **Fixed:** Resolved CI analysis lints in `RateLimiter` and validation scripts to validat build pipeline.

## [2.1.1] - 2026-01-13

- **Feature:** Added **User-Agent Rotation** and **Jittered Delays** as default benign anti-ban strategies.
- **Feature:** Implemented **Adaptive Fallback** logic: if a 403/429 (Ban) error is detected, the scraper automatically rotates identity and retries with backoff.

## [2.1.0] - 2026-01-13

- **Feature:** Implemented intelligent `RateLimiter` for all scrapers to prevent IP limits and Cloudflare blocks. 1337x is now limited to 1 request every 3 seconds, and PirateBay to 1 request every 2 seconds.
- **Fixed:** Series Verification logic from v2.0.9 included in this minor release.

## [2.0.9] - 2026-01-13

- **Fixed:** Series Verification now correctly handles season packs and typical naming conventions (ignoring strict year checks and allowing 'S01', 'Season', etc.), resolving the 100% failure rate for top series.
- **Fixed:** `verify_resolution` tool script provided for local verification of coverage.

## [2.0.8] - 2026-01-13

- **Fixed:** Implemented "Deep Inspection" for magnet links. Scrapers now verify the internal file name (`dn` parameter) of the magnet link against the request, preventing situations where a correct page yields an unrelated file (e.g., retrieving "IMPACT" instead of "Avatar").

## [2.0.7] - 2026-01-13

- **Fixed:** Stream Verification now strictly rejects single-digit sequels (e.g., "Iron Man 2") which were previously slipping through as "short junk words".

## [2.0.6] - 2026-01-13

- **Fixed:** Disabled `AutoNAT` on Android to prevent P2P node initialization hang.
- **Fixed:** Switched P2P network binding to dynamic ports (TCP/0, QUIC/0) to avoid conflicts.
- **Improved:** Reduced log noise by silencing "no shared secret" warnings during initialization.

## [2.0.5] - 2026-01-13

- **Fixed:** Addressed strict analyzer lints in `TitleVerifier` (missing class docs).
- **CI:** Release workflow now enforces strict linting checks.

## [2.0.4] - 2026-01-13

- **Fixed:** Resolved linter errors in `TitleVerifier` that caused CI failure.

## [2.0.3] - 2026-01-13

- **Fixed:** Stream Verification logic now strictly enforces year matching and safe-suffix filtering to prevent unrelated content from being returned.
- **Verified:** Stremio addon download link functionality in Portal.

## [2.0.2] - 2026-01-13

- Restored IPFS bootstrap nodes to fix "Connecting..." hang in production.
- Disabled excessive verbose debug logging (EKG/Pulse) in release builds.
- Updated Stremio manifest to require configuration, enabling account linking flow.

## [2.0.1] - 2026-01-13

- **HOTFIX**: Restored Portal access (removed `MaintenanceScreen`).
- **HOTFIX**: Disabled debug-only login bypass in `AuthScreen` for cleaner production release.

## [2.0.0] - 2026-01-11

### Added

- **Feature Gap Closure**: Implemented extensive legacy feature support (Torznab, UDP Scraping, Caching).
- **Expert Screen**: Real-time diagnostics with EKG, Spectrum, and Density visualizations.
- **Settings Mesh**: Redesigned settings navigation (Zones, Hero Animations).
- **Core Engine**: Advanced scoring heuristics, provider failover, and multi-source scraping.
- **Test Coverage**: Achieved >90% verified test coverage across critical components.
- **UDP Tracker Client**: Full BEP 15 implementation for direct swarm intelligence.
- **Cortex Service**: Integration with Azure OpenAI, DeepSeek, and Google Gemini.

### Changed

- Refactored `DesktopGoogleAuth` with mockable HTTP server for robust testing.
- Stabilized macOS build pipeline (Provisioning Profile automation).
- Enhanced `SwarmDashboard` with interactive logs and pulse monitoring.

### Fixed

- Addressed `dart_libp2p` stream handling bugs.
- Resolved race conditions in `ScraperEngine`.
- Fixed multiple UI layout regressions and navigation loops.
