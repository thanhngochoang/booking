#!/usr/bin/env bash
# Installs the Android SDK pieces this project needs into ./.android-sdk (no admin rights).
# Downloads the zips directly from dl.google.com, so it also works where sdkmanager cannot reach the network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$ROOT/.android-sdk"
REPO="https://dl.google.com/android/repository"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sdk.XXXXXX")"

mkdir -p "$SDK/platforms" "$SDK/build-tools"

if [ ! -d "$SDK/platforms/android-34" ]; then
  curl -sSL -o "$TMP/p.zip" "$REPO/platform-34-ext7_r03.zip"
  unzip -q "$TMP/p.zip" -d "$TMP/p" && mv "$TMP/p"/* "$SDK/platforms/android-34"
fi
if [ ! -d "$SDK/build-tools/34.0.0" ]; then
  curl -sSL -o "$TMP/b.zip" "$REPO/build-tools_r34-macosx.zip"
  unzip -q "$TMP/b.zip" -d "$TMP/b" && mv "$TMP/b"/* "$SDK/build-tools/34.0.0"
fi
if [ ! -d "$SDK/platforms/android-35" ]; then
  curl -sSL -o "$TMP/p35.zip" "$REPO/platform-35_r02.zip"
  unzip -q "$TMP/p35.zip" -d "$TMP/p35" && mv "$TMP/p35"/* "$SDK/platforms/android-35"
fi
# AGP 9.x compiles against platform 36 with build-tools 36.0.0
if [ ! -d "$SDK/platforms/android-36" ]; then
  curl -sSL -o "$TMP/p36.zip" "$REPO/platform-36_r02.zip"
  unzip -q "$TMP/p36.zip" -d "$TMP/p36" && mv "$TMP/p36"/* "$SDK/platforms/android-36"
fi
if [ ! -d "$SDK/build-tools/36.0.0" ]; then
  curl -sSL -o "$TMP/b36.zip" "$REPO/build-tools_r36_macosx.zip"
  unzip -q "$TMP/b36.zip" -d "$TMP/b36" && mv "$TMP/b36"/* "$SDK/build-tools/36.0.0"
fi
if [ ! -d "$SDK/ndk/28.2.13676358" ]; then
  curl -sSL -o "$TMP/ndk.zip" "$REPO/android-ndk-r28c-darwin.zip"
  mkdir -p "$SDK/ndk" && unzip -q "$TMP/ndk.zip" -d "$TMP/ndk" && mv "$TMP/ndk"/* "$SDK/ndk/28.2.13676358"
fi
if [ ! -x "$SDK/cmake/3.22.1/bin/cmake" ]; then
  curl -sSL -o "$TMP/cmake.zip" "$REPO/cmake-3.22.1-darwin.zip"
  mkdir -p "$SDK/cmake/3.22.1" "$TMP/cmake" && unzip -q "$TMP/cmake.zip" -d "$TMP/cmake" && cp -R "$TMP/cmake"/* "$SDK/cmake/3.22.1/"
fi
if [ ! -d "$SDK/platform-tools" ]; then
  curl -sSL -o "$TMP/t.zip" "$REPO/platform-tools_r37.0.1-darwin.zip"
  unzip -q "$TMP/t.zip" -d "$SDK"
fi
rm -rf "$TMP"
echo "sdk.dir=$SDK" > "$ROOT/local.properties"
echo "Android SDK installed in $SDK"
