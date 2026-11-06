import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/pricing/special_days.dart';
import 'package:photobooking/features/packages/special_day_rules.dart';

final _today = DateTime.utc(2026, 10, 1);

SpecialDayError? _error({
  String name = 'Mùa cưới',
  DateTime? from,
  DateTime? to,
  int count = 0,
  bool isNew = true,
  DateTime? keepFrom,
}) => specialDayError(
  name: name,
  from: from ?? DateTime.utc(2026, 11, 14),
  to: to ?? DateTime.utc(2026, 11, 22),
  today: _today,
  existingCount: count,
  isNew: isNew,
  keepFrom: keepFrom,
);

void main() {
  group('specialDayError', () {
    test('accepts a normal range, a single day and exactly 60 days', () {
      expect(_error(), isNull);
      expect(_error(to: DateTime.utc(2026, 11, 14)), isNull);
      expect(
        _error(from: DateTime.utc(2026, 11, 1), to: DateTime.utc(2026, 12, 30)),
        isNull,
      );
    });

    test('a name of 1 or 41 characters is refused, 2 and 40 pass', () {
      expect(_error(name: 'a'), SpecialDayError.name);
      expect(_error(name: ' a '), SpecialDayError.name);
      expect(_error(name: 'ab'), isNull);
      expect(_error(name: 'a' * 40), isNull);
      expect(_error(name: 'a' * 41), SpecialDayError.name);
    });

    test('61 days is too long', () {
      expect(
        _error(from: DateTime.utc(2026, 11, 1), to: DateTime.utc(2026, 12, 31)),
        SpecialDayError.tooLong,
      );
    });

    test('the end may be 365 days ahead but not 366', () {
      final limit = _today.add(const Duration(days: 365));
      expect(_error(from: limit, to: limit), isNull);
      expect(
        _error(from: limit, to: limit.add(const Duration(days: 1))),
        SpecialDayError.tooFar,
      );
    });

    test('the 21st range is refused, editing one is not', () {
      expect(_error(count: 19), isNull);
      expect(_error(count: 20), SpecialDayError.limit);
      expect(_error(count: 20, isNew: false), isNull);
    });

    test('a start in the past is refused unless it is the kept one', () {
      final past = DateTime.utc(2026, 9, 28);
      final to = DateTime.utc(2026, 10, 3);
      expect(_error(from: past, to: to), SpecialDayError.past);
      expect(_error(from: past, to: to, isNew: false, keepFrom: past), isNull);
    });
  });

  group('holidayRuns', () {
    test('joins consecutive days of one name and keeps others apart', () {
      final runs = holidayRuns(const [
        Holiday(day: '2026-04-30', name: '30/4 – 1/5'),
        Holiday(day: '2026-02-17', name: 'Tết'),
        Holiday(day: '2026-02-16', name: 'Tết'),
        Holiday(day: '2026-05-01', name: '30/4 – 1/5'),
        Holiday(day: '2026-04-26', name: 'Giỗ Tổ'),
        Holiday(day: '2026-02-19', name: 'Tết'),
      ]);
      expect(runs.map((r) => (r.name, r.from.day, r.from.month, r.to.day)), [
        ('Tết', 16, 2, 17),
        ('Tết', 19, 2, 19),
        ('Giỗ Tổ', 26, 4, 26),
        ('30/4 – 1/5', 30, 4, 1),
      ]);
      expect(runs.last.to.month, 5);
    });
  });
}
