#!/usr/bin/env bash
# Creates a git worktree under .worktrees/<name> that builds and debugs like the main checkout.
# The toolchain (.flutter, .android-sdk, .home, .pub-cache, .certs, .jdk) and the local secrets
# (.env, google-services.json, firebase_options.dart) are not in git, so they are symlinked from
# the main checkout instead of downloaded again. The AVD, Gradle cache and debug key are shared.
#   scripts/worktree.sh <branch> [name]     existing branch, or a new one from origin/develop
#   scripts/worktree.sh --link <path>       only (re)create the links in an existing worktree
# Open the worktree folder itself in VS Code (its .vscode/ is the branch's own).
set -euo pipefail
MAIN="$(git -C "$(dirname "${BASH_SOURCE[0]}")" worktree list --porcelain | sed -n '1s/^worktree //p')"

link_all() {
  local wt="$1"
  for p in .flutter .android-sdk .home .pub-cache .certs .jdk .env \
           app/google-services.json \
           app_flutter/android/app/google-services.json \
           app_flutter/lib/firebase_options.dart; do
    [ -e "$MAIN/$p" ] || continue
    if [ -e "$wt/$p" ] && [ ! -L "$wt/$p" ]; then echo "keep $p (real file in the worktree)"; continue; fi
    mkdir -p "$(dirname "$wt/$p")"
    ln -sfn "$MAIN/$p" "$wt/$p"
  done
  echo "Linked toolchain and secrets into $wt"
}

if [ "${1:-}" = --link ]; then link_all "$(cd "${2:?path}" && pwd)"; exit 0; fi

BRANCH="${1:?usage: scripts/worktree.sh <branch> [name]}"
NAME="${2:-${BRANCH##*/}}"
WT="$MAIN/.worktrees/$NAME"
[ -e "$WT" ] && { echo "$WT already exists (use --link to refresh links)"; exit 1; }
git -C "$MAIN" fetch -q origin
if git -C "$MAIN" show-ref -q --verify "refs/heads/$BRANCH"; then
  git -C "$MAIN" worktree add -q "$WT" "$BRANCH"
elif git -C "$MAIN" show-ref -q --verify "refs/remotes/origin/$BRANCH"; then
  git -C "$MAIN" worktree add -q --track -b "$BRANCH" "$WT" "origin/$BRANCH"
else
  git -C "$MAIN" worktree add -q --no-track -b "$BRANCH" "$WT" origin/develop
fi
link_all "$WT"
echo "Open in VS Code: code \"$WT\"   (remove later: git worktree remove \"$WT\")"
