# Pull Request

## Summary

Describe the purpose of this PR.

## Changes

- [ ] Feature
- [ ] Bug fix
- [ ] Docs
- [ ] Refactor / chore

## Details

List the key changes:

- ...

## Screenshots (UI)

If relevant, add before/after screenshots.

## Checklist

- [ ] Builds locally (`npm run build`)
- [ ] Tests pass (`npm test`) if applicable
- [ ] Lint/style respected (Tailwind utility conventions, no inline CSS in HTML)
- [ ] Updated docs/README/CHANGELOG if needed
- [ ] No secrets committed

### Auth v2 Checklist (if applicable)

- [ ] Changes align with `docs/NEW_AUTH.md` (per-seedling routing, Option A path-secret, dynamic manifest)
- [ ] Root `/manifest.json` behavior preserved (recent seedling window = 10m configurable via `RECENT_SEEDLING_WINDOW_MS`)
- [ ] Dev-only manifest variants remain gated by `?dev=1` and are not exposed in production UI
- [ ] No `stremioAddonsConfig` signatures in dynamic manifests
- [ ] Limits respected (soft cap 20 seedlings per user via `MAX_SEEDLINGS_PER_USER`)

## Linked issues

Fixes #
