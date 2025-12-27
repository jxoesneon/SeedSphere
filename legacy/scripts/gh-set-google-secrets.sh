#!/usr/bin/env bash
set -euo pipefail

# Set Google OAuth client credentials as GitHub Actions secrets for the current repo.
# Usage:
#   GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... bash scripts/gh-set-google-secrets.sh
# or run and follow prompts.

OWNER_REPO_OVERRIDE=""

if command -v gh >/dev/null 2>&1; then GH_BIN="gh"; elif [ -x "$HOME/bin/gh" ]; then GH_BIN="$HOME/bin/gh"; else echo "ERROR: gh not found in PATH" >&2; exit 1; fi

if [[ -n "$OWNER_REPO_OVERRIDE" ]]; then
  owner_repo="$OWNER_REPO_OVERRIDE"
else
  repo_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$repo_url" ]]; then echo "ERROR: No git remote 'origin'" >&2; exit 1; fi
  if [[ "$repo_url" == git@github.com:* ]]; then
    owner_repo="${repo_url#git@github.com:}"; owner_repo="${owner_repo%.git}"
  elif [[ "$repo_url" == https://github.com/* ]]; then
    owner_repo="${repo_url#https://github.com/}"; owner_repo="${owner_repo%.git}"
  else
    echo "ERROR: Could not detect GitHub owner/repo from: $repo_url" >&2; exit 1
  fi
fi

echo "Repo: $owner_repo"
$GH_BIN auth status || true

GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"

if [[ -z "$GOOGLE_CLIENT_ID" ]]; then
  read -r -p "Enter GOOGLE_CLIENT_ID: " GOOGLE_CLIENT_ID
fi
if [[ -z "$GOOGLE_CLIENT_SECRET" ]]; then
  read -r -s -p "Enter GOOGLE_CLIENT_SECRET: " GOOGLE_CLIENT_SECRET; echo
fi

if [[ -z "$GOOGLE_CLIENT_ID" || -z "$GOOGLE_CLIENT_SECRET" ]]; then
  echo "ERROR: Both GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET are required." >&2
  exit 1
fi

echo "Setting GitHub Actions secrets on $owner_repo ..."
$GH_BIN secret set GOOGLE_CLIENT_ID --repo "$owner_repo" --body "$GOOGLE_CLIENT_ID"
$GH_BIN secret set GOOGLE_CLIENT_SECRET --repo "$owner_repo" --body "$GOOGLE_CLIENT_SECRET"

echo "Done. Current matching secrets:"
$GH_BIN secret list --repo "$owner_repo" | grep -E '^(GOOGLE_CLIENT_ID|GOOGLE_CLIENT_SECRET)\b' || true

echo "Authorized redirect URIs to configure in Google Cloud Console (Web Application):"
LOCAL_REDIRECT="http://localhost:5173/api/auth/google/callback"
PROD_REDIRECT="https://seedsphere.fly.dev/api/auth/google/callback"
echo " - $LOCAL_REDIRECT"
echo " - $PROD_REDIRECT"
