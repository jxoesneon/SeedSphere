#!/usr/bin/env bash
set -euo pipefail

# Config: set to your repo explicitly to override auto-detection
OWNER_REPO_OVERRIDE=""

# 1) Resolve gh binary
if command -v gh >/dev/null 2>&1; then GH_BIN="gh"; elif [ -x "$HOME/bin/gh" ]; then GH_BIN="$HOME/bin/gh"; else echo "ERROR: gh not found in PATH" >&2; exit 1; fi

# 2) Detect owner/repo from git remote (unless overridden)
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

# 3) Auth status (non-fatal if not logged in)
$GH_BIN auth status || true

# 4) List current secrets
secret_list="$($GH_BIN secret list --repo "$owner_repo" 2>/dev/null || true)"
echo "Existing matching secrets:" && echo "$secret_list" | grep -E '^(AUTH_JWT_SECRET|AI_KMS_KEY)\b' || echo "(none found)"

need_auth_jwt_secret=0
need_ai_kms_key=0

echo "$secret_list" | grep -q '^AUTH_JWT_SECRET\b' || need_auth_jwt_secret=1

echo "$secret_list" | grep -q '^AI_KMS_KEY\b' || need_ai_kms_key=1

# 5) Set missing secrets
if [[ $need_auth_jwt_secret -eq 1 ]]; then
  echo "Setting AUTH_JWT_SECRET..."
  AUTH_JWT_SECRET="$(node -e "console.log(require('crypto').randomBytes(48).toString('hex'))")"
  $GH_BIN secret set AUTH_JWT_SECRET --repo "$owner_repo" --body "$AUTH_JWT_SECRET"
else
  echo "AUTH_JWT_SECRET already present"
fi

if [[ $need_ai_kms_key -eq 1 ]]; then
  echo "Setting AI_KMS_KEY..."
  AI_KMS_KEY="$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")"
  $GH_BIN secret set AI_KMS_KEY --repo "$owner_repo" --body "$AI_KMS_KEY"
else
  echo "AI_KMS_KEY already present"
fi

# 6) Verify
echo "Post-update secrets:"
$GH_BIN secret list --repo "$owner_repo" | grep -E '^(AUTH_JWT_SECRET|AI_KMS_KEY)\b' || true
