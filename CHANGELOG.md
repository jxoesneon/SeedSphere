# Changelog

All notable changes to this project will be documented in this file.

## [1.9.49] - 2026-01-05 (iOS & Docker Fix)

### Platform & Deployment

- **iOS Compatibility**: Updated `ios/Podfile` to target iOS 14.0, resolving "Ineligible destinations" errors in CodeQL (xcodebuild) workflow.
- **Docker Deployment**: Corrected `router/Dockerfile` to use `dart build cli` instead of the legacy `dart build` command, ensuring reliable server container builds.

## [1.9.48] - 2026-01-05 (Deep CI/Build Fix)

### Critical Infrastructure

- **Android Network Security**: Updated `network_security_config.xml` to allow global cleartext traffic (`<base-config>`), fixing a regression where public P2P bootstrap nodes (TCP/4001) were being blocked on Android 9+.
- **CI Build**: Validated Android NDK installation and build process locally to resolve timeout/environment issues in CodeQL workflow.

## [1.9.47] - 2026-01-05 (Security Fix)

### Security & CI

- **Log Redaction**: HTTP Logs in `NetworkConstants` now actively redact sensitive authorization data (tokens, secrets) to comply with CodeQL security policies.
- **CodeQL**: Fixed potential leakage of sensitive data in debug traces.

## [1.9.46] - 2026-01-05 (CI Green)

### Code Maintenance

- **Formatting**: Applied `dart format` to 40+ files in `gardener` to match the project's style guide and pass strict CI checks.
- **CI Verification**: Verified `router` tests (passed), `gardener` tests (passed), and `bridge` build (passed) locally.
- **Security**: Redacted sensitive fields (`token`, `secret`, `idToken`) from `HttpLogger` traces to pass CodeQL analysis.

## [1.9.45] - 2026-01-05 (CI Fixes)

### Forensics & Debugging

- **HTTP Interceptor**: Implemented `HttpLogger` to trace full Request/Response lifecycles (URL, Method, Status, Body) for authentication calls.
- **P2P Command Trace**: Enhanced P2P isolate logging to emit granular `CMD: <Action>` traces for better visibility into internal state changes.

## [1.9.44] - 2026-01-05 (Action Tracing)

### Forensics & Debugging

- **HTTP Interceptor**: Implemented `HttpLogger` to trace full Request/Response lifecycles (URL, Method, Status, Body) for authentication calls.
- **P2P Command Trace**: Enhanced P2P isolate logging to emit granular `CMD: <Action>` traces for better visibility into internal state changes.

## [1.9.43] - 2026-01-05 (Android 16 Readiness)

### Platform Compatibility

- **Android 13+ Support**: Added `NEARBY_WIFI_DEVICES` permission to `AndroidManifest.xml` to support local mDNS discovery on modern Android versions (API 33+).
- **Cleartext Traffic**: Enabled `usesCleartextTraffic="true"` to prevent OS-level blocking of raw TCP socket connections (e.g., P2P bootstrapping) on restrictive networks.

## [1.9.42] - 2026-01-05 (Public Static IP Fallback)

### Bootstrap Resilience

- **Public IPFS Static IPs**: Added 10+ public static IPFS bootstrap nodes (including Protocol Labs' Mars, Earth, Venus, Pluto, Mercury) to ensure connectivity even when local DNS resolution fails completely.

## [1.9.41] - 2026-01-05 (Dynamic DNS Fix)

### Network Resilience

- **Reverted Static IP**: Removed hardcoded Fly.io Anycast IP to avoid connectivity issues if the platform rotates addresses.
- **Hostname Correction**: Maintained the fix for `seedsphere.fly.dev` (replacing the invalid `seedsphere-router` hostname) which ensures proper DNS resolution.

## [1.9.40] - 2026-01-05 (Hostname Fix)

### Critical Connectivity Fixes

- **Hostname Correction**: Fixed a typo in the bootstrap configuration where `seedsphere-router.fly.dev` (invalid) was used instead of `seedsphere.fly.dev`.
- **Static IP Fallback**: Hardcoded the router's Anycast IP (`66.241.125.244` / `2a09:8280...`) to bypass DNS resolution failures on restrictive networks (e.g., Android Emulators).

## [1.9.39] - 2026-01-05 (Forensic Diagnostics)

### Forensic Suite

- **Diagnostic Reporting**: Added "Generate Diagnostic Report" in Debug Logs to capture P2P identity, network addresses, and auth state for troubleshooting.
- **Categorical Logging**: System logs are now tagged with `[NET]`, `[DHT]`, `[PERF]`, and `[AUTH]` for granular filtering.
- **Network Path Verification**: Implemented raw socket pings to bootstrap nodes to identify infrastructure-level blockages.
- **Performance Tracking**: Added periodic isolate health checks (connection counts and status) every 60 seconds.

### Logic Fixes

- **Auth Service**: [CRITICAL] Restored Bearer token support for session verification on the router, enabling automatic "sharedSecret" recovery for mobile heartbeats.
- **UI**: Added category filters to the `DebugLogsScreen` for more efficient debugging.
- **P2P Manager**: Optimized isolate message listener to handle structured forensic data.

## [1.9.38] - 2026-01-05 (Emergency P2P Repair)

### Connectivity Fixes

- **Public Swarm Integration**: Removed the hardcoded Swarm Key (PSK) that was blocking discovery on the public IPFS network.
- **Router Port Sync**: Updated the SeedSphere Router to listen on port 4001 (matching `fly.toml`) and added support for the TCP protocol.
- **Improved Bootstrap**: Updated multiaddresses in Gardener to include both TCP and UDP/QUIC for more robust discovery via the router.
- **Manual Optimization**: The "Optimize Network" button in Swarm Uplink now triggers an active re-bootstrap command in the background isolate.

## [1.9.37] - 2026-01-05 (Stellar Patch)

### P2P & Connectivity

- **Auto-Linking**: Automatically establishes secure device pairing during Google Sign-In, resolving "Heartbeat skipped" warnings.
- **Bootstrap Nodes**: Added public IPFS bootstrap nodes (Protocol Labs, Cloudflare) for robust global peer discovery.
- **Manual Config**: Implemented persistence and real-world effects for manual configuration toggles (Bootstrap, Scrape Swarm).

### Stremio Integration

- **Addon Catalogs**: Added "Recently Resolved" catalog to the local Stremio manifest for a better companion experience.
- **Identity**: Stabilized addon identity with persistent `gardenerId`.

### UX & Tooling

- **Debug Logs**: New interactive Logs page with level-based color coding and real-time streaming.
- **Key Vault**: Added clipboard paste support to all API key fields.
- **Auth**: Refined error handling and messaging in `AuthScreen` for a more premium production feel.
- **Maintenance**: Resolved lint errors related to `path_provider` and production logging.

## [1.9.35] - 2026-01-05

### Audit Implementation & Hardening

- **Security**: Added peer blacklisting (`ReputationManager`) and pairing payload verification (`PairingManager`).
- **Stremio Integration**: Stabilized addon identity with persistent `gardenerId` and fixed Google OAuth configuration.
- **Core Logic**: Upgraded `StreamResolver` with robust polling and file selection strategies.
- **UX**: Removed all UI-level mock delays (`Future.delayed`) in favor of real P2P state reactivity.
- **Test Coverage**: Achieved >90% test coverage for core logic components.

## [1.9.34] - 2026-01-04 (Private)

- Adjusted the flux capacitor's temporal displacement.

## [1.9.33] - 2026-01-04 (Private)

- Re-aligning the warp coils for better efficiency.

## [1.9.32] - 2026-01-04 (Private)

- Fixed a glitch in the matrix (deja vu handled).

## [1.9.31] - 2026-01-04 (Private)

- Teaching the AI the difference between 'good' and 'evil'.

## [1.9.30] - 2026-01-04 (Private)

- Optimizing quantum entanglement protocols.

## [1.9.29] - 2026-01-04 (Private)

- Cleaning up digital cobwebs in the server room.

## [1.9.28] - 2026-01-04 (Private)

- Polishing the pixels for that extra shine.

## [1.9.27] - 2026-01-04 (Private)

- Reducing entropy in the codebase (one bug at a time).

## [1.9.26] - 2026-01-04 (Private)

- Calibrating the infinite improbability drive.

## [1.9.25] - 2026-01-04 (Private)

- Ensuring the bits are flowing in the right direction.

## [1.9.24] - 2026-01-04 (Private)

- Removing gremlins from the machinery.

## [1.9.23] - 2026-01-04 (Private)

- Upgrading the coffee machine for the developers.

## [1.9.22] - 2026-01-04 (Private)

- Hunting down Heisenbugs (don't look at them!).

## [1.9.21] - 2026-01-04 (Private)

- Tightening the nuts and bolts on the backend.

## [1.9.20] - 2026-01-04 (Private)

- Defragmenting the collective consciousness.

## [1.9.19] - 2026-01-04 (Private)

- Routine checkup: vital signs are stable.

## [1.9.18] - 2026-01-03

### Fixed

- **Auth**: Corrected SMTP authentication logic to prefer `BREVO_API_KEY` when available, resolving Magic Link failures.
- **Security**: Fully implemented "Unlink All Devices" backend functionality.
- **UI**: Improved Magic Link error reporting and automatic device list refresh after unlinking.

## [1.9.17] - 2026-01-03

### Added

- **User Profile**: Dedicated section in Portal for managing Identity, Sessions, and Security.
- **Session Management**: View active sessions and remotely revoke them (`GET /sessions`, `DELETE /sessions/:id`).
- **Debrid Integrations**: Secure UI for managing Real-Debrid and AllDebrid API keys with visibility toggles.
- **Account Security**: "Danger Zone" for account deletion and device unlinking.
- **Docs**: Updated documentation to reflect "Stremio Companion/OS" positioning.

## [1.9.16] - 2026-01-02 (Private)

- Sweeping up the bits left on the floor.

## [1.9.15] - 2026-01-02 (Private)

- Oiling the gears of the CI/CD pipeline.

## [1.9.14] - 2026-01-02 (Private)

- Rebooting the universe (just a small part of it).

## [1.9.13] - 2026-01-01 (Private)

- Converting caffeine into code efficiently.

## [1.9.12] - 2026-01-01 (Private)

- Patching the hull breach in Sector 7G.

## [1.9.11] - 2026-01-01 (Private)

- Recalibrating sensors for maximum detection.

## [1.9.10] - 2026-01-01 (Private)

- Flushing the buffer (and the cache).

## [1.9.9] - 2026-01-01 (Private)

- Synchronizing watches with the atomic clock.

## [1.9.8] - 2026-01-01 (Private)

- Preventing the singularity (for now).

## [1.9.7] - 2026-01-01 (Private)

- Updating definitions of 'normal' operation.

## [1.9.6] - 2026-01-01 (Private)

- The hamster wheel is spinning smoothly again.

## [1.9.5] - 2025-12-31

### Added

- **Build Infrastructure**: Timestamped release binaries (e.g., `gardener-windows-setup-20251231.exe`) for uniqueness.
- **Test Reliability**: Hardened integration tests against zombie processes.

## [1.9.4] - 2025-12-31

### Added on 2025-12-31

- **Desktop Authentication**: Loopback IP Flow for Windows, Linux, and macOS.
- **Android Authentication**: Release keystore configuration for consistent signing.
- **iOS Config**: Preparation for Google Sign-In.

### Fixed

- **Linting**: Resolved duplicate imports and unawaited futures in Auth logic.

## [1.9.3] - 2025-12-31

### Fixed on 2025-12-31

- **Code Coverage**: Improved test coverage for `router` services (Mailer, P2P, RateLimit, Prefetch).
- **Quality Assurance**: Resolved linter warnings and compilation errors in test suite.

## [1.9.2] - 2025-12-30 (Private)

- Minor tweaks to the secret sauce.

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
