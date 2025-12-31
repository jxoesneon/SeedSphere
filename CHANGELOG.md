# Changelog

All notable changes to this project will be documented in this file.

## [1.9.3] - 2025-12-30

### Added

- **Mobile Deep Linking**: Full Universal Links (iOS) and App Links (Android) integration.
- **Magic Link Authentication**: Email-based passwordless login flow.
- **Device Linking Flow**: QR code initiated device pairing with token exchange.
- **SwarmDashboard Test**: Widget test with HTTP mocking for improved coverage.
- **Router Test**: GoRouter configuration verification test.

### Fixed

- **google_sign_in**: Downgraded to `^6.2.1` for compatibility.
- **Lint Cleanup**: Resolved `@override` annotation issues in test mocks.
- **Coverage Scripts**: Added filtered coverage calculation utility.

## [1.9.1] - 2025-12-29

### Added

- **Cortex AI**: Core infrastructure (Models, Cache, Service) for AI-enhanced descriptions.
- **DeepSeek Integration**: Default free-tier provider for streaming descriptions.
- **Gardener CI**: Multi-platform build pipeline (`gardener-ci.yml`) and verification (`ci-gardener.yml`).
- **Backend CI**: Path-filtered verification for Router/Bridge (`ci-backend.yml`).
- **Release Governance**: Automated versioning scripts and rigorous workflow documentation in `.agent`.

### Changed

- **Architecture**: Enforced Service-Controller-Model in Router and Riverpod in Gardener.
- **Agent Config**: Migrated and customized agent rules from FerroTeX.
- **Dashboard**: Renamed "Popular Systems" to "Popular Streams".

### Fixed

- **Windows Support**: Bundled `libsodium.dll` to prevent startup hangs/degraded mode.
- **Metadata Normalization**: Restored legacy parity for parsing quality, audio, and codecs.
- **Test Suite**: Fixed port conflicts in `server_test.dart` to allow running tests alongside debug stack.

## [1.9.0] - 2025-12-20

- Initial "Federated Frontier" Parity Release.
