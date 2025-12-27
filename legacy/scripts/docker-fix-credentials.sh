#!/usr/bin/env bash
set -euo pipefail

# Fix Docker credential helper on macOS when 'docker-credential-desktop' is missing
# Then optionally build the local image: seedsphere:local
# Usage:
#   bash scripts/docker-fix-credentials.sh [--no-build]

NO_BUILD=0
if [[ ${1:-} == "--no-build" ]]; then
  NO_BUILD=1
fi

CONFIG_FILE="$HOME/.docker/config.json"
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%s)"

echo "[1/5] Show current Docker config: $CONFIG_FILE (if present)"
if [[ -f "$CONFIG_FILE" ]]; then
  cat "$CONFIG_FILE" || true
else
  echo "(no config.json found, will create a minimal one)"
fi

echo "\n[2/5] Ensure docker-credential-osxkeychain exists in PATH"
if ! command -v docker-credential-osxkeychain >/dev/null 2>&1; then
  echo "ERROR: docker-credential-osxkeychain not found in PATH. Install Docker Desktop or add the helper." >&2
  exit 1
fi

echo "\n[3/5] Patch credsStore/credHelpers -> osxkeychain (backup will be created)"
python3 - <<'PY'
import json, os, time, sys
p=os.path.expanduser('~/.docker/config.json')
backup=p+'.bak.'+str(int(time.time()))
if not os.path.exists(os.path.dirname(p)):
    os.makedirs(os.path.dirname(p), exist_ok=True)
if not os.path.exists(p):
    data={}
else:
    with open(p) as f:
        try:
            data=json.load(f)
        except Exception as e:
            print('Failed to parse config.json:', e, file=sys.stderr)
            sys.exit(1)
changed=False
# Switch global credsStore
if data.get('credsStore')=='desktop':
    data['credsStore']='osxkeychain'; changed=True
# Switch per-registry credHelpers
ch=data.get('credHelpers',{})
if isinstance(ch, dict):
    for k,v in list(ch.items()):
        if v=='desktop':
            ch[k]='osxkeychain'; changed=True
    data['credHelpers']=ch
# If neither key present, default to osxkeychain
if 'credsStore' not in data and 'credHelpers' not in data:
    data['credsStore']='osxkeychain'; changed=True
# Write backup then new config
try:
    if os.path.exists(p):
        with open(backup,'w') as f: json.dump(data, f, indent=2)
except Exception:
    pass
with open(p,'w') as f: json.dump(data, f, indent=2)
print('Updated', p)
if os.path.exists(backup):
    print('Backup at', backup)
PY

echo "\n[4/5] Show updated Docker config:"
cat "$CONFIG_FILE" || true

if [[ "$NO_BUILD" -eq 1 ]]; then
  echo "\n[5/5] Skipping docker build (per --no-build)"
  exit 0
fi

echo "\n[5/5] Retrying docker build: seedsphere:local"
docker build -t seedsphere:local .
