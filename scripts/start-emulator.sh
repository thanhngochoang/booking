#!/usr/bin/env bash
# Boots the project AVD if no Android emulator is running, then waits until Android has booted.
# Used by the VS Code preLaunchTask so F5 works with no emulator open. Usage: start-emulator.sh [avd]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/env.sh" >/dev/null
export HOME="$ROOT/.home"
AVD="${1:-photobooking_api35}"

if adb devices | grep -q '^emulator-.*device$'; then
  echo "Emulator already running."
  exit 0
fi

echo "Starting $AVD..."
# New session (setsid via perl, macOS has no setsid binary): the VS Code task terminal sends SIGHUP
# when this script exits, and the emulator ignores nohup and shuts down unless it is detached.
perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' "$ANDROID_HOME/emulator/emulator" -avd "$AVD" \
  </dev/null >"$ROOT/.home/emulator.log" 2>&1 &
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
echo "Emulator ready."
