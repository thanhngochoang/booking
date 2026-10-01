#!/usr/bin/env bash
# Installs Flutter stable into ./.flutter (no admin rights). Delete .flutter to reset.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/.flutter"
if [ -x "$DEST/bin/flutter" ]; then echo "Flutter already in $DEST"; "$DEST/bin/flutter" --version; exit 0; fi
ARCH="$(uname -m)"; case "$ARCH" in arm64) A="arm64";; *) A="x64";; esac
JSON="$(curl -sSL https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json)"
REL="$(printf '%s' "$JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin); h=d['current_release']['stable']
r=[x for x in d['releases'] if x['hash']==h and x.get('dart_sdk_arch')=='$A'][0]
print(d['base_url']+'/'+r['archive'])")"
echo "Downloading $REL"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/flutter.XXXXXX")"; curl -sSL -o "$TMP/flutter.zip" "$REL"
unzip -q "$TMP/flutter.zip" -d "$ROOT" && rm -rf "$TMP"
"$DEST/bin/flutter" --version
