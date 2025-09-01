#!/usr/bin/env bash
set -euo pipefail

# Install Google Cloud SDK (gcloud) on macOS using Homebrew and initialize
# Usage: bash scripts/gcloud-install.sh

if [[ "$OSTYPE" != darwin* ]]; then
  echo "This installer is intended for macOS." >&2
  exit 1
fi

command -v brew >/dev/null 2>&1 || { echo "Homebrew not found. Install Homebrew first: https://brew.sh" >&2; exit 1; }

echo "[1/5] Installing Google Cloud SDK (brew cask) if missing..."
if brew list --cask google-cloud-sdk >/dev/null 2>&1; then
  echo "google-cloud-sdk already installed."
else
  brew install --cask google-cloud-sdk
fi

# Ensure shell profile is sourced so gcloud is on PATH
if ! command -v gcloud >/dev/null 2>&1; then
  # Source the installed path if Homebrew suggests it
  if [[ -f "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc" ]]; then
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
  elif [[ -f "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc" ]]; then
    source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
  fi
fi

echo "[2/5] Verifying gcloud installation..."
gcloud --version || { echo "gcloud not found on PATH after install." >&2; exit 1; }

# Update SDK components
echo "[3/5] Updating gcloud components (optional)..."
gcloud components update --quiet || true

echo "[4/5] Running gcloud init (you will be prompted to login)..."
# This opens a browser for auth and lets you pick a default project
if ! gcloud config get-value core/account >/dev/null 2>&1; then
  gcloud init
else
  echo "gcloud already initialized for account: $(gcloud config get-value core/account)"
fi

echo "[5/5] Current gcloud config:"
gcloud config list --format='text'

echo "Done. Next: create an OAuth 2.0 Client ID in Google Cloud Console (Web application) and copy the CLIENT_ID/CLIENT_SECRET."
