import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/lunar.dart';
import 'package:photobooking/core/vn_time.dart';

/// Dates are compared by their `yyyy-MM-dd` key so the test does not depend on
/// whether the port returns UTC or local midnight.
String? key(DateTime? d) => d == null ? null : dayKeyOf(d);

void main() {
  test('Tết (1/1) 2024-2033', () {
    const tet = {
      2024: '2024-02-10',
      2025: '2025-01-29',
      2026: '2026-02-17',
      2027: '2027-02-06',
      2028: '2028-01-26',
      2029: '2029-02-13',
      2030: '2030-02-02',
      2031: '2031-01-23',
      2032: '2032-02-11',
      2033: '2033-01-31',
    };
    tet.forEach((year, solar) {
      expect(key(lunarToSolar(1, 1, year)), solar, reason: 'Tết $year');
      final l = solarToLunar(parseDayKey(solar)!);
      expect((l.day, l.month, l.year, l.leap), (1, 1, year, false));
    });
  });

  test('Giỗ Tổ (10/3), 23/12 and mùng 5 Tết', () {
    expect(key(lunarToSolar(10, 3, 2025)), '2025-04-07');
    expect(key(lunarToSolar(10, 3, 2026)), '2026-04-26');
    expect(key(lunarToSolar(23, 12, 2025)), '2026-02-10');
    expect(key(lunarToSolar(5, 1, 2026)), '2026-02-21');
  });

  test('knows the leap month', () {
    final l = solarToLunar(DateTime(2025, 7, 25));
    expect((l.day, l.month, l.year, l.leap), (1, 6, 2025, true));
    expect(key(lunarToSolar(1, 6, 2025, leap: true)), '2025-07-25');
    expect(lunarToSolar(1, 7, 2025, leap: true), isNull);
    expect(lunarToSolar(1, 6, 2026, leap: true), isNull);
    expect(leapMonthOf(2025), 6);
    expect(leapMonthOf(2028), 5);
    expect(leapMonthOf(2031), 3);
    expect(leapMonthOf(2026), isNull);
  });

  test('month lengths', () {
    expect(lunarMonthLength(6, 2025, leap: true), 29);
    expect(lunarMonthLength(1, 2026), 30);
    expect(lunarMonthLength(12, 2025), 29);
    expect(() => lunarMonthLength(7, 2025, leap: true), throwsArgumentError);
  });

  test('solarToLunar reads the date part only', () {
    final a = solarToLunar(DateTime(2026, 2, 17, 23, 59));
    final b = solarToLunar(DateTime.utc(2026, 2, 17));
    expect((a.day, a.month, a.year, a.leap), (1, 1, 2026, false));
    expect((b.day, b.month, b.year, b.leap), (1, 1, 2026, false));
  });

  test('round trips every day 2024-01-01 .. 2033-12-31', () {
    var d = DateTime.utc(2024);
    final end = DateTime.utc(2033, 12, 31);
    while (!d.isAfter(end)) {
      final l = solarToLunar(d);
      expect(
        key(lunarToSolar(l.day, l.month, l.year, leap: l.leap)),
        dayKeyOf(d),
        reason: dayKeyOf(d),
      );
      expect(
        l.day >= 1 && l.day <= lunarMonthLength(l.month, l.year, leap: l.leap),
        isTrue,
        reason: dayKeyOf(d),
      );
      d = DateTime.utc(d.year, d.month, d.day + 1);
    }
  });

  test('lunarLabel: bare number, month on the 1st', () {
    expect(lunarLabel(DateTime(2026, 11, 9)), '1/10');
    expect(lunarLabel(DateTime(2026, 11, 23)), '15');
    expect(lunarLabel(DateTime(2026, 11, 10)), '2');
  });
}
