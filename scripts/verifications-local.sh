#!/usr/bin/env bash
# Staff verification CLI (S21, npm run verifications) against the local emulators
# (scripts/backend-local.sh must be running). Same environment and guards as
# scripts/awards-local.sh; `show` downloads the business photo to $TMPDIR/verifications/<uid>/.
#
# Example (seed: app_flutter/firebase/functions/seed/README.md, "Verification (S21)"):
#   scripts/verifications-local.sh list
#   scripts/verifications-local.sh show seed-photographer-giang
#   scripts/verifications-local.sh approve seed-photographer-giang --actor seed-staff-admin
set -euo pipefail
STAFF_CLI=verifications exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/awards-local.sh" "$@"
