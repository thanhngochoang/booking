// test/features/organizer/terms_assets_test.dart
//
// Decision 17: the two S30 terms texts ship as drafts, registered in pubspec.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  const files = [
    'assets/terms/organizer_terms_vi.md',
    'assets/terms/public_place_commitment_vi.md',
  ];

  test('the terms drafts exist, are marked as drafts and are bundled', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    final assets = (pubspec['flutter'] as Map)['assets'] as List;
    for (final f in files) {
      final text = File(f).readAsStringSync().toLowerCase();
      expect(text, contains('bản nháp, chờ luật sư'), reason: f);
      expect(text, contains('2026-10-18'), reason: f);
      expect(assets, contains(f));
    }
  });
}
