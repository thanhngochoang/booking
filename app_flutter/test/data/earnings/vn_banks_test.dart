import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/earnings/vn_banks.dart';

void main() {
  test('bankByCode finds an exact code only', () {
    expect(bankByCode('VCB')?.bin, '970436');
    expect(bankByCode('vcb'), isNull);
  });
}
