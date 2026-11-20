#!/usr/bin/env bash
# Installs the pinned Flutter stable into ./.flutter (no admin rights). Delete .flutter to reset.
set -euo pipefail
FLUTTER_VERSION="3.50.1"  # keep in step with flutter-version in .github/workflows/flutter.yml (2 jobs)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/.flutter"
# Worktrees link .flutter to the main checkout's SDK (as env.sh and scripts/bin/flutter use it):
# update that SDK in place instead of replacing the link with a private copy.
if [ -L "$DEST" ]; then DEST="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$DEST")"; fi
installed_version() {
  # Flutter >= 3.47 has no .flutter/version; the version is in bin/cache/flutter.version.json.
  local v=""
  if [ -f "$1/bin/cache/flutter.version.json" ]; then
    v="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('frameworkVersion',''))" "$1/bin/cache/flutter.version.json" 2>/dev/null || true)"
  fi
  if [ -z "$v" ] && [ -f "$1/version" ]; then v="$(tr -d '[:space:]' < "$1/version")"; fi
  printf '%s' "$v"
}
if [ -x "$DEST/bin/flutter" ]; then
  OLD="$(installed_version "$DEST")"
  if [ "$OLD" = "$FLUTTER_VERSION" ]; then
    echo "Flutter $FLUTTER_VERSION already in $DEST"; "$DEST/bin/flutter" --version; exit 0
  fi
  echo "Replacing Flutter ${OLD:-unknown} with $FLUTTER_VERSION"
fi
ARCH="$(uname -m)"; case "$ARCH" in arm64) A="arm64";; *) A="x64";; esac
JSON="$(curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json)"
REL="$(printf '%s' "$JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
m=[x for x in d['releases'] if x['channel']=='stable' and x['version']=='$FLUTTER_VERSION' and x.get('dart_sdk_arch')=='$A']
if not m:
    sys.exit('Flutter $FLUTTER_VERSION not in the release index')
print(d['base_url']+'/'+m[0]['archive'])")"
echo "Downloading $REL"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/flutter.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "$TMP/flutter.zip" "$REL"
unzip -q "$TMP/flutter.zip" -d "$TMP"
# Remove the old SDK only once the new one is downloaded and unpacked.
rm -rf "$DEST"
mv "$TMP/flutter" "$DEST"
"$DEST/bin/flutter" --version
NEW="$(installed_version "$DEST")"
[ "$NEW" = "$FLUTTER_VERSION" ] || { echo "Installed Flutter is '$NEW', expected $FLUTTER_VERSION" >&2; exit 1; }
# A fresh SDK has x86_64 host tools again; on Apple silicon without Rosetta put the arm64 ones back
# (prints "Not an arm64 Mac" and does nothing elsewhere).
"$ROOT/scripts/flutter-host-arm64.sh"
