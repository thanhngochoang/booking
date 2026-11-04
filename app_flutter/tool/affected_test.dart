// Usage: dart run tool/affected_test.dart <base-ref> [--list|--run|--json ...]
// (run from app_flutter/). Picks the tests a branch can affect; when unsure
// it picks all of them. How it works and how to extend the rules:
// docs/testing/affected-tests.md.
//
// Uses dart: libraries only, so CI can run it without `pub get`.
import 'dart:io';

import 'affected/analysis.dart';
import 'affected/cli.dart';

/// Rules for this repo on top of the generic defaults.
const config = AffectedConfig(
  repoGlobalFiles: [
    '.github/workflows/flutter.yml', // how the tests are run
    'design-system/**', // tokens.json → lib/core/theme/tokens.g.dart in CI
  ],
  // The Firebase backend and packages/domain live in booking-be (#299). The
  // tests that read them read ../.backend/, pinned by ../backend.lock and
  // filled by ../scripts/sync-backend.sh; the guard they import
  // (test/support/backend_snapshot.dart) reads both literally, so a change
  // to either selects them all. No rule is needed for that.
  passiveFiles: [
    ...AffectedConfig.defaultPassiveFiles,
    '.claude/**',
  ],
);

Future<void> main(List<String> args) async {
  exitCode = await runCli(args, config: config);
}
