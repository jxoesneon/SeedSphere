# Merge Queue Implementation Plan

## Overview

GitHub Merge Queue prevents "semantic conflicts" by ensuring that PRs are tested _in combination_ before merging to `main`.

## Configuration Steps

### 1. Protect `main` Branch

- Enable "Require merge queue" in Branch Protection Rules.
- Set "Parallel mode" to true (start with concurrency 5).
- set "Build Check" to look for `ci-dynamic.yml` success.

### 2. CI Adaptation

The dynamic CI workflow (`ci-dynamic.yml`) is already compatible. No changes needed other than ensuring it triggers on `merge_group` event.

### 3. Update Workflow Triggers

Update `.github/workflows/ci-dynamic.yml`:

```yaml
on:
  merge_group:
  pull_request:
  push:
```

## Rollout Strategy

1.  **Pilot**: Enable on a dev branch first.
2.  **Go Live**: Enable on `main` during a low-traffic period.
3.  **Monitor**: Watch for "false positive" build failures in the queue.
