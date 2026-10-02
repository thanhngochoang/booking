import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/vn_time.dart';

void main() {
  test('toVn adds seven hours and stays a UTC-labelled value', () {
    final vn = toVn(DateTime.utc(2026, 10, 1, 5));
    expect((vn.hour, vn.day), (12, 1));
  });

  test('weekend is decided on the Vietnamese calendar day', () {
    expect(isVnWeekend(DateTime.utc(2026, 10, 3, 5)), isTrue); // Sat noon
    expect(
      isVnWeekend(DateTime.utc(2026, 10, 2, 17, 30)),
      isTrue,
    ); // Sat 00:30 VN
    expect(
      isVnWeekend(DateTime.utc(2026, 10, 4, 17, 30)),
      isFalse,
    ); // Mon 00:30 VN
    expect(isVnWeekend(DateTime.utc(2026, 10, 1, 5)), isFalse); // Thu
  });

  test('the week ends at Monday 00:00 in Vietnam', () {
    // Thursday 12:00 VN -> Monday 5 Oct 00:00 VN = Sunday 17:00 UTC.
    expect(
      endOfVnWeek(DateTime.utc(2026, 10, 1, 5)),
      DateTime.utc(2026, 10, 4, 17),
    );
    // Sunday 23:00 VN is still this week.
    expect(
      endOfVnWeek(DateTime.utc(2026, 10, 4, 16)),
      DateTime.utc(2026, 10, 4, 17),
    );
    // Monday 00:30 VN belongs to the next week.
    expect(
      endOfVnWeek(DateTime.utc(2026, 10, 4, 17, 30)),
      DateTime.utc(2026, 10, 11, 17),
    );
  });

  test('vnDateKey and parseDayKey', () {
    expect(vnDateKey(DateTime.utc(2026, 10, 4, 17)), '2026-10-05');
    expect(vnDateKey(DateTime.utc(2026, 10, 4, 16, 59)), '2026-10-04');
    expect(parseDayKey('2026-10-12'), DateTime.utc(2026, 10, 12));
    for (final bad in [
      '',
      '2026-13-01',
      '2026-02-30',
      '12/10/2026',
      '2026-1-1',
    ]) {
      expect(parseDayKey(bad), isNull, reason: bad);
    }
  });

  test('dayKeyOf reads the calendar fields without converting time zones', () {
    expect(dayKeyOf(DateTime.utc(2026, 10, 12)), '2026-10-12');
    expect(dayKeyOf(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(dayKeyOf(DateTime.utc(999, 3, 4)), '0999-03-04');
  });
}
