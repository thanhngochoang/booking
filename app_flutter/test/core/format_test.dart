import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/vn_time.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

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
    expect(formatMoney(999950, short: true), '1M');
    expect(formatMoney(999950, short: true), isNot('1000K'));
    expect(formatMoney(999949, short: true), '999,9K');
    expect(formatMoney(12000000, short: true), '12M');
  });

  test('weekday labels run T2 to T7 then CN', () {
    expect(
      [
        for (var d = DateTime.monday; d <= DateTime.sunday; d++)
          weekdayLabel(d),
      ],
      ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
    );
  });

  test('formatDay and formatDayMonth read the calendar fields', () {
    final saturday = DateTime.utc(2026, 10, 3); // a Saturday
    expect(formatDay(saturday), 'T7 03/10');
    expect(formatDayMonth(saturday), '03/10');
    expect(formatDay(DateTime.utc(2026, 10, 4)), 'CN 04/10');
    expect(formatDay(DateTime.utc(2026, 12, 25)), 'T6 25/12');
  });

  test('formatDay of a Vietnamese date shifted past midnight', () {
    // 17:30 UTC on Fri 2 Oct is 00:30 on Sat 3 Oct in Vietnam.
    expect(formatDay(toVn(DateTime.utc(2026, 10, 2, 17, 30))), 'T7 03/10');
  });

  test('formatRating has one decimal and a comma', () {
    expect(formatRating(4.9), '4,9');
    expect(formatRating(5), '5,0');
    expect(formatRating(4.56), '4,6');
    expect(formatRating(4.54), '4,5');
    expect(formatRating(0), '0,0');
  });

  test('priceFromLabel: null for unknown or non-positive prices', () {
    final l = AppLocalizationsVi();
    expect(priceFromLabel(1500000, l), 'từ 1,5M');
    expect(priceFromLabel(250000, l), 'từ 250K');
    expect(priceFromLabel(0, l), isNull);
    expect(priceFromLabel(-5, l), isNull);
    expect(priceFromLabel(null, l), isNull);
  });

  test('formatDuration in hours and minutes', () {
    final l = AppLocalizationsVi();
    expect(formatDuration(45, l), '45 phút');
    expect(formatDuration(60, l), '1 giờ');
    expect(formatDuration(120, l), '2 giờ');
    expect(formatDuration(90, l), '1 giờ 30 phút');
    expect(formatDuration(480, l), '8 giờ');
  });
}
