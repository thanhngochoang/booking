#!/usr/bin/env bash
# Local backend in one command: Firebase Emulator Suite (Auth, Firestore, Functions, Storage, UI)
# with saved data, the Cloud Functions build in watch mode, and the seed on first start.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/backend-local.sh [--fresh] [--seed] [--lan] [--help]

Starts the Firebase Emulator Suite for app_flutter (Auth 9099, Firestore 8080, Functions 5001,
Storage 9199, Emulator UI http://127.0.0.1:4000) and rebuilds Cloud Functions on every change.
Data is saved to app_flutter/firebase/.emulator-data on Ctrl-C and loaded on the next start.

  --fresh   delete the saved emulator data first (then seed)
  --seed    apply the seed again on top of the saved data
  --lan     listen on 0.0.0.0 instead of 127.0.0.1 (Genymotion, real devices on the same Wi-Fi)
  --help    show this text

Project id: $FIREBASE_PROJECT, else project_info.project_id of
app_flutter/android/app/google-services.json, else demo-nag.
Seed accounts: app_flutter/firebase/functions/seed/README.md
EOF
}

FRESH=0 SEED=0 LAN=0
for arg in "$@"; do
  case "$arg" in
    --fresh) FRESH=1 ;;
    --seed) SEED=1 ;;
    --lan) LAN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FB="$ROOT/app_flutter/firebase"
FN="$FB/functions"
DOMAIN="$ROOT/packages/domain"
DATA="$FB/.emulator-data"
CONFIG="$FB/firebase.json"

# JDK for the Firestore emulator and the corporate CA for npm (NODE_EXTRA_CA_CERTS).
# env.sh is written for interactive shells (some of its lines return non-zero), so relax -e/-u.
set +eu
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh" >/dev/null
set -eu
export HOME="$ROOT/.home"   # firebase-tools and npm write their caches inside the repo
mkdir -p "$HOME"
export JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true

command -v node >/dev/null || { echo "Node.js 22 or newer is required (brew install node@22)." >&2; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 22 ] || { echo "Node.js 22 or newer is required, found $(node -v)." >&2; exit 1; }

GS="$ROOT/app_flutter/android/app/google-services.json"
if [ -n "${FIREBASE_PROJECT:-}" ]; then
  PROJECT="$FIREBASE_PROJECT"
elif [ -f "$GS" ]; then
  PROJECT="$(node -p 'require(process.argv[1]).project_info.project_id' "$GS")"
else
  PROJECT=demo-nag
fi

[ -d "$DOMAIN/node_modules" ] || npm --prefix "$DOMAIN" ci
[ -d "$FN/node_modules" ] || npm --prefix "$FN" ci
npm --prefix "$FN" run --silent build

if [ "$LAN" = 1 ]; then
  CONFIG="$FB/.firebase.lan.json"
  node -e '
    const fs = require("fs");
    const [src, dst] = process.argv.slice(1);
    const c = JSON.parse(fs.readFileSync(src, "utf8"));
    for (const v of Object.values(c.emulators)) if (v && typeof v === "object" && "host" in v) v.host = "0.0.0.0";
    fs.writeFileSync(dst, JSON.stringify(c, null, 2));
  ' "$FB/firebase.json" "$CONFIG"
fi

if [ "$FRESH" = 1 ]; then rm -rf "$DATA"; fi
IMPORT=()
if [ -f "$DATA/firebase-export-metadata.json" ]; then
  IMPORT=(--import "$DATA")
else
  SEED=1
fi

seed_when_ready() {
  for _ in $(seq 1 120); do
    if curl -fsS "http://127.0.0.1:8080/" >/dev/null 2>&1 && curl -fsS "http://127.0.0.1:9099/" >/dev/null 2>&1; then
      FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT="$PROJECT" \
        npm --prefix "$FN" run --silent seed
      return
    fi
    sleep 1
  done
  echo "Emulators did not answer within 120 s; seed skipped (run again with --seed)." >&2
}

WATCH_PID="" SEED_PID=""
cleanup() {
  [ -z "$WATCH_PID" ] || kill "$WATCH_PID" 2>/dev/null || true
  [ -z "$SEED_PID" ] || kill "$SEED_PID" 2>/dev/null || true
}
trap cleanup EXIT

(cd "$FN" && exec node build.mjs --watch) &
WATCH_PID=$!
if [ "$SEED" = 1 ]; then
  seed_when_ready &
  SEED_PID=$!
fi

cat <<EOF
Project: $PROJECT   Emulator UI: http://127.0.0.1:4000   Data: $DATA
Run the app (debug) against it, from app_flutter/:
  Android emulator   flutter run --dart-define=USE_EMULATORS=true
  iOS Simulator      flutter run --dart-define=USE_EMULATORS=true                (after the iOS enablement plan)
  Genymotion         flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.3.2   (start with --lan)
  Real device        flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=<this Mac's LAN IP>   (start with --lan)
Ctrl-C stops everything and saves the data.
EOF

cd "$FN"
"$FN/node_modules/.bin/firebase" emulators:start \
  --config "$CONFIG" --project "$PROJECT" \
  ${IMPORT[@]+"${IMPORT[@]}"} --export-on-exit "$DATA"
