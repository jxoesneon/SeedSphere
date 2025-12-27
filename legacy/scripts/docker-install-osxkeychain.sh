#!/usr/bin/env bash
set -euo pipefail

# Install or link docker-credential-osxkeychain helper on macOS
# This script searches for the helper inside Docker Desktop.app and links it into PATH.
# Usage: bash scripts/docker-install-osxkeychain.sh

HELPER_NAME="docker-credential-osxkeychain"
TARGET_DIR="/usr/local/bin"
TARGET_PATH="${TARGET_DIR}/${HELPER_NAME}"

echo "[1/4] Checking if ${HELPER_NAME} already exists in PATH..."
if command -v "${HELPER_NAME}" >/dev/null 2>&1; then
  which "${HELPER_NAME}"
  echo "Already installed. Nothing to do."
  exit 0
fi

echo "[2/4] Searching inside Docker Desktop.app for ${HELPER_NAME}..."
CANDIDATES=(
  "/Applications/Docker.app/Contents/Resources/bin/${HELPER_NAME}"
  "$HOME/Applications/Docker.app/Contents/Resources/bin/${HELPER_NAME}"
)
FOUND=""
for c in "${CANDIDATES[@]}"; do
  if [[ -x "$c" ]]; then FOUND="$c"; break; fi
done

if [[ -z "$FOUND" ]]; then
  echo "ERROR: Could not locate ${HELPER_NAME} in Docker Desktop.app."
  echo "- Ensure Docker Desktop is installed in /Applications (or ~/Applications)."
  echo "- Then re-run this script."
  exit 1
fi

echo "Found helper: $FOUND"

echo "[3/4] Creating symlink to ${TARGET_PATH} (may require sudo)..."
if [[ ! -d "$TARGET_DIR" ]]; then
  sudo mkdir -p "$TARGET_DIR"
fi
# Remove stale file if present but not the same
if [[ -e "$TARGET_PATH" && ! -L "$TARGET_PATH" ]]; then
  echo "Existing non-symlink at ${TARGET_PATH}, moving aside..."
  sudo mv "$TARGET_PATH" "${TARGET_PATH}.bak.$(date +%s)"
fi
sudo ln -sf "$FOUND" "$TARGET_PATH"

echo "[4/4] Verifying installation..."
if command -v "${HELPER_NAME}" >/dev/null 2>&1; then
  which "${HELPER_NAME}"
  echo "${HELPER_NAME} installed successfully."
else
  echo "ERROR: ${HELPER_NAME} not found after installation." >&2
  exit 1
fi
