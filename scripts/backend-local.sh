#!/usr/bin/env bash
# Local backend in one command: Firebase Emulator Suite (Auth, Firestore, Functions, Storage, UI)
# with saved data, the Cloud Functions build in watch mode, and the seed on first start.
# The real script is booking-be's scripts/backend-local.sh (#299); this wrapper runs it from the booking-be
# checkout ($BOOKING_BE_DIR, default ../booking-be) with this repo's JDK, CA certificates, HOME and
# APP_DIR (scripts/bin/_booking-be.sh). Options, --help included, are passed through.
set -euo pipefail
# shellcheck source=scripts/bin/_booking-be.sh
source "$(dirname "$0")/bin/_booking-be.sh"
exec "$BE/scripts/backend-local.sh" "$@"
