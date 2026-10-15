// test/core/screen_codes_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/screen_codes.dart';

void main() {
  test('codes are Sxx.yy, sorted, unique, numbered from .01 without gaps in each use case', () {
    final codes = ScreenCodes.all;
    expect(codes, everyElement(matches(RegExp(r'^S\d{2}\.\d{2}$'))));
    expect(codes.toSet().length, codes.length);
    expect([...codes]..sort(), codes);
    final byUseCase = <String, List<int>>{};
    for (final c in codes) {
      byUseCase
          .putIfAbsent(c.substring(0, 3), () => [])
          .add(int.parse(c.substring(4)));
    }
    // Use case numbers reserved for screens outside the app (S28: studio web
    // dashboard, #161) are skipped; every other number is used, in order.
    const reserved = {'S28'};
    final useCases = byUseCase.keys.toList();
    expect(useCases, [
      for (var i = 1; i <= useCases.length + reserved.length; i++)
        if (!reserved.contains('S${i.toString().padLeft(2, '0')}'))
          'S${i.toString().padLeft(2, '0')}',
    ]);
    for (final e in byUseCase.entries) {
      expect(e.value, [
        for (var i = 1; i <= e.value.length; i++) i,
      ], reason: e.key);
    }
  });

  test('the code table in the main spec lists exactly these codes', () {
    final spec = File(
      '../docs/superpowers/specs/2026-10-01-remaining-screens.md',
    ).readAsStringSync();
    // Only the code table in section 2; later sections have other S-tables.
    final start = spec.indexOf('## 2. Mã màn hình');
    final table = spec.substring(start, spec.indexOf('\n## ', start + 1));
    // S28 and S23.08–S23.23 belong to the web dashboard (Phase 1.5,
    // 2026-10-08-dashboard-web-design.md §6), which has its own screen-codes.ts
    // rather than being compiled into the Flutter app.
    final inSpec = RegExp(
      r'^\| (S\d\d\.\d\d) \|',
      multiLine: true,
    ).allMatches(table).map((m) => m.group(1)!).where((c) {
      if (c.startsWith('S28.')) return false;
      if (c.startsWith('S23.') && int.parse(c.substring(4)) > 7) return false;
      return true;
    }).toList();
    expect(inSpec, ScreenCodes.all);
  });

  test('existing screens use the codes the spec assigns them', () {
    expect(ScreenCodes.splash, 'S01.01');
    expect(ScreenCodes.sessionError, 'S01.02');
    expect(ScreenCodes.login, 'S01.03');
    expect(ScreenCodes.register, 'S01.04');
    expect(ScreenCodes.role, 'S01.05');
    expect(ScreenCodes.home, 'S02.01');
    expect(ScreenCodes.bookService, 'S04.01');
    expect(ScreenCodes.profile, 'S09.01');
    expect(ScreenCodes.settings, 'S09.02');
    expect(ScreenCodes.editProfile, 'S09.03');
  });
}
