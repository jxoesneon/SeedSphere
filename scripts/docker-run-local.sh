#!/usr/bin/env bash
set -euo pipefail

# Run the local SeedSphere Docker image and expose on http://localhost:8080
# - Removes any existing container named seedsphere_local
# - Sets PORT=8080 for the server
# - Requires GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in the environment
# - Waits for /health to be ready (up to 30s)

NAME="seedsphere_local"
IMAGE="seedsphere:local"
PORT=8080

# Load environment from .env.local (preferred) or .env if present
if [[ -f ".env.local" ]]; then
  echo "[0/4] Loading .env.local"
  set -a
  # shellcheck disable=SC1091
  . ./.env.local
  set +a
elif [[ -f ".env" ]]; then
  echo "[0/4] Loading .env"
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# Validate required env vars for Google OAuth
if [[ -z "${GOOGLE_CLIENT_ID:-}" || -z "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  echo "ERROR: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set in your shell environment." >&2
  echo "Example:" >&2
  echo "  export GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com" >&2
  echo "  export GOOGLE_CLIENT_SECRET=your-client-secret" >&2
  echo "Then re-run: scripts/docker-run-local.sh" >&2
  exit 1
fi

# Optional but recommended for saving API keys:
if [[ -z "${AI_KMS_KEY:-}" ]]; then
  echo "WARNING: AI_KMS_KEY is not set; saving provider API keys will fail (crypto_not_initialized)." >&2
  echo "Generate and export a base64 32-byte key, e.g.:" >&2
  echo "  node -e \"console.log(require('crypto').randomBytes(32).toString('base64'))\"" >&2
  echo "  export AI_KMS_KEY=..." >&2
fi

echo "[1/4] Removing any existing container: ${NAME}"
docker rm -f "$NAME" >/dev/null 2>&1 || true

echo "[2/4] Starting container from ${IMAGE} on port ${PORT}"
docker run -d \
  --name "$NAME" \
  -p ${PORT}:${PORT} \
  -e PORT=${PORT} \
  -e NODE_ENV=production \
  -e COOKIE_SECURE=false \
  -e AUTH_JWT_SECRET="${AUTH_JWT_SECRET:-dev-local-secret-change-me}" \
  -e GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
  -e GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}" \
  -e AI_KMS_KEY="${AI_KMS_KEY:-}" \
  -e SMTP_HOST="${SMTP_HOST:-}" \
  -e SMTP_PORT="${SMTP_PORT:-}" \
  -e SMTP_USER="${SMTP_USER:-}" \
  -e SMTP_PASS="${SMTP_PASS:-}" \
  -e SMTP_SECURE="${SMTP_SECURE:-}" \
  -e SMTP_FROM="${SMTP_FROM:-}" \
  -e MS_CLIENT_ID="${MS_CLIENT_ID:-}" \
  -e MS_CLIENT_SECRET="${MS_CLIENT_SECRET:-}" \
  "$IMAGE" >/dev/null

echo "[3/4] Waiting for health endpoint..."
START=$(date +%s)
while true; do
  if curl -fsS "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    echo "Healthy"
    break
  fi
  if (( $(date +%s) - START > 30 )); then
    echo "ERROR: Service did not become healthy within 30s" >&2
    docker logs "$NAME" --tail=200 || true
    exit 1
  fi
  sleep 1
done

echo "[4/4] Running. Open:"
echo " - App:    http://localhost:${PORT}"
echo " - Health: http://localhost:${PORT}/health"
