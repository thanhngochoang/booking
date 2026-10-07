import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Customers pay 100% up front, so no Vietnamese string may talk about a
  // deposit ("cọc").
  test('no Vietnamese string mentions "cọc"', () {
    final arb =
        jsonDecode(File('lib/l10n/app_vi.arb').readAsStringSync())
            as Map<String, dynamic>;
    final offenders = <String>[
      for (final e in arb.entries)
        if (!e.key.startsWith('@') &&
            e.value is String &&
            (e.value as String).toLowerCase().contains('cọc'))
          '${e.key}: ${e.value}',
    ];
    expect(offenders, isEmpty);
  });
}
