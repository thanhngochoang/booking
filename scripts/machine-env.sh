#!/usr/bin/env bash
# Saves this machine's Android SDK paths into the shell profile, so VS Code (which reads the shell
# environment when it starts) lists the devices and emulators of the repo's toolchain. Idempotent:
# the block between the markers is replaced on every run, with the path of the main checkout on
# THIS machine. Called by scripts/setup.sh; run it again after moving the repo.
#   scripts/machine-env.sh            write the block
#   scripts/machine-env.sh --print    only print it
set -euo pipefail
# Main checkout (not a worktree), so every worktree shares one SDK and AVD.
MAIN="$(git -C "$(dirname "${BASH_SOURCE[0]}")" worktree list --porcelain | sed -n '1s/^worktree //p')"
REAL_HOME=$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || true)
REAL_HOME="${REAL_HOME:-$HOME}"
case "${SHELL:-/bin/zsh}" in */bash) PROFILE="$REAL_HOME/.bash_profile" ;; *) PROFILE="$REAL_HOME/.zshrc" ;; esac
BEGIN='# >>> booking repo (scripts/machine-env.sh) >>>'
END='# <<< booking repo <<<'

BLOCK=$(cat <<EOS
$BEGIN
export BOOKING="$MAIN"
export ANDROID_HOME="\$BOOKING/.android-sdk"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"
export ANDROID_AVD_HOME="\$BOOKING/.home/.android/avd"
export PATH="\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$PATH"
$END
EOS
)

if [ "${1:-}" = --print ]; then echo "$BLOCK"; exit 0; fi

touch "$PROFILE"
TMP="$(mktemp)"
# Drop the previous managed block and the old hand-pasted block from docs/SETUP.md (same variables).
awk -v b="$BEGIN" -v e="$END" '
  $0==b {skip=1; next} $0==e {skip=0; next} skip {next}
  /^# booking repo \(Android SDK \+ AVD inside the repo\)$/ {old=1; next}
  old && /^(BOOKING=|export (ANDROID_HOME|ANDROID_SDK_ROOT|ANDROID_AVD_HOME)=|export PATH="\$ANDROID_HOME)/ {next}
  {old=0; print}
' "$PROFILE" > "$TMP"
printf '%s\n\n%s\n' "$(cat "$TMP")" "$BLOCK" > "$PROFILE"
rm -f "$TMP"
echo "Updated $PROFILE (ANDROID_HOME=$MAIN/.android-sdk)."

# Also store the SDK in this machine's Flutter settings (~/.config/flutter), which the VS Code
# Flutter daemon reads on every start: devices show up even in a VS Code that was opened before the
# profile changed (Reload Window is enough) or launched without the shell environment.
if [ -x "$MAIN/.flutter/bin/flutter" ]; then
  HOME="$REAL_HOME" FLUTTER_SUPPRESS_ANALYTICS=true "$MAIN/.flutter/bin/flutter" config --android-sdk "$MAIN/.android-sdk" >/dev/null \
    && echo "Flutter settings: android-sdk = $MAIN/.android-sdk"
fi
echo "VS Code: Cmd+Shift+P > Developer: Reload Window (devices); Cmd+Q and reopen to pick up the new shell variables too."
