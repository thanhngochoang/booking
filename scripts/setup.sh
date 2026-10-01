#!/usr/bin/env bash
# One-shot environment setup for a new machine. No admin rights needed; everything lands inside the repo.
#   git clone <repo> && cd booking && scripts/setup.sh && source scripts/env.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== 1/5 Checking prerequisites (git, curl, unzip, python3, JDK 17)"
for c in git curl unzip python3; do command -v "$c" >/dev/null || { echo "missing: $c"; exit 1; }; done
if [ ! -x "$ROOT/.jdk/Contents/Home/bin/java" ] && [ ! -x "$ROOT/.jdk/bin/java" ] && [ ! -d /opt/homebrew/opt/openjdk@17 ] && [ ! -d /usr/local/opt/openjdk@17 ]; then
  echo "JDK 17 not found. Either: brew install openjdk@17   (user-owned Homebrew, no sudo)"
  echo "  or download a JDK 17 .tar.gz (Temurin/Zulu, macOS, your CPU arch) and extract it so that .jdk/Contents/Home/bin/java exists."
  exit 1
fi

echo "== 2/5 Android SDK -> .android-sdk/"
scripts/install-sdk.sh

echo "== 3/5 Flutter SDK -> .flutter/"
scripts/install-flutter.sh

echo "== 4/5 Fonts -> app_flutter/assets/fonts/"
[ -x scripts/fetch-fonts.sh ] && scripts/fetch-fonts.sh || echo "   (fetch-fonts.sh not present yet, skip)"

echo "== 5/5 Environment (JAVA_HOME, ANDROID_HOME, truststore, PATH)"
# shellcheck disable=SC1091
source scripts/env.sh
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
flutter doctor
echo
echo "Done. In every new shell run:  source scripts/env.sh"
