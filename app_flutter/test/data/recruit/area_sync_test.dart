import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/area.dart';

void main() {
  test('builtInAreas ids equal RECRUIT_AREAS ids in packages/domain/src/recruit_areas.ts', () {
    final ts = File('../packages/domain/src/recruit_areas.ts')
        .readAsStringSync();
    final block = RegExp(r'export const RECRUIT_AREAS[^=]*=\s*\[([\s\S]*?)\];')
        .firstMatch(ts);
    expect(block, isNotNull, reason: 'RECRUIT_AREAS not found');
    final ids = [
      for (final m in RegExp(
        r"\{\s*id:\s*'([a-z0-9-]+)'",
      ).allMatches(block!.group(1)!))
        m.group(1)!,
    ];
    expect(ids, isNotEmpty);
    // Same ids in the same order (Decision 6).
    expect(ids, [for (final a in builtInAreas) a.id]);
  });
}
