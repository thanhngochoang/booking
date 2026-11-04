#!/usr/bin/env bash
# Checks out the booking-be files the app tests read (PATHS below) at the commit pinned in
# backend.lock into ./.backend (gitignored). The tests fail with a hint when it is missing or
# not at that commit (app_flutter/test/support/backend_snapshot.dart).
#   scripts/sync-backend.sh             fetch the pinned commit (no-op when already there)
#   scripts/sync-backend.sh --update    pin the tip of the lock's branch, then fetch it
#   BACKEND_REPO=$PWD/../booking-be scripts/sync-backend.sh    read a local clone (offline)
# CI passes BACKEND_REPO=git@github.com:thanhngochoang/booking-be.git with a read-only deploy key.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/backend.lock"

# Every booking-be file an app test reads; a test that reads a new one adds it here.
PATHS=(
  firebase/firebase.json
  firebase/firestore.rules
  firebase/storage.rules
  firebase/functions/src/config.ts
  firebase/functions/seed/fixtures.ts
  packages/domain/src/vn_banks.ts
  packages/domain/src/recruit_areas.ts
  packages/domain/test/fixtures/booking_policy.json
  packages/domain/test/fixtures/payout_account.json
)

repo=; branch=; ref=
while IFS='=' read -r key value; do
  case "$key" in repo) repo=$value ;; branch) branch=$value ;; ref) ref=$value ;; esac
done < "$LOCK"
[ -n "$repo" ] && [ -n "$branch" ] && [ -n "$ref" ] || { echo "$LOCK: need repo=, branch= and ref=" >&2; exit 1; }
src="${BACKEND_REPO:-$repo}"

if [ "${1:-}" = --update ]; then
  new="$(git ls-remote "$src" "refs/heads/$branch" | cut -f1)"
  [ -n "$new" ] || { echo "no branch $branch at $src" >&2; exit 1; }
  sed -i.bak "s/^ref=.*/ref=$new/" "$LOCK" && rm -f "$LOCK.bak"
  ref="$new"
  echo "backend.lock: ref=$ref"
fi

dest="$ROOT/.backend"
if [ -f "$dest/.backend-ref" ] && [ "$(cat "$dest/.backend-ref")" = "$ref" ]; then
  echo ".backend already at $ref"
  exit 0
fi
tmp="$(mktemp -d "${TMPDIR:-/tmp}/backend.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
filter=(--filter=blob:none)   # blob-less over the network; a local clone ignores it
[ -d "$src" ] && filter=()
git clone -q --no-checkout ${filter[@]+"${filter[@]}"} "$src" "$tmp/repo"
git -C "$tmp/repo" sparse-checkout set --no-cone "${PATHS[@]}"
git -C "$tmp/repo" checkout -q "$ref"
missing=0
for p in "${PATHS[@]}"; do
  [ -f "$tmp/repo/$p" ] || { echo "booking-be $ref has no $p (renamed? update PATHS and the test that reads it)" >&2; missing=1; }
done
[ "$missing" = 0 ] || exit 1
rm -rf "$tmp/repo/.git" "$dest"
mv "$tmp/repo" "$dest"
echo "$ref" > "$dest/.backend-ref"
echo ".backend at $ref"
