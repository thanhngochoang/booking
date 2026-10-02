// test/data/skills/no_device_score_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app never computes the profile score (spec 2026-10-02 §3)', () {
    expect(
      File('lib/data/skills/skills_completeness.dart').existsSync(),
      isFalse,
    );
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('skills_completeness'))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
