---
trigger: always_on
glob: "*"
description: Project governance rules for Release, Cross-Platform, and Automation.
---

# Project Governance Rules (SeedSphere)

## 1. Release Management
- **Workflows**: Strictly follow .agent/workflows/release-workflow.md for all releases.
- **Automation**: ALWAYS use .agent/scripts/release.ps1 for version bumps. This ensures `pubspec.yaml` and `package.json` files stay in sync.
- **Versioning**: Synchronization is mandatory. `router`, `gardener`, and `portal` must strictly share the same version number (SemVer).

## 2. Cross-Platform Compatibility
- **Mobile First**: `gardener` is a Flutter app. Verify changes on Android and iOS (simulator/device) where possible.
- **Desktop Parity**: Ensure `router` runs seamlessly on Windows, Linux, and macOS.
- **Path Handling**: Use `path` package or `Platform.pathSeparator`. NEVER manually concatenate file URIs.
- **Binaries**: Explicitly handle `.exe` extensions on Windows (e.g. for `libsodium` loading).

## 3. Automation & Documentation
- **Workflow-First**: Complex manual processes must be documented in .agent/workflows/.
- **Scripts**: Reusable maintenance scripts belong in .agent/scripts/ (PowerShell preferred for cross-platform ease).
- **CI/CD Standards**:
  - **Release**: Use `gardener-ci.yml` for multi-platform build verification.
  - **Verification**: Use split workflows (`ci-backend.yml`, `ci-gardener.yml`) with **Path Filtering** enabled to save resources.
  - **Dependencies**: Rely on `dependabot.yml` for automated updates; review PRs weekly.

## 4. Development Standards
- **Testing**: `dart test` (Router) and `flutter test` (Gardener) are the golden standards.
- **Analysis**: Code must pass `dart analyze` with zero errors.

## 5. Architectural Integrity
- **Router (Backend)**:
  - **Pattern**: Service-Controller-Model.
  - **Dependency Injection**: Pass services via constructor. Avoid global singletons where possible (except `db`, `env`).
  - **Cortex AI**: AI features belong in `AiService` (logic) and `AddonService` (presentation). keep `server.dart` clean.
- **Gardener (Frontend)**:
  - **State Management**: strict **Riverpod**. No `setState` for complex business logic.
  - **Navigation**: GoRouter.
- **Parity**: Maintain functional parity with Legacy Node.js implementation until full migration is confirmed.

## 6. AI Collaboration Guidelines
- **Context Awareness**: Before editing, always check `parity_report.md` to ensure feature completeness.
- **Logging**: Use `print` for debug, but prefer structured logging for production features.
- **Testing**: When editing `P2PNode`, usually mock the swarm interactions. Real-world testing is done via `debug_stack.ps1`.
