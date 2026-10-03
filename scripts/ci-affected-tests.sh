#!/usr/bin/env bash
# scripts/ci-affected-tests.sh
#
# Detects which Flutter test files to run based on changed files in the PR.
# Outputs a newline-separated list of test file paths (relative to app_flutter/).
#
# Strategy:
#   1. If pubspec.yaml, analysis_options.yaml, or dart_test.yaml changed → run ALL tests
#   2. If core/ lib files changed → run ALL tests (core is shared by everything)
#   3. If features/X or data/X changed → run only tests in that subtree
#   4. If only non-dart files changed (docs, CI, etc.) → run NO tests
#
# Usage:
#   scripts/ci-affected-tests.sh <base-ref>
#   e.g.  scripts/ci-affected-tests.sh origin/develop
#
# Output: file list or the literal string "ALL" or "NONE"
set -euo pipefail

BASE_REF="${1:-origin/develop}"
APP_DIR="app_flutter"

# Get changed files relative to repo root
CHANGED_FILES=$(git diff --name-only "$BASE_REF"...HEAD -- "$APP_DIR/" 2>/dev/null || \
                git diff --name-only "$BASE_REF" HEAD -- "$APP_DIR/" 2>/dev/null || \
                echo "")

if [ -z "$CHANGED_FILES" ]; then
  echo "NONE"
  exit 0
fi

# ── Check for "run everything" triggers ─────────────────────────────
GLOBAL_TRIGGERS="pubspec.yaml pubspec.lock analysis_options.yaml dart_test.yaml l10n.yaml"
for trigger in $GLOBAL_TRIGGERS; do
  if echo "$CHANGED_FILES" | grep -q "$APP_DIR/$trigger"; then
    echo "ALL"
    exit 0
  fi
done

# If core/ lib files changed, run all tests (core is imported everywhere)
if echo "$CHANGED_FILES" | grep -q "$APP_DIR/lib/core/"; then
  echo "ALL"
  exit 0
fi

# If main.dart or app-level files changed, run all tests
if echo "$CHANGED_FILES" | grep -q "$APP_DIR/lib/main"; then
  echo "ALL"
  exit 0
fi

# ── Map changed lib files → test files ──────────────────────────────
TEST_FILES=""

for file in $CHANGED_FILES; do
  # Strip app_flutter/ prefix
  rel="${file#$APP_DIR/}"

  # If it's already a test file, include it directly
  if [[ "$rel" == test/*_test.dart ]]; then
    TEST_FILES="$TEST_FILES $rel"
    continue
  fi

  # Map lib/X.dart → test/X_test.dart
  if [[ "$rel" == lib/*.dart ]]; then
    test_file="test/${rel#lib/}"
    test_file="${test_file%.dart}_test.dart"
    if [ -f "$APP_DIR/$test_file" ]; then
      TEST_FILES="$TEST_FILES $test_file"
    else
      # No direct test file; find tests in the same directory
      dir="test/$(dirname "${rel#lib/}")"
      if [ -d "$APP_DIR/$dir" ]; then
        while IFS= read -r f; do
          TEST_FILES="$TEST_FILES ${f#$APP_DIR/}"
        done < <(find "$APP_DIR/$dir" -name "*_test.dart" -maxdepth 1 2>/dev/null)
      fi
    fi
    continue
  fi
done

# Deduplicate and output
if [ -z "$TEST_FILES" ]; then
  # Changed files exist but no matching tests found (non-dart changes)
  echo "NONE"
else
  echo "$TEST_FILES" | tr ' ' '\n' | sort -u | grep -v '^$'
fi
