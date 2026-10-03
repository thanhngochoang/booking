#!/usr/bin/env bash
# Boots the project AVD if no Android device is connected (AVD, Genymotion or phone), then waits
# until Android has booted. VS Code task "Bật emulator dự án". Usage: start-emulator.sh [avd]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/env.sh" >/dev/null
export HOME="$ROOT/.home"
AVD="${1:-photobooking_api35}"

if adb devices | tail -n +2 | grep -q '[[:space:]]device$'; then
  echo "A device is already connected:"; adb devices | tail -n +2
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
