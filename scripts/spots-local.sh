#!/usr/bin/env bash
# Staff spots CLI against the local emulators (scripts/backend-local.sh must be running).
set -euo pipefail

usage() {
  cat <<'EOF2'
Usage: scripts/spots-local.sh <command> [args]   (same commands as the CLI below)

Runs the staff spots CLI against the local emulators started by scripts/backend-local.sh
(Firestore 127.0.0.1:8080, Auth 127.0.0.1:9099, Storage 127.0.0.1:9199). It unsets
GOOGLE_APPLICATION_CREDENTIALS and never touches a real project.

Project id: $FIREBASE_PROJECT, else project_info.project_id of
app_flutter/android/app/google-services.json, else demo-nag.
Bucket: $STORAGE_BUCKET, else $FIREBASE_STORAGE_BUCKET, else project_info.storage_bucket of the
same file, else <project>.appspot.com.
Admin: seed-staff-admin (app_flutter/firebase/functions/seed/README.md).

Example:
  scripts/spots-local.sh list
  scripts/spots-local.sh rank
  scripts/spots-local.sh pin seed-spot-cau-dat --actor seed-staff-admin
  scripts/spots-local.sh claims list
  scripts/spots-local.sh claims approve <claimId> --actor seed-staff-admin
  scripts/spots-local.sh claims reject <claimId> --reason "Giấy tờ không khớp" --actor seed-staff-admin
  scripts/spots-local.sh access seed-spot-ho-tay --type ticket --fee "Người lớn=50000" --actor seed-staff-admin
  scripts/spots-local.sh organizers suspend seed-organizer-bai-da --actor seed-staff-admin

CLI usage:
EOF2
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FN="$ROOT/app_flutter/firebase/functions"
GS="$ROOT/app_flutter/android/app/google-services.json"

# Help must not start anything: the CLI's --help only prints text (no Firebase, no emulator).
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      if [ -d "$FN/node_modules" ]; then
        exec npm --prefix "$FN" run --silent spots -- --help
      fi
      echo "(run npm --prefix app_flutter/firebase/functions ci to see the CLI's own usage)"
      exit 0
      ;;
  esac
done

# JDK/CA setup from env.sh is written for interactive shells, so relax -e/-u around it.
set +eu
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh" >/dev/null
set -eu
export HOME="$ROOT/.home"
mkdir -p "$HOME"
# Local runs use no credentials; a key in the environment must never reach the Admin SDK.
unset GOOGLE_APPLICATION_CREDENTIALS
# firebase-admin and the Storage client prefer these over GCLOUD_PROJECT / FIREBASE_STORAGE_EMULATOR_HOST.
unset GOOGLE_CLOUD_PROJECT STORAGE_EMULATOR_HOST

gs_value() { # gs_value <project_info key>
  [ -f "$GS" ] && node -p 'require(process.argv[1]).project_info[process.argv[2]] || ""' "$GS" "$1" 2>/dev/null || true
}

if [ -n "${FIREBASE_PROJECT:-}" ]; then
  PROJECT="$FIREBASE_PROJECT"
else
  PROJECT="$(gs_value project_id)"
  [ -n "$PROJECT" ] || PROJECT=demo-nag
fi

if [ -z "${STORAGE_BUCKET:-}" ]; then
  STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-}"
  [ -n "$STORAGE_BUCKET" ] || STORAGE_BUCKET="$(gs_value storage_bucket)"
  [ -n "$STORAGE_BUCKET" ] || STORAGE_BUCKET="$PROJECT.appspot.com"
fi

[ -d "$FN/node_modules" ] || npm --prefix "$FN" ci

for port in 8080 9099; do
  if ! curl -fsS "http://127.0.0.1:$port/" >/dev/null 2>&1; then
    echo "Emulator on 127.0.0.1:$port does not answer: start scripts/backend-local.sh first." >&2
    exit 1
  fi
done

export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
export FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199
export GCLOUD_PROJECT="$PROJECT"
export STORAGE_BUCKET

exec npm --prefix "$FN" run --silent spots -- "$@"
