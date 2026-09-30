#!/usr/bin/env bash
# Installs the Android SDK pieces this project needs into ./.android-sdk (no admin rights).
# Downloads the zips directly from dl.google.com, so it also works where sdkmanager cannot reach the network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$ROOT/.android-sdk"
REPO="https://dl.google.com/android/repository"
TMP="$(mktemp -d)"

mkdir -p "$SDK/platforms" "$SDK/build-tools"

if [ ! -d "$SDK/platforms/android-34" ]; then
  curl -sSL -o "$TMP/p.zip" "$REPO/platform-34-ext7_r03.zip"
  unzip -q "$TMP/p.zip" -d "$TMP/p" && mv "$TMP/p"/* "$SDK/platforms/android-34"
fi
if [ ! -d "$SDK/build-tools/34.0.0" ]; then
  curl -sSL -o "$TMP/b.zip" "$REPO/build-tools_r34-macosx.zip"
  unzip -q "$TMP/b.zip" -d "$TMP/b" && mv "$TMP/b"/* "$SDK/build-tools/34.0.0"
fi
if [ ! -d "$SDK/platform-tools" ]; then
  curl -sSL -o "$TMP/t.zip" "$REPO/platform-tools_r37.0.1-darwin.zip"
  unzip -q "$TMP/t.zip" -d "$SDK"
fi
rm -rf "$TMP"
echo "sdk.dir=$SDK" > "$ROOT/local.properties"
echo "Android SDK installed in $SDK"
