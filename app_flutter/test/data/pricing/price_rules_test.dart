import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/price_rules.dart';

/// Runs every section of the shared case table
/// (`test/data/contracts/day_pricing_cases.json`, a copy of the backend's
/// `packages/domain/test/fixtures/day_pricing_cases.json`) against the Dart
/// port, then the same extra checks the backend test makes.

typedef Json = Map<String, dynamic>;

final Json table = jsonDecode(
  File('test/data/contracts/day_pricing_cases.json').readAsStringSync(),
) as Json;

List<Json> section(String name) => (table[name] as List).cast<Json>();

DateTime day(String key) => parseDayKey(key)!;

String keyOf(DateTime d) => dayKeyOf(d);

PriceRule rule(Json j) {
  final r = PriceRule.tryParse(j['id'] as String, j);
  if (r == null) {
    throw StateError('table rule must parse: $j');
  }
  return r;
}

List<PriceRule> rulesOf(Object? j) => [
  for (final r in (j as List).cast<Json>()) rule(r),
];

PricedPackage package(Json j) => PricedPackage(
  id: j['id'] as String,
  price: j['price'] as int,
  active: j['active'] as bool? ?? true,
);

/// A rule as the table writes it: `id` next to the document fields.
Json asJson(PriceRule r) => {'id': r.id, ...r.toMap()};

Json? rangeJson(DayRange? r) =>
    r == null ? null : {'from': keyOf(r.from), 'to': keyOf(r.to)};

void main() {
  test('the table has every section, each case with a why', () {
    for (final name in table.keys) {
      final cases = section(name);
      expect(cases, isNotEmpty, reason: name);
      for (final c in cases) {
        expect(c['why'], isA<String>(), reason: '$name case without why');
      }
    }
    expect(table.keys.toSet(), {
      'lunar',
      'ranges',
      'priceForDay',
      'priceBounds',
      'startingPrice',
      'nextOccurrence',
      'split',
      'withException',
      'scaled',
      'scaledRules',
      'parse',
      'invalid',
    });
    expect(section('priceForDay').length, greaterThanOrEqualTo(60));
    expect(section('lunar').length, greaterThanOrEqualTo(20));
  });

  group('lunar', () {
    for (final c in section('lunar')) {
      test(c['why'] as String, () {
        final want = c['lunar'] as Json;
        final got = solarToLunar(day(c['solar'] as String));
        expect({
          'day': got.day,
          'month': got.month,
          'year': got.year,
          'leap': got.leap,
        }, want);
        final back = lunarToSolar(
          want['day'] as int,
          want['month'] as int,
          want['year'] as int,
          leap: want['leap'] as bool,
        );
        expect(back == null ? null : keyOf(back), c['solar']);
      });
    }
  });

  group('ruleRanges', () {
    for (final c in section('ranges')) {
      test(c['why'] as String, () {
        final got = ruleRanges(rule(c['rule'] as Json), c['year'] as int);
        expect([for (final r in got) rangeJson(r)], c['expected']);
      });
    }
  });

  group('priceForDay', () {
    for (final c in section('priceForDay')) {
      test(c['why'] as String, () {
        final s = c['service'] as Json;
        final got = priceForDay(
          s['price'] as int,
          s['id'] as String,
          rulesOf(c['rules']),
          day(c['day'] as String),
        );
        final want = c['expected'] as Json;
        expect(got.amount, want['amount']);
        expect(got.isRule, want['kind'] == 'rule');
        expect(got.rule?.id, want['ruleId']);
      });
    }
  });

  group('priceBounds', () {
    for (final c in section('priceBounds')) {
      test(c['why'] as String, () {
        final s = c['service'] as Json;
        final got = priceBounds(
          s['price'] as int,
          s['id'] as String,
          rulesOf(c['rules']),
          day(c['today'] as String),
        );
        expect({'min': got.min, 'max': got.max}, c['expected']);
      });
    }
  });

  group('startingPrice', () {
    for (final c in section('startingPrice')) {
      test(c['why'] as String, () {
        final got = startingPrice(
          [for (final s in (c['services'] as List).cast<Json>()) package(s)],
          rulesOf(c['rules']),
          day(c['today'] as String),
        );
        expect(got, c['expected']);
      });
    }
  });

  group('nextOccurrence', () {
    for (final c in section('nextOccurrence')) {
      test(c['why'] as String, () {
        final got = nextOccurrence(
          rule(c['rule'] as Json),
          day(c['today'] as String),
        );
        expect(rangeJson(got), c['expected']);
      });
    }
  });

  group('splitRule', () {
    for (final c in section('split')) {
      final original = rule(c['rule'] as Json);
      final at = day(c['day'] as String);
      final newPrice = c['newPrice'] as int?;
      test(c['why'] as String, () {
        final got = splitRule(original, at, newPrice, c['newId'] as String);
        final want = c['expected'] as Json;
        expect(asJson(got.before), want['before']);
        expect(got.after == null ? null : asJson(got.after!), want['after']);
      });
      test('${c['why']}: no day before ${c['day']} changes price', () {
        final got = splitRule(original, at, newPrice, c['newId'] as String);
        final rules = [got.before, ?got.after];
        for (var i = 1; i <= 800; i++) {
          final d = DateTime.utc(at.year, at.month, at.day - i);
          expect(
            priceForDay(1500000, original.serviceId, rules, d).amount,
            priceForDay(1500000, original.serviceId, [original], d).amount,
            reason: keyOf(d),
          );
        }
      });
    }
  });

  group('withException', () {
    for (final c in section('withException')) {
      test(c['why'] as String, () {
        final input = rule(c['rule'] as Json);
        final before = jsonEncode(asJson(input));
        final d = day(c['day'] as String);
        final value = c['value'];
        final got = value == 'clear'
            ? clearException(input, d)
            : withException(input, d, value as int?);
        expect(asJson(got), c['expected']);
        expect(
          jsonEncode(asJson(input)),
          before,
          reason: 'input is not mutated',
        );
      });
    }
  });

  group('scaledPrice', () {
    for (final c in section('scaled')) {
      test(c['why'] as String, () {
        expect(
          scaledPrice(
            c['input'] as int,
            c['fromPrice'] as int,
            c['toPrice'] as int,
          ),
          c['expected'],
        );
      });
    }
  });

  group('scaledRule', () {
    for (final c in section('scaledRules')) {
      test(c['why'] as String, () {
        final got = scaledRule(
          rule(c['rule'] as Json),
          package(c['from'] as Json),
          package(c['to'] as Json),
          c['newId'] as String,
        );
        expect(asJson(got), c['expected']);
      });
    }
  });

  group('PriceRule.tryParse', () {
    for (final c in section('parse')) {
      test(c['why'] as String, () {
        final got = PriceRule.tryParse(c['id'] as String, c['raw']);
        expect(got == null ? null : asJson(got), c['expected']);
      });
    }
  });

  group('validatePriceRuleField', () {
    for (final c in section('invalid')) {
      test(c['why'] as String, () {
        final ctx = c['ctx'] as Json;
        final got = validatePriceRuleField(
          c['rule'] as Json,
          today: day(ctx['today'] as String),
          serviceIds: (ctx['serviceIds'] as List).cast<String>(),
          creating: ctx['creating'] as bool,
        );
        expect(got, c['field']);
      });
    }
  });

  group('price rules', () {
    const s1 = PricedPackage(id: 's1', price: 1500000);
    const weekend = PriceRule(
      id: 'w',
      serviceId: 's1',
      price: 1800000,
      repeat: PriceRepeat.weekly,
      weekdays: {Weekday.sat, Weekday.sun},
    );
    const tet = PriceRule(
      id: 'tet',
      serviceId: 's1',
      price: 3000000,
      repeat: PriceRepeat.yearly,
      lunar: true,
      from: '12-23',
      to: '01-05',
    );

    DateTime addDays(String from, int n) {
      final d = day(from);
      return DateTime.utc(d.year, d.month, d.day + n);
    }

    test('constants', () {
      expect(kMaxRulesPerService, 30);
      expect(kMaxExceptions, 50);
      expect(kMaxSpanDays, 92);
      expect(kMaxAheadDays, 730);
    });

    test('templates: 11 entries in the spec order, all valid yearly rules', () {
      expect(
        [
          for (final t in priceRuleTemplates)
            (t.code, t.lunar, t.from, t.to, t.group.name),
        ],
        [
          ('tet', true, '12-23', '01-05', 'holiday'),
          ('hung_kings', true, '03-10', '03-10', 'holiday'),
          ('new_year', false, '01-01', '01-01', 'holiday'),
          ('reunification', false, '04-30', '05-01', 'holiday'),
          ('national_day', false, '09-02', '09-02', 'holiday'),
          ('valentine', false, '02-14', '02-14', 'occasion'),
          ('womens_day', false, '03-08', '03-08', 'occasion'),
          ('mid_autumn', true, '08-15', '08-15', 'occasion'),
          ('vn_womens_day', false, '10-20', '10-20', 'occasion'),
          ('christmas', false, '12-24', '12-25', 'occasion'),
          ('wedding_season', false, '10-15', '12-31', 'occasion'),
        ],
      );
      for (final t in priceRuleTemplates) {
        expect(t.name, isNotEmpty);
        expect(t.name.length, lessThanOrEqualTo(40));
        final r = PriceRule(
          id: t.code,
          serviceId: 's1',
          price: 1000000,
          repeat: PriceRepeat.yearly,
          lunar: t.lunar,
          from: t.from,
          to: t.to,
          template: t.code,
        );
        expect(
          validatePriceRuleField(
            r.toMap(),
            today: day('2026-11-06'),
            serviceIds: const ['s1'],
            creating: true,
          ),
          isNull,
          reason: t.code,
        );
      }
    });

    test('a precomputed lunar date gives the same answer as none', () {
      for (var i = 0; i < 400; i++) {
        final d = addDays('2026-01-01', i);
        for (final r in [tet, weekend]) {
          final a = ruleCoversDay(r, d, lunar: solarToLunar(d));
          final b = ruleCoversDay(r, d);
          expect(
            (a.covers, a.price),
            (b.covers, b.price),
            reason: '${r.id} ${keyOf(d)}',
          );
        }
      }
    });

    test('ruleCoversDay reports the price of an exception', () {
      const r = PriceRule(
        id: 'w',
        serviceId: 's1',
        price: 1800000,
        repeat: PriceRepeat.weekly,
        weekdays: {Weekday.sat, Weekday.sun},
        exceptions: {
          '2026-11-14': 2100000,
          '2026-11-15': null,
          '2026-11-09': 'x',
        },
      );
      expect(ruleCoversDay(r, day('2026-11-14')), (
        covers: true,
        price: 2100000,
      ));
      expect(ruleCoversDay(r, day('2026-11-15')), (covers: false, price: null));
      expect(ruleCoversDay(r, day('2026-11-21')), (
        covers: true,
        price: 1800000,
      ));
      expect(ruleCoversDay(r, day('2026-11-09')), (covers: false, price: null));
    });

    test(
      'weekday comes from the Gregorian date, not the time zone or time of day',
      () {
        expect(
          priceForDay(1500000, 's1', [
            weekend,
          ], DateTime(2026, 11, 14, 23, 59)).isRule,
          isTrue,
        );
        expect(
          priceForDay(1500000, 's1', [
            weekend,
          ], DateTime(2026, 11, 13, 23, 59)).isRule,
          isFalse,
        );
        expect(
          priceForDay(1500000, 's1', [
            weekend,
          ], DateTime.utc(2026, 11, 14)).isRule,
          isTrue,
        );
      },
    );

    test(
      'monthPrices has one entry per day and the same answer as priceForDay',
      () {
        const other = PriceRule(
          id: 'x',
          serviceId: 's1',
          price: 1,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.mon},
        );
        final rules = [weekend, tet, other];
        final feb = monthPrices(s1.price, s1.id, rules, 2026, 2);
        expect(feb, hasLength(28));
        expect(monthPrices(s1.price, s1.id, rules, 2028, 2), hasLength(29));
        feb.forEach((d, got) {
          final want = priceForDay(s1.price, s1.id, rules, d);
          expect(
            (got.amount, got.isRule, got.rule?.id),
            (want.amount, want.isRule, want.rule?.id),
          );
        });
        expect(feb[day('2026-02-17')]?.amount, 3000000);
        expect(feb[day('2026-02-14')]?.isRule, isTrue);
        expect(feb.keys.take(2).map(keyOf), ['2026-02-01', '2026-02-02']);
        final dec = monthPrices(s1.price, s1.id, const [], 2026, 12);
        expect(dec, hasLength(31));
        expect(dec[day('2026-12-31')]?.amount, 1500000);
        expect(dec[day('2026-12-31')]?.isRule, isFalse);
      },
    );

    test('a rule listed twice with an equal price keeps the first', () {
      final copy = PriceRule.tryParse('copy', weekend.toMap())!;
      final got = priceForDay(1500000, 's1', [
        weekend,
        copy,
      ], day('2026-11-14'));
      expect(got.rule?.id, 'w');
    });

    test('priceForDay never throws for a rule without weekdays', () {
      const odd = PriceRule(
        id: 'o',
        serviceId: 's1',
        price: 1,
        repeat: PriceRepeat.weekly,
      );
      final got = priceForDay(1500000, 's1', [odd], day('2026-11-14'));
      expect(got.isRule, isFalse);
    });

    test('a rule of another package never applies', () {
      final got = priceForDay(1500000, 's2', [weekend], day('2026-11-14'));
      expect(got.isRule, isFalse);
      expect(got.amount, 1500000);
    });

    test('scaledPrice refuses a package price of 0 and caps at 1e9', () {
      expect(() => scaledPrice(1000000, 0, 1000000), throwsArgumentError);
      expect(scaledPrice(1000000000, 1, 1000000000), 1000000000);
    });

    test('priceBounds and startingPrice agree for one active package', () {
      final cheap = PriceRule.tryParse('c', {
        ...weekend.toMap(),
        'price': 1100000,
      })!;
      final rules = [cheap, tet];
      final bounds = priceBounds(s1.price, s1.id, rules, day('2026-11-06'));
      expect(startingPrice(const [s1], rules, day('2026-11-06')), bounds.min);
      expect(bounds.min, 1100000);
      expect(bounds.max, 3000000);
    });

    test(
      'startingPrice skips inactive packages and is null with none active',
      () {
        const off = PricedPackage(id: 's2', price: 100, active: false);
        expect(
          startingPrice(const [s1, off], const [], day('2026-11-06')),
          1500000,
        );
        expect(startingPrice(const [off], const [], day('2026-11-06')), isNull);
        expect(startingPrice(const [], const [], day('2026-11-06')), isNull);
      },
    );

    test('30 lunar rules over ten years stay quick', () {
      final rules = [
        for (var i = 0; i < 30; i++)
          PriceRule.tryParse('t$i', {...tet.toMap(), 'price': 1000000 + i})!,
      ];
      final watch = Stopwatch()..start();
      var n = 0;
      for (var i = 0; i < 3650; i++) {
        if (priceForDay(
          1500000,
          's1',
          rules,
          addDays('2026-01-01', i),
        ).isRule) {
          n++;
        }
      }
      expect(
        n,
        allOf(greaterThan(100), lessThan(200)),
        reason: 'covered days $n',
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });
}
