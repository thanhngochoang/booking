import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';

PricedService _service(Map<String, dynamic> j) {
  final d = j['dayPrices'] as Map<String, dynamic>?;
  return PricedService(
    price: j['price'] as int,
    dayPrices: d == null
        ? null
        : {for (final w in Weekday.values) w: d[w.name] as int},
    specialPrice: j['specialPrice'] as int?,
  );
}

SpecialDays _special(Map<String, dynamic> j) => SpecialDays(
  holidays: (j['holidays'] as List).cast<String>(),
  ranges: [
    for (final r in j['ranges'] as List)
      (from: (r as Map)['from'] as String, to: r['to'] as String),
  ],
);

PricedService _two(int weekday, int weekend) => PricedService(
  price: weekday,
  dayPrices: {
    for (final w in Weekday.values) w: w.isWeekend ? weekend : weekday,
  },
);

void main() {
  group('shared case table', () {
    final cases = jsonDecode(
      File('test/data/contracts/day_pricing_cases.json').readAsStringSync(),
    ) as List;

    test('is not empty', () => expect(cases, isNotEmpty));

    for (final c in cases.cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final r = priceForDayKey(
          _service(c['service'] as Map<String, dynamic>),
          c['day'] as String,
          _special(c['special'] as Map<String, dynamic>),
        );
        expect(r.amount, c['amount']);
        expect(r.kind.name, c['kind']);
      });
    }
  });

  group('weekdayOf', () {
    test('uses the calendar date, not the time zone or time of day', () {
      // 2026-11-14 is a Saturday.
      expect(weekdayOf(DateTime(2026, 11, 14, 23, 59)), Weekday.sat);
      expect(weekdayOf(DateTime.utc(2026, 11, 14)), Weekday.sat);
      expect(weekdayOf(DateTime(2026, 11, 15, 0, 1)), Weekday.sun);
      expect(weekdayOf(DateTime(2026, 11, 16)), Weekday.mon);
    });

    test('reads yyyy-MM-dd keys and rejects bad ones', () {
      expect(weekdayOfKey('2028-02-29'), Weekday.tue);
      expect(weekdayOfKey('2027-02-29'), isNull);
      expect(weekdayOfKey('nope'), isNull);
    });
  });

  group('priceSummary', () {
    test('single when all 7 equal', () {
      final s = priceSummary(const PricedService(price: 1000000));
      expect(s, isA<SinglePrice>());
      expect((s.min, s.max, s.special), (1000000, 1000000, null));
    });

    test('two levels when mon-fri equal and sat = sun', () {
      final s = priceSummary(_two(1500000, 1800000));
      expect(s, isA<TwoLevelPrice>());
      final t = s as TwoLevelPrice;
      expect(
        (t.weekday, t.weekend, t.min, t.max),
        (1500000, 1800000, 1500000, 1800000),
      );
    });

    test('a cheaper weekend is still two levels', () {
      final s = priceSummary(_two(2000000, 1500000));
      expect(s, isA<TwoLevelPrice>());
      expect((s.min, s.max), (1500000, 2000000));
    });

    test('per day when sat and sun differ or a weekday differs', () {
      final p = {for (final w in Weekday.values) w: 1000000};
      expect(
        priceSummary(
          PricedService(
            price: 1000000,
            dayPrices: {...p, Weekday.sun: 1200000},
          ),
        ),
        isA<PerDayPrice>(),
      );
      expect(
        priceSummary(
          PricedService(price: 1000000, dayPrices: {...p, Weekday.wed: 900000}),
        ),
        isA<PerDayPrice>(),
      );
    });

    test('the range and the summary never include specialPrice', () {
      const s = PricedService(price: 1000000, specialPrice: 3000000);
      expect(priceRange(s), (min: 1000000, max: 1000000));
      final sum = priceSummary(s);
      expect(sum, isA<SinglePrice>());
      expect((sum.max, sum.special), (1000000, 3000000));
    });

    test('equal day prices read as a single price, not min-max', () {
      final s = PricedService(
        price: 1500000,
        dayPrices: {for (final w in Weekday.values) w: 1500000},
      );
      expect(priceSummary(s), isA<SinglePrice>());
    });
  });

  group('normalizeDayPrices', () {
    test('drops dayPrices when all 7 equal and takes Monday as price', () {
      final n = normalizeDayPrices({
        for (final w in Weekday.values) w: 1500000,
      });
      expect(n.price, 1500000);
      expect(n.dayPrices, isNull);
    });

    test('keeps dayPrices otherwise', () {
      final p = _two(1500000, 1800000).dayPrices!;
      final n = normalizeDayPrices(p);
      expect(n.price, 1500000);
      expect(n.dayPrices, p);
    });
  });

  test('dayPricesFromMap needs exactly the 7 whole-VND keys', () {
    final ok = {for (final w in Weekday.values) w.name: 1000};
    expect(dayPricesFromMap(ok), isNotNull);
    expect(dayPricesFromMap({...ok}..remove('sun')), isNull);
    expect(dayPricesFromMap({...ok, 'sun': 0}), isNull);
    expect(dayPricesFromMap({...ok, 'sun': 1.5}), isNull);
    expect(dayPricesFromMap(null), isNull);
  });
}
