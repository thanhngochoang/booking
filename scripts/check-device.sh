#!/usr/bin/env bash
# Prints what this machine uses to debug on Android, so two machines can be compared line by line.
# Paste the output when "it runs on my machine but not on yours".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/bin/_jvm-env.sh"
ADB="$ANDROID_HOME/platform-tools/adb"

echo "== Toolchain"
echo "repo            $ROOT"
echo "flutter         $("$ROOT/.flutter/bin/flutter" --version --machine 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["frameworkVersion"],"/ dart",d["dartSdkVersion"])' 2>/dev/null || echo 'missing (scripts/install-flutter.sh)')"
echo "JAVA_HOME       ${JAVA_HOME:-unset}"
echo "ANDROID_HOME    $ANDROID_HOME"
if [ -x "$ADB" ]; then echo "adb (repo)      $("$ADB" version | head -1)"; else echo "adb (repo)      missing (scripts/install-sdk.sh)"; fi
echo "adb on PATH     $(command -v adb || echo none)"
# A second adb server (Genymotion's own, an Android Studio SDK) fights the repo's: "adb server version doesn't match".
for pid in $(pgrep -f 'adb.*fork-server' || true); do
  exe=$(lsof -a -p "$pid" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
  case "$exe" in
    "$ANDROID_HOME"/*) echo "adb server      $exe (repo)" ;;
    *) printf 'WARNING adb server from another SDK: %s\n  -> adb kill-server; Genymotion: Settings > ADB > "Use custom Android SDK tools" = %s\n' "${exe:-pid $pid}" "$ANDROID_HOME" ;;
  esac
done

echo
echo "== VS Code (reads ANDROID_HOME from the shell profile written by scripts/machine-env.sh)"
# _jvm-env.sh moved HOME into the repo; read the real one from the user database.
REAL_HOME=$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
MAIN="$(git -C "$ROOT" worktree list --porcelain | sed -n '1s/^worktree //p')"   # main checkout, also from a worktree
if grep -qF "BOOKING=\"$MAIN\"" "${REAL_HOME:-/nonexistent}/.zshrc" "${REAL_HOME:-/nonexistent}/.bash_profile" 2>/dev/null; then echo "~/.zshrc points at this repo"; else echo "WARNING ~/.zshrc does not point at this repo: run scripts/machine-env.sh, then Cmd+Q VS Code"; fi

echo
echo "== Debug signing key (app_flutter/android/app/debug.keystore, shared by the team)"
keytool -list -v -keystore "$ROOT/app_flutter/android/app/debug.keystore" -storepass android -alias androiddebugkey 2>/dev/null \
  | grep -E 'SHA1:|SHA256:' | sed 's/^[[:space:]]*/                /'

echo
echo "== Connected devices"
if [ -x "$ADB" ]; then
  "$ADB" devices | tail -n +2 | while read -r serial state _; do
    [ -z "$serial" ] && continue
    if [ "$state" != device ]; then echo "$serial  $state  (adb kill-server, then reconnect)"; continue; fi
    model=$("$ADB" -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    api=$("$ADB" -s "$serial" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
    abi=$("$ADB" -s "$serial" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
    manu=$("$ADB" -s "$serial" shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r')
    kind=phone
    case "$serial" in emulator-*) kind=AVD ;; esac
    case "$manu" in Genymobile|Genymotion) kind=Genymotion ;; esac
    rev=$("$ADB" -s "$serial" reverse --list 2>/dev/null | grep -c 'tcp:9099' || true)
    echo "$serial  $kind  $model  API $api  $abi  adb-reverse:$([ "$rev" -gt 0 ] && echo on || echo off)"
  done
fi
echo
echo "Local backend from any device: scripts/backend-local.sh, then VS Code \"Flutter: (debug) + backend local\""
echo "(it runs scripts/adb-reverse.sh and uses EMULATOR_HOST=127.0.0.1)."
