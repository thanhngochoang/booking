import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails (never skips) when `../.backend` is missing or not at the commit pinned
/// in `../backend.lock`. The paths are literal on purpose: tool/affected_test.dart
/// selects every test that imports this file when backend.lock or the sync script
/// changes (docs/testing/affected-tests.md).
void requireBackendSnapshot() {
  final lock = File('../backend.lock').readAsStringSync();
  final script = File('../scripts/sync-backend.sh');
  final marker = File('../.backend/.backend-ref');
  final ref = RegExp(r'^ref=(\S+)', multiLine: true).firstMatch(lock)?.group(1);
  final have = marker.existsSync() ? marker.readAsStringSync().trim() : null;
  if (ref == null || have != ref) {
    fail('booking-be snapshot ${have == null ? 'missing' : 'at $have'}, backend.lock wants $ref: '
        'run ${script.path} from app_flutter/ '
        '(offline: BACKEND_REPO=\$PWD/../booking-be scripts/sync-backend.sh)');
  }
}
