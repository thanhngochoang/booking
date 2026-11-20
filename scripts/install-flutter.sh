#!/usr/bin/env bash
# Installs the pinned Flutter stable into ./.flutter (no admin rights). Delete .flutter to reset.
set -euo pipefail
FLUTTER_VERSION="3.50.1"  # keep in step with flutter-version in .github/workflows/flutter.yml (2 jobs)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/.flutter"
if [ -x "$DEST/bin/flutter" ]; then
  # Flutter >= 3.47 has no .flutter/version; the version is in bin/cache/flutter.version.json.
  OLD=""
  if [ -f "$DEST/bin/cache/flutter.version.json" ]; then
    OLD="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('frameworkVersion',''))" "$DEST/bin/cache/flutter.version.json" 2>/dev/null || true)"
  fi
  if [ -z "$OLD" ] && [ -f "$DEST/version" ]; then OLD="$(tr -d '[:space:]' < "$DEST/version")"; fi
  if [ "$OLD" = "$FLUTTER_VERSION" ]; then
    echo "Flutter $FLUTTER_VERSION already in $DEST"; "$DEST/bin/flutter" --version; exit 0
  fi
  echo "Replacing Flutter ${OLD:-unknown} with $FLUTTER_VERSION"
fi
ARCH="$(uname -m)"; case "$ARCH" in arm64) A="arm64";; *) A="x64";; esac
JSON="$(curl -sSL https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json)"
REL="$(printf '%s' "$JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
m=[x for x in d['releases'] if x['channel']=='stable' and x['version']=='$FLUTTER_VERSION' and x.get('dart_sdk_arch')=='$A']
if not m:
    sys.exit('Flutter $FLUTTER_VERSION not in the release index')
print(d['base_url']+'/'+m[0]['archive'])")"
echo "Downloading $REL"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/flutter.XXXXXX")"; curl -sSL -o "$TMP/flutter.zip" "$REL"
# Remove the old SDK only once the new one is downloaded and unpacked.
unzip -q "$TMP/flutter.zip" -d "$TMP" && rm -rf "$DEST" && mv "$TMP/flutter" "$DEST" && rm -rf "$TMP"
"$DEST/bin/flutter" --version
