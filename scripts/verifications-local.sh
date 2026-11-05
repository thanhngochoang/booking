#!/usr/bin/env bash
# Staff verification CLI (S21) against the local emulators (scripts/backend-local.sh must be running).
# The real script is booking-be's scripts/verifications-local.sh (#299); this wrapper runs it from the booking-be
# checkout ($BOOKING_BE_DIR, default ../booking-be) with this repo's JDK, CA certificates, HOME and
# APP_DIR (scripts/bin/_booking-be.sh). Options, --help included, are passed through.
set -euo pipefail
# shellcheck source=scripts/bin/_booking-be.sh
source "$(dirname "$0")/bin/_booking-be.sh"
exec "$BE/scripts/verifications-local.sh" "$@"
