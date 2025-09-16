#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-http://127.0.0.1:8080}"
TOKEN_FILE="${TOKEN_FILE:-/tmp/ss_token.txt}"
COOKIES_FILE="${COOKIES_FILE:-/tmp/ss_cookies.txt}"

log() { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

# Helper to perform an HTTP request and show status and a body sample
req() {
  # usage: req [-b cookiefile] [-c cookiefile] [extra curl args...] -- URL
  local out_file
  out_file=$(mktemp)
  # shellcheck disable=SC2068
  local code
  code=$(curl -sS -o "$out_file" -w "%{http_code}" $@)
  printf "HTTP %s\n" "$code"
  # Print a small body sample to avoid noise
  head -c 300 "$out_file"; echo
  rm -f "$out_file"
}

# Wait for server readiness on /health
wait_ready() {
  local tries=${1:-60} # ~60 * 0.5s = 30s
  local i
  for i in $(seq 1 "$tries"); do
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/health" || true)
    if [[ "$code" == "200" ]]; then
      log "Server ready (HTTP 200 on /health)"
      return 0
    fi
    sleep 0.5
  done
  log "Server did not become ready in time"
  return 1
}

# 1) Obtain Magic Link token (use existing file or generate with dev-secret)
if [[ -f "$TOKEN_FILE" ]]; then
  TOKEN=$(cat "$TOKEN_FILE")
  log "Using existing magic token at $TOKEN_FILE (${#TOKEN} chars)"
else
  log "Token file not found at $TOKEN_FILE; generating dev token (AUTH_JWT_SECRET || dev-secret)"
  node - <<'NODE'
const jwt = require('jsonwebtoken');
const fs = require('fs');
const secret = process.env.AUTH_JWT_SECRET || 'dev-secret';
const token = jwt.sign({ sub: 'dev+cli@example.com', jti: 'cli-' + Date.now(), typ: 'magic' }, secret, { issuer: 'seedsphere', audience: 'auth', expiresIn: '15m' });
fs.writeFileSync('/tmp/ss_token.txt', token);
console.log('token_written:' + token.length);
NODE
  TOKEN=$(cat /tmp/ss_token.txt)
fi

# 2) Call magic callback to set session (store cookies), with fallback if token expired
log "Waiting for server readiness"
wait_ready || true
log "Calling magic callback to set session (showing headers)"
# Show headers to verify Set-Cookie was issued; also persist cookies
curl -sS -D - -c "$COOKIES_FILE" -o /dev/null "$BASE/api/auth/magic/callback?token=$TOKEN" | sed -n '1,15p'
log "Cookie jar saved to: $COOKIES_FILE"
if [[ -s "$COOKIES_FILE" ]]; then head -n 3 "$COOKIES_FILE" | sed 's/.*/(cookie) &/'; fi
# If no session cookie present, generate a fresh token and retry once
if ! grep -q 'ss_sess' "$COOKIES_FILE" 2>/dev/null; then
  log "No session cookie found; regenerating magic token and retrying callback"
  node - <<'NODE'
const jwt = require('jsonwebtoken');
const fs = require('fs');
const secret = process.env.AUTH_JWT_SECRET || 'dev-secret';
const token = jwt.sign({ sub: 'dev+cli@example.com', jti: 'cli-' + Date.now(), typ: 'magic' }, secret, { issuer: 'seedsphere', audience: 'auth', expiresIn: '15m' });
fs.writeFileSync('/tmp/ss_token.txt', token);
console.log('token_written:' + token.length);
NODE
  TOKEN=$(cat /tmp/ss_token.txt)
  curl -sS -D - -c "$COOKIES_FILE" -o /dev/null "$BASE/api/auth/magic/callback?token=$TOKEN" | sed -n '1,15p'
  log "Cookie jar (after retry): $COOKIES_FILE"
  if [[ -s "$COOKIES_FILE" ]]; then head -n 3 "$COOKIES_FILE" | sed 's/.*/(cookie) &/'; fi
fi

# 3) Verify session
log "Verifying session"
SESSION_JSON=$(curl -sS -b "$COOKIES_FILE" "$BASE/api/auth/session" || true)
printf "Session: %s\n" "$SESSION_JSON"
# If user is null, retry once with a fresh token
if echo "$SESSION_JSON" | grep -q '"user": null'; then
  log "Session user is null; regenerating magic token and retrying login"
  node - <<'NODE'
const jwt = require('jsonwebtoken');
const fs = require('fs');
const secret = process.env.AUTH_JWT_SECRET || 'dev-secret';
const token = jwt.sign({ sub: 'dev+cli@example.com', jti: 'cli-' + Date.now(), typ: 'magic' }, secret, { issuer: 'seedsphere', audience: 'auth', expiresIn: '15m' });
fs.writeFileSync('/tmp/ss_token.txt', token);
console.log('token_written:' + token.length);
NODE
  TOKEN=$(cat /tmp/ss_token.txt)
  curl -sS -D - -c "$COOKIES_FILE" -o /dev/null "$BASE/api/auth/magic/callback?token=$TOKEN" | sed -n '1,15p'
  SESSION_JSON=$(curl -sS -b "$COOKIES_FILE" "$BASE/api/auth/session" || true)
  printf "Session (after retry): %s\n" "$SESSION_JSON"
fi

# 4) Mint seedling
log "Minting seedling"
MINT_JSON=$(curl -sS -b "$COOKIES_FILE" -X POST "$BASE/api/seedlings" || true)
printf "Mint: %s\n" "$MINT_JSON"

# Extract manifestUrl and stremioUrl with Node (no jq dependency)
MANIFEST_URL=$(printf '%s' "$MINT_JSON" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(s||"{}");console.log(j.manifestUrl||"")}catch{}})')
STREMIO_URL=$(printf '%s' "$MINT_JSON" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(s||"{}");console.log(j.stremioUrl||"")}catch{}})')
log "Manifest URL: ${MANIFEST_URL:-<none>}"
log "Stremio URL:  ${STREMIO_URL:-<none>}"

# 5) Fetch per-seedling manifest sample
if [[ -n "${MANIFEST_URL:-}" ]]; then
  log "Per-seedling manifest sample"
  req -- "$MANIFEST_URL"
  # Derive seedling and secret from the manifest URL to build stream call
  PATH_ONLY=$(printf '%s' "$MANIFEST_URL" | sed -E 's|https?://[^/]+||')
  SEEDLING_ID=$(printf '%s' "$PATH_ONLY" | awk -F'/' '{print $3}')
  SK=$(printf '%s' "$PATH_ONLY" | awk -F'/' '{print $4}')
  if [[ -n "$SEEDLING_ID" && -n "$SK" ]]; then
    STREAM_URL="$BASE/s/$SEEDLING_ID/$SK/stream/movie/tt1254207.json?variant=best"
    log "Per-seedling stream request (demo id tt1254207, variant=best)"
    # Show HTTP and sample
    req -- "$STREAM_URL"
    # Print streams count
    curl -sS "$STREAM_URL" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(s||"{}");const n=Array.isArray(j.streams)?j.streams.length:0;console.log("streams_count:",n)}catch(e){console.error("json_parse_error",e.message)}})'
    # Re-fetch manifest and print the default for config key "variant" (should reflect "best" now)
    log "Per-seedling manifest after stream (expect variant default=best)"
    curl -sS "$MANIFEST_URL" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(s||"{}");const cfg=Array.isArray(j.config)?j.config:[];const entry=cfg.find(e=>e&&e.key==="variant");console.log("variant_default:", entry&&entry.default || "<none>")}catch(e){console.error("json_parse_error",e.message)}})'
  fi
fi

# 6) Root manifest JSON fetch (should return JSON; recent per-seedling if session present)
log "Root manifest (JSON)"
req -- "$BASE/manifest.json"

# 7) Root manifest HTML redirect (should 302 to /#/start)
log "Root manifest HTML redirect"
curl -sS -o /dev/null -w 'HTTP %{http_code} %{redirect_url}\n' -H 'Accept: text/html' "$BASE/manifest.json"

# 8) CORS header test with web.strem.io Origin
log "CORS headers with Origin: https://web.strem.io"
curl -sS -D - -o /dev/null -H 'Origin: https://web.strem.io' "$BASE/manifest.json" | sed -n '1,20p' | grep -i 'Access-Control-Allow-Origin' || true

# 9) Verify asset base forced to seedsphere.fly.dev when Origin is web.strem.io
if [[ -n "${MANIFEST_URL:-}" ]]; then
  log "Per-seedling manifest assets for web.strem.io Origin"
  curl -sS -H 'Origin: https://web.strem.io' "$MANIFEST_URL" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(s||"{}");console.log("logo:",j.logo||"", "\nbackground:", j.background||"")}catch(e){console.error("json_parse_error",e.message)}})'
fi

# 10) Google OAuth config status
log "Google OAuth status"
req -- "$BASE/api/auth/google/status"

# 11) Account route guard check (approximate without headless browser)
log "Logging out to verify route guard behavior"
req -b "$COOKIES_FILE" -c "$COOKIES_FILE" -X POST -- "$BASE/api/auth/logout"
log "Session after logout (expect user: null)"
req -b "$COOKIES_FILE" -- "$BASE/api/auth/session"
log "SPA redirect cannot be asserted via curl. Manually open: $BASE/#/account and expect to be redirected to /#/start?return=%2Faccount after app loads."

log "QA flow completed"
