// test/core/screen_codes_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/screen_codes.dart';

void main() {
  test('codes are S01..S67, in order, with no gaps or repeats', () {
    final expected = [
      for (var i = 1; i <= 67; i++) 'S${i.toString().padLeft(2, '0')}',
    ];
    expect(ScreenCodes.all, expected);
  });

  test('the code table in the main spec lists exactly these codes', () {
    final spec = File(
      '../docs/superpowers/specs/2026-10-01-remaining-screens.md',
    ).readAsStringSync();
    // Only the code table in section 2; later sections have other S-tables.
    final start = spec.indexOf('## 2. Mã màn hình');
    final table = spec.substring(start, spec.indexOf('\n## ', start + 1));
    final inSpec = RegExp(
      r'^\| (S\d\d) \|',
      multiLine: true,
    ).allMatches(table).map((m) => m.group(1)!).toList();
    expect(inSpec, ScreenCodes.all);
  });

  test('existing screens use the codes the spec assigns them', () {
    expect(ScreenCodes.login, 'S28');
    expect(ScreenCodes.role, 'S29');
    expect(ScreenCodes.profile, 'S30');
    expect(ScreenCodes.settings, 'S31');
    expect(ScreenCodes.register, 'S41');
    expect(ScreenCodes.editProfile, 'S42');
    expect(ScreenCodes.splash, 'S66');
    expect(ScreenCodes.sessionError, 'S67');
  });
}
