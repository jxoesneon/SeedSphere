#!/usr/bin/env bash
set -euo pipefail

# Configuration
GH_EXTRACTED_DIR_DEFAULT="$HOME/Downloads/gh_2.78.0_macOS_amd64"
GH_DIR="${1:-$GH_EXTRACTED_DIR_DEFAULT}"
GH_BIN_SRC="$GH_DIR/bin/gh"
BIN_DIR="$HOME/bin"
GH_BIN_LINK="$BIN_DIR/gh"

echo "[1/5] Verifying downloaded gh binary at: $GH_BIN_SRC"
if [[ ! -x "$GH_BIN_SRC" ]]; then
  echo "ERROR: gh binary not found or not executable at: $GH_BIN_SRC" >&2
  echo "Pass the extracted directory as first arg if different, e.g.:" >&2
  echo "  $0 \"$HOME/Downloads/gh_2.78.0_macOS_amd64\"" >&2
  exit 1
fi

echo "[2/5] Creating local bin and symlinking gh -> $GH_BIN_LINK"
mkdir -p "$BIN_DIR"
ln -sf "$GH_BIN_SRC" "$GH_BIN_LINK"

# Ensure current shell session can see ~/bin first in PATH when sourcing this file
export PATH="$BIN_DIR:$PATH"

echo "[3/5] Verifying installation"
"$GH_BIN_LINK" --version

# Detect owner/repo from git remote
echo "[4/5] Detecting repository from git remote 'origin'"
if repo_url=$(git remote get-url origin 2>/dev/null); then
  if [[ "$repo_url" == git@github.com:* ]]; then
    owner_repo="${repo_url#git@github.com:}"; owner_repo="${owner_repo%.git}"
  elif [[ "$repo_url" == https://github.com/* ]]; then
    owner_repo="${repo_url#https://github.com/}"; owner_repo="${owner_repo%.git}"
  else
    echo "WARN: Could not parse owner/repo from remote: $repo_url" >&2
    owner_repo=""
  fi
else
  echo "WARN: No git remote 'origin' found in this directory" >&2
  owner_repo=""
fi

if [[ -n "${owner_repo:-}" ]]; then
  echo "Detected repo: $owner_repo"
else
  echo "Repo not detected. You can still use gh normally; pass --repo <owner/repo>." >&2
fi

# Non-interactive auth status (may suggest login)
echo "[5/5] Checking gh auth status"
"$GH_BIN_LINK" auth status || true

# If authenticated and repo detected, list target secrets (read-only)
if [[ -n "${owner_repo:-}" ]]; then
  echo "Listing CI secrets (AUTH_JWT_SECRET, AI_KMS_KEY) for $owner_repo (if authenticated):"
  "$GH_BIN_LINK" secret list --repo "$owner_repo" | grep -E 'AUTH_JWT_SECRET|AI_KMS_KEY' || true
fi

echo "Done. If auth is required, run: gh auth login"
