# Sourced by scripts/backend-local.sh, spots-local.sh, awards-local.sh and verifications-local.sh.
# The Firebase backend lives in booking-be (#299); these wrappers run its scripts from the booking-be
# checkout ($BOOKING_BE_DIR, default the sibling ../booking-be) with this repo's environment:
# the JDK and corporate CA of scripts/env.sh, HOME inside the repo, and APP_DIR for the project id
# (app_flutter/android/app/google-services.json). Sets ROOT (this repo) and BE (the checkout).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BE="${BOOKING_BE_DIR:-$ROOT/../booking-be}"
[ -d "$BE" ] && BE="$(cd "$BE" && pwd)"
if [ ! -f "$BE/firebase/firebase.json" ]; then
  echo "booking-be checkout not found at $BE: git clone https://github.com/thanhngochoang/booking-be.git \"$BE\" (or set BOOKING_BE_DIR)" >&2
  exit 1
fi

# JDK for the Firestore emulator and the corporate CA for npm (NODE_EXTRA_CA_CERTS).
# env.sh is written for interactive shells (some of its lines return non-zero), so relax -e/-u.
set +eu
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh" >/dev/null
set -eu
export HOME="$ROOT/.home"   # firebase-tools and npm write their caches inside the repo
mkdir -p "$HOME"
export APP_DIR="$ROOT/app_flutter"
