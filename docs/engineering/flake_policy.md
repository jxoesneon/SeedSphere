# Flaky Test Policy (The Three-Strike Rule)

## Definition

A test is **Flaky** if it fails and then passes without any code changes to the system under test (e.g., due to race conditions, network jitter, or resource contention).

## The Three-Strike Rule

1.  **Detection**: If a test fails in CI but passes on retry (or locally), it is a suspect.
2.  **Quarantine**:
    - Immediately annotate the test with `@Tags(['flaky'])` (Dart) or equivalent.
    - This removes it from the **Blocking CI Gate**.
3.  **Remediation**:
    - Open a **High Priority** GitHub Issue: `fix(test): potentially flaky [Test Name]`.
    - The test _cannot_ be de-quarantined until the root cause is fixed.

## Running Quarantined Tests

Quarantined tests are run in a separate "Quarantine Suite" job that does **not** block merging but reports health.
Run locally:

```powershell
.agent/scripts/test_suite.ps1 -Quarantine
```

## How to Quarantine

**Dart/Flutter:**

```dart
@Tags(['flaky'])
test('my unstable test', () { ... });
```
