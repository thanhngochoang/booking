import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/calendar_days.dart';

void main() {
  test('calendarDay and monthOf drop the time and keep the date', () {
    expect(
      calendarDay(DateTime.utc(2026, 10, 12, 23, 59)),
      DateTime.utc(2026, 10, 12),
    );
    expect(calendarDay(DateTime(2026, 10, 12, 1)), DateTime.utc(2026, 10, 12));
    expect(monthOf(DateTime.utc(2026, 10, 12)), DateTime.utc(2026, 10));
  });

  test('addMonths and lastDayOfMonth cross years and leap days', () {
    expect(addMonths(DateTime.utc(2026, 12), 1), DateTime.utc(2027, 1));
    expect(addMonths(DateTime.utc(2026, 1), -1), DateTime.utc(2025, 12));
    expect(lastDayOfMonth(DateTime.utc(2028, 2)), DateTime.utc(2028, 2, 29));
    expect(lastDayOfMonth(DateTime.utc(2026, 10)), DateTime.utc(2026, 10, 31));
  });

  test('vnToday reads the Vietnamese wall calendar', () {
    expect(vnToday(DateTime.utc(2026, 9, 30, 18)), DateTime.utc(2026, 10, 1));
    expect(
      vnToday(DateTime.utc(2026, 9, 30, 16, 59)),
      DateTime.utc(2026, 9, 30),
    );
  });

  test('monthGrid is six Monday-first weeks around the month', () {
    final g = monthGrid(DateTime.utc(2026, 10));
    expect(g, hasLength(42));
    expect(g.first, DateTime.utc(2026, 9, 28)); // 1 Oct 2026 is a Thursday
    expect(g[3], DateTime.utc(2026, 10, 1));
    expect(g.last, DateTime.utc(2026, 11, 8));
    expect(g.every((d) => d.isUtc && d.hour == 0), isTrue);
    expect(
      monthGrid(DateTime.utc(2026, 6)).first,
      DateTime.utc(2026, 6, 1),
    ); // a Monday
  });

  test('daysBetween is inclusive and order-free', () {
    expect(daysBetween(DateTime.utc(2026, 10, 3), DateTime.utc(2026, 10, 1)), [
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 2),
      DateTime.utc(2026, 10, 3),
    ]);
    expect(
      daysBetween(DateTime.utc(2026, 10, 31), DateTime.utc(2026, 11, 1)),
      hasLength(2),
    );
    expect(daysBetween(DateTime.utc(2026, 10, 5), DateTime.utc(2026, 10, 5)), [
      DateTime.utc(2026, 10, 5),
    ]);
  });
}
