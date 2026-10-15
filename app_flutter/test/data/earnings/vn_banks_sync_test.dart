import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/earnings/vn_banks.dart';

void main() {
  test('bank list equals VN_BANKS', () {
    final ts = File('../packages/domain/src/vn_banks.ts').readAsStringSync();
    final rows = RegExp(
      r"code: '([^']+)', bin: '([^']+)', shortName: '([^']+)', name: '([^']+)'",
    ).allMatches(ts).toList();
    expect(rows, isNotEmpty);
    expect(vnBanks.length, rows.length);
    for (var i = 0; i < rows.length; i++) {
      final m = rows[i];
      expect(
        (
          vnBanks[i].code,
          vnBanks[i].bin,
          vnBanks[i].shortName,
          vnBanks[i].name,
        ),
        (m.group(1), m.group(2), m.group(3), m.group(4)),
        reason: 'row $i',
      );
    }
  });

  test('bankByCode finds an exact code only', () {
    expect(bankByCode('VCB')?.bin, '970436');
    expect(bankByCode('vcb'), isNull);
  });
}
