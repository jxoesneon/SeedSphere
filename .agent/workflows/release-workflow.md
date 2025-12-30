---
description: Comprehensive Release Process for SeedSphere
---

# Release Process

Follow this sequential process for a flawless release.

## Phase 1: Verification

Ensure the codebase is stable.

1.  **Full Stack Verification**
    Run the unified debug script to ensure backend/frontend connectivity and no errors.
    ```powershell
    .agent/scripts/debug_stack.ps1
    ```
    _Verify: "Popular Streams" loads in Portal logs and no red error lines appear._

2.  **Automated CI Checks**
    Ensure GitHub Actions are passing for your branch:
    - `ci-backend.yml`: Verifies Router & Bridge (Dart/Node).
    - `ci-gardener.yml`: Verifies Gardener (Flutter).
    
    You can run the local suite to pre-verify:
    ```powershell
    .agent/scripts/test_suite.ps1
    ```

## Phase 2: Release Preparation

Prepare the repository for the new version (e.g., `2.0.1`).

1.  **Sync Repository**
    ```powershell
    git checkout main
    git fetch origin
    git reset --hard origin/main
    ```

2.  **Bump Versions**
    Run the automation script with your **target version**:
    ```powershell
    .agent/scripts/release.ps1 -Version <VERSION>
    ```
    _This updates pubspec.yaml AND syncs lockfiles automatically._

3.  **Update Documentation**
    - **Changelog**: Edit `CHANGELOG.md`.

4.  **Create Release PR**
    ```powershell
    git checkout -b release/v<VERSION>
    git add .
    git commit -m "chore(release): bump version to <VERSION>"
    git push -u origin release/v<VERSION>
    gh pr create --title "chore(release): bump version to <VERSION>" --body "Bump version."
    ```

5.  **Merge PR**
    ```powershell
    gh pr merge --auto --squash --delete-branch
    ```

## Phase 3: Deployment & Confirmation

1.  **Tag & Push**
    ```powershell
    git checkout main
    git pull
    git tag v<VERSION>
    git push origin v<VERSION>
    ```
    _This triggers the `gardener-ci.yml` release pipeline._
    _You can also manually trigger builds for specific platforms via GitHub Actions UI._

2.  **Confirm Build**
    Monitor GitHub Actions: https://github.com/jxoesneon/SeedSphere/actions
