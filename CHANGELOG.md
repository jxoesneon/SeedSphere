# Changelog

All notable changes to this project will be documented in this file.

## [1.9.36] - 2026-01-05

### Debug Logs & Developer Tooling

- **Debug Logs**: Added a full-featured Debug Logs page accessible from Node Configuration. Displays real-time logs with level-based color coding, copy-to-clipboard export, and log clearing.
- **Instrumentation**: Core services (`P2PManager`, `ReputationManager`, `StreamResolver`) now use `DebugLogger` for structured, observable logging.

### Connectivity

- **NAT Traversal**: Enabled `enableNatTraversal` via dart_ipfs 1.7.5, improving peer connectivity behind NAT/firewalls.
- **Dependencies**: Updated `dart_ipfs` to 1.7.5 and `intl` to 0.20.2.

### UI Polish

- **Key Vault**: Added paste buttons to all API key fields (Orion, OpenAI).
- **Network Status Card**: Refactored peer count display to use `TweenAnimationBuilder` for smooth animated transitions.

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
