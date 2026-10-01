import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/format.dart';

void main() {
  test('distance has one decimal, a comma and the unit', () {
    expect(formatDistance(1.24), '1,2 km');
    expect(formatDistance(12), '12,0 km');
    expect(formatDistance(0.04), '0,1 km', reason: 'never shows 0,0 km');
  });

  test('formatMoney: full and short forms', () {
    expect(formatMoney(1500000), '1.500.000₫');
    expect(formatMoney(250000), '250.000₫');
    expect(formatMoney(500), '500₫');
    expect(formatMoney(1500000, short: true), '1,5M');
    expect(formatMoney(8000000, short: true), '8M');
    expect(formatMoney(250000, short: true), '250K');
    expect(formatMoney(600000, short: true), '600K');
    expect(formatMoney(1250, short: true), '1,3K');
    expect(formatMoney(999, short: true), '999₫');
    expect(formatMoney(12000000, short: true), '12M');
  });
}
