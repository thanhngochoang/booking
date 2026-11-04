import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/area.dart';

import '../../support/backend_snapshot.dart';

void main() {
  setUpAll(requireBackendSnapshot);

  test('builtInAreas ids and centres equal RECRUIT_AREAS in booking-be packages/domain/src/recruit_areas.ts', () {
    final ts = File('../.backend/packages/domain/src/recruit_areas.ts')
        .readAsStringSync();
    final block = RegExp(r'export const RECRUIT_AREAS[^=]*=\s*\[([\s\S]*?)\];')
        .firstMatch(ts);
    expect(block, isNotNull, reason: 'RECRUIT_AREAS not found');
    final areas = [
      for (final m in RegExp(
        r"\{\s*id:\s*'([a-z0-9-]+)',[^}]*?lat:\s*([\d.]+),\s*lng:\s*([\d.]+)",
      ).allMatches(block!.group(1)!))
        (m.group(1)!, double.parse(m.group(2)!), double.parse(m.group(3)!)),
    ];
    expect(areas, isNotEmpty);
    // Same ids, centres and order (Decision 6).
    expect(areas, [for (final a in builtInAreas) (a.id, a.lat, a.lng)]);
  });

  test('the seed instant config areas in booking-be firebase/functions/seed/fixtures.ts are builtInAreas', () {
    final ts = File('../.backend/firebase/functions/seed/fixtures.ts')
        .readAsStringSync();
    final config = ts.indexOf('export const SEED_INSTANT_CONFIG');
    expect(config, isNonNegative, reason: 'SEED_INSTANT_CONFIG not found');
    final block = RegExp(r'\bareas:\s*\[([\s\S]*?)\]')
        .firstMatch(ts.substring(config));
    expect(block, isNotNull, reason: 'SEED_INSTANT_CONFIG.areas not found');
    final areas = [
      for (final m in RegExp(
        r"name:\s*'([^']+)',\s*lat:\s*([\d.]+),\s*lng:\s*([\d.]+)",
      ).allMatches(block!.group(1)!))
        (m.group(1)!, double.parse(m.group(2)!), double.parse(m.group(3)!)),
    ];
    expect(areas, isNotEmpty);
    // Names and centres, in order: what the seed writes to
    // instant_config/current is what the app offers when location is off.
    expect(areas, [for (final a in builtInAreas) (a.name, a.lat, a.lng)]);
  });
}
