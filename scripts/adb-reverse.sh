#!/usr/bin/env bash
# Makes the local backend reachable at 127.0.0.1 on every connected Android device: AVD, Genymotion,
# USB or Wi-Fi phone. `adb reverse` forwards the device's own ports to this Mac, so the app uses the
# same EMULATOR_HOST (127.0.0.1) everywhere and scripts/backend-local.sh needs no --lan.
# Ports: the emulators in app_flutter/firebase/firebase.json (Auth, Firestore, Functions, Storage).
# Usage: scripts/adb-reverse.sh [serial]   (default: every device in state "device")
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/bin/_jvm-env.sh"
ADB="$ANDROID_HOME/platform-tools/adb"
[ -x "$ADB" ] || ADB=adb
PORTS=(9099 8080 5001 9199)

if [ $# -gt 0 ]; then
  SERIALS=("$1")
else
  SERIALS=()
  while read -r serial state _; do
    [ "$state" = device ] && SERIALS+=("$serial")
  done < <("$ADB" devices | tail -n +2)
fi
[ ${#SERIALS[@]} -gt 0 ] || { echo "No Android device connected (adb devices)."; exit 0; }

for s in "${SERIALS[@]}"; do
  for p in "${PORTS[@]}"; do "$ADB" -s "$s" reverse "tcp:$p" "tcp:$p" >/dev/null; done
  echo "adb reverse ${PORTS[*]} -> $s"
done
