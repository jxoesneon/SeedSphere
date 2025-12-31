# Changelog

All notable changes to this project will be documented in this file.

## [1.9.3] - 2025-12-31

### Fixed on 2025-12-31

- **Code Coverage**: Improved test coverage for `router` services (Mailer, P2P, RateLimit, Prefetch).
- **Quality Assurance**: Resolved linter warnings and compilation errors in test suite.

## [1.9.1] - 2025-12-29

### Added on 2025-12-29

- **Cortex AI**: Core infrastructure (Models, Cache, Service) for AI-enhanced descriptions.
- **DeepSeek Integration**: Default free-tier provider for streaming descriptions.
- **Gardener CI**: Multi-platform build pipeline (`gardener-ci.yml`) and verification (`ci-gardener.yml`).
- **Backend CI**: Path-filtered verification for Router/Bridge (`ci-backend.yml`).
- **Release Governance**: Automated versioning scripts and rigorous workflow documentation in `.agent`.

### Changed on 2025-12-29

- **Architecture**: Enforced Service-Controller-Model in Router and Riverpod in Gardener.
- **Agent Config**: Migrated and customized agent rules from FerroTeX.
- **Dashboard**: Renamed "Popular Systems" to "Popular Streams".

### Fixed on 2025-12-28

- **Windows Support**: Bundled `libsodium.dll` to prevent startup hangs/degraded mode.
- **Metadata Normalization**: Restored legacy parity for parsing quality, audio, and codecs.
- **Test Suite**: Fixed port conflicts in `server_test.dart` to allow running tests alongside debug stack.

## [1.9.0] - 2025-12-20

- Initial "Federated Frontier" Parity Release.
