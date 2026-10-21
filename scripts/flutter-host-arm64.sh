#!/usr/bin/env bash
# Puts arm64 host tools (flutter_tester, impellerc, font-subset, ...) into .flutter on Apple silicon.
#
# The Flutter tool always fills cache/artifacts/engine/darwin-x64 from the x86_64 archives and
# relied on Rosetta to run them. macOS 27 ships without Rosetta, so `flutter test` fails to load
# (flutter_tester, and impellerc for shaders, are x86_64). The engine also publishes darwin-arm64
# archives for the same revision; this copies their binaries over the x86_64 ones. Idempotent.
# Run it again after `flutter upgrade`, `flutter precache` or deleting .flutter/bin/cache.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/.flutter/bin/cache"
DIR="$CACHE/artifacts/engine/darwin-x64"

[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo "Not an arm64 Mac: nothing to do"; exit 0; }
[ -d "$DIR" ] || "$ROOT/scripts/bin/flutter" precache --no-android --no-ios --no-web --no-linux --no-windows --no-fuchsia
if file "$DIR/flutter_tester" | grep -q arm64 && file "$DIR/font-subset" | grep -q arm64; then
  echo "Host tools are already arm64"; exit 0
fi

REV="$(cat "$CACHE/engine.stamp")"
BASE="https://storage.googleapis.com/flutter_infra_release/flutter/$REV/darwin-arm64"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/flutter-arm64.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
for zip in artifacts font-subset; do
  echo "Downloading $BASE/$zip.zip"
  curl -fsSL -o "$TMP/$zip.zip" "$BASE/$zip.zip"
  unzip -q -o "$TMP/$zip.zip" -d "$TMP/$zip"
done

# gen_snapshot is left alone: darwin-x64 keeps gen_snapshot_arm64/_x64 for macOS desktop builds.
for f in "$TMP/artifacts"/*; do
  name="$(basename "$f")"
  [ "$name" = gen_snapshot ] && continue
  rm -rf "${DIR:?}/$name"
  cp -R "$f" "$DIR/$name"
done
cp "$TMP/font-subset/font-subset" "$DIR/font-subset"
chmod +x "$DIR/flutter_tester" "$DIR/impellerc" "$DIR/font-subset"
file "$DIR/flutter_tester" "$DIR/impellerc" "$DIR/font-subset" | sed 's/: .*executable /: /'
