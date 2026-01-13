---
description: Comprehensive Release Process for SeedSphere
---

# Release Process

We use an **Interactive Release Wizard** to streamline versioning, verification, and deployment.

## Quick Start (The "Happy Path")

1.  **Run the Wizard**

    ```powershell
    .agent/scripts/release_wizard.ps1
    ```

2.  **Follow the Prompts**
    - **Version**: Enter target (e.g., `1.9.7`).
    - **Tests**: It will run the suite.
      - ✅ **Pass**: Automatically proceeds.
      - ❌ **Fail**: You can choosing to **(R)etry** or **(F)orce** release (bypass tests).
    - **Commit**: Confirm to stage and commit changes.
    - **Tag**: Confirm to create the git tag.
    - **Push**: Confirm to push to GitHub (triggers CI/CD).

## Advanced Strategy

For details on our long-term roadmap (Dynamic Matrices, Merge Queues), see:
[.agent/advanced_engineering_strategy.md](../../advanced_engineering_strategy.md)

## Manual Fallback (If Wizard Fails)

If the script is broken, use the manual commands:

1.  **Bump Version**:
    - Update `gardener/pubspec.yaml`
    - Update `router/pubspec.yaml`
2.  **Tag & Push**:

    ```powershell
    git commit -am "chore(release): bump version"
    git tag vX.Y.Z
    git push origin main --tags
    ```

3.  **Pre-Flight Checks (Important!)**:

    > [!IMPORTANT]
    > Always run these before tagging to prevent CI failures!

    **Router (Backend):**

    ```bash
    cd router
    dart format --output=none --set-exit-if-changed .
    dart analyze --fatal-infos
    dart test
    ```

    **Gardener (Frontend):**

    ```bash
    cd gardener
    flutter analyze --no-fatal-infos
    flutter test
    ```
