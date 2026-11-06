import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/rule_draft.dart';

final _today = DateTime.utc(2026, 11, 6);

RuleFormValues _values({
  int? price = 2000000,
  bool repeats = false,
  PriceRepeat cycle = PriceRepeat.yearly,
  bool lunar = false,
  DateTime? from,
  DateTime? to,
  Set<Weekday> weekdays = const {Weekday.sat},
  String? keepFrom,
  String? keepTo,
}) => RuleFormValues(
  serviceId: 'p1',
  price: price,
  name: ' Mùa cưới ',
  repeats: repeats,
  cycle: cycle,
  lunar: lunar,
  from: from ?? DateTime.utc(2026, 11, 14),
  to: to ?? DateTime.utc(2026, 11, 22),
  weekdays: weekdays,
  keepFrom: keepFrom,
  keepTo: keepTo,
);

RuleFormError? _error(
  RuleFormValues v, {
  bool creating = true,
  int ruleCount = 0,
  bool applyToAll = false,
  List<int> otherCounts = const [],
}) => ruleFormError(
  v,
  today: _today,
  creating: creating,
  serviceIds: const ['p1'],
  ruleCount: ruleCount,
  applyToAll: applyToAll,
  otherCounts: otherCounts,
);

void main() {
  group('lunar days of picked solar days', () {
    test('14/11/2026 is lunar 6/10, the key is MM-dd of the main month', () {
      final p = lunarPickOf(DateTime.utc(2026, 11, 14));
      expect((p.day, p.month, p.leap, p.key), (6, 10, false, '10-06'));
    });

    test('a day in the leap month 6 of 2025 maps to month 6 and says leap', () {
      final p = lunarPickOf(DateTime.utc(2025, 7, 25));
      expect((p.day, p.month, p.leap, p.key), (1, 6, true, '06-01'));
    });
  });

  group('occurrences of a yearly series', () {
    test('Tết 2027 is 30/1 to 10/2 (lunar 23/12 to 5/1)', () {
      final r = yearlyOccurrenceOf(
        from: '12-23',
        to: '01-05',
        lunar: true,
        year: 2026,
      );
      expect(r?.from, DateTime.utc(2027, 1, 30));
      expect(r?.to, DateTime.utc(2027, 2, 10));
    });

    test('a solar range crossing 31/12 is one range', () {
      final r = nextYearlyOccurrence(
        from: '12-24',
        to: '01-02',
        lunar: false,
        today: _today,
      );
      expect(r?.from, DateTime.utc(2026, 12, 24));
      expect(r?.to, DateTime.utc(2027, 1, 2));
    });

    test('a running occurrence is the next one until its last day', () {
      final r = nextYearlyOccurrence(
        from: '12-24',
        to: '01-02',
        lunar: false,
        today: DateTime.utc(2027, 1, 2),
      );
      expect(r?.from, DateTime.utc(2026, 12, 24));
      final after = nextYearlyOccurrence(
        from: '12-24',
        to: '01-02',
        lunar: false,
        today: DateTime.utc(2027, 1, 3),
      );
      expect(after?.from, DateTime.utc(2027, 12, 24));
    });

    test('the next lunar Tết from today is the one of 2027', () {
      final r = nextYearlyOccurrence(
        from: '12-23',
        to: '01-05',
        lunar: true,
        today: _today,
      );
      expect(r?.from, DateTime.utc(2027, 1, 30));
    });

    test('lunar day 30 of a 29-day month is its last day', () {
      // Lunar month 12 of 2026 has 29 days: 30/12 is the 29th.
      final r = yearlyOccurrenceOf(
        from: '12-30',
        to: '12-30',
        lunar: true,
        year: 2026,
      );
      final e = yearlyOccurrenceOf(
        from: '12-29',
        to: '12-29',
        lunar: true,
        year: 2026,
      );
      expect(r?.from, e?.from);
    });
  });

  test('weekdays of a range: only the days in it, all seven from a week', () {
    expect(
      weekdaysBetween(DateTime.utc(2026, 11, 14), DateTime.utc(2026, 11, 15)),
      {Weekday.sat, Weekday.sun},
    );
    expect(
      weekdaysBetween(DateTime.utc(2026, 11, 14), DateTime.utc(2026, 11, 14)),
      {Weekday.sat},
    );
    expect(
      weekdaysBetween(DateTime.utc(2026, 11, 14), DateTime.utc(2026, 11, 21)),
      Weekday.values.toSet(),
    );
  });

  group('the rule the form sends', () {
    test('switch off: a one-off range with its days', () {
      final input = _values().toInput()!;
      expect(input.toMap(), {
        'serviceId': 'p1',
        'price': 2000000,
        'repeat': 'none',
        'name': 'Mùa cưới',
        'from': '2026-11-14',
        'to': '2026-11-22',
      });
    });

    test('yearly on the solar calendar: MM-dd of the picked days', () {
      final input = _values(repeats: true).toInput()!;
      expect(
        (input.repeat, input.lunar, input.from, input.to),
        (PriceRepeat.yearly, false, '11-14', '11-22'),
      );
    });

    test('yearly lunar: the lunar day-month of the picked days', () {
      final input = _values(repeats: true, lunar: true).toInput()!;
      expect((input.lunar, input.from, input.to), (true, '10-06', '10-14'));
    });

    test('a day in a leap month is written as the main month', () {
      final input = _values(
        repeats: true,
        lunar: true,
        from: DateTime.utc(2025, 7, 25),
        to: DateTime.utc(2025, 7, 27),
      ).toInput()!;
      expect((input.from, input.to), ('06-01', '06-03'));
    });

    test('a yearly series that was not touched keeps its stored days', () {
      final input = _values(
        repeats: true,
        lunar: true,
        from: DateTime.utc(2027, 1, 30),
        to: DateTime.utc(2027, 2, 10),
        keepFrom: '12-23',
        keepTo: '01-05',
      ).toInput()!;
      expect((input.from, input.to), ('12-23', '01-05'));
    });

    test('weekly sends the weekdays and no days', () {
      final input = _values(
        repeats: true,
        cycle: PriceRepeat.weekly,
        weekdays: {Weekday.sat, Weekday.sun},
      ).toInput()!;
      expect(input.toMap(), {
        'serviceId': 'p1',
        'price': 2000000,
        'repeat': 'weekly',
        'name': 'Mùa cưới',
        'weekdays': ['sat', 'sun'],
      });
    });

    test('no price, no rule', () {
      expect(_values(price: null).toInput(), isNull);
    });
  });

  group('inline errors', () {
    test('a valid form has none', () {
      expect(_error(_values()), isNull);
      expect(_error(_values(repeats: true)), isNull);
      expect(_error(_values(repeats: true, lunar: true)), isNull);
    });

    test('price: empty, zero, above 1.000.000.000', () {
      expect(_error(_values(price: null)), RuleFormError.price);
      expect(_error(_values(price: 0)), RuleFormError.price);
      expect(_error(_values(price: 1000000001)), RuleFormError.priceHigh);
      expect(_error(_values(price: 1000000000)), isNull);
    });

    test('a one-off range that ended is refused when creating only', () {
      final past = _values(
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 10, 5),
      );
      expect(_error(past), RuleFormError.past);
      expect(_error(past, creating: false), isNull);
    });

    test('a one-off range of 93 days is too long, 92 is fine', () {
      final from = DateTime.utc(2026, 11, 14);
      expect(
        _error(_values(from: from, to: from.add(const Duration(days: 92)))),
        RuleFormError.tooLong,
      );
      expect(
        _error(_values(from: from, to: from.add(const Duration(days: 91)))),
        isNull,
      );
    });

    test('a one-off range starting beyond two years is too far', () {
      final from = DateTime.utc(2028, 11, 6);
      expect(_error(_values(from: from, to: from)), RuleFormError.tooFar);
      final ok = DateTime.utc(2028, 11, 5);
      expect(_error(_values(from: ok, to: ok)), isNull);
    });

    test('a yearly series is not "past" and is held to 92 days', () {
      expect(
        _error(
          _values(
            repeats: true,
            from: DateTime.utc(2026, 10, 1),
            to: DateTime.utc(2026, 10, 5),
          ),
        ),
        isNull,
      );
      expect(
        _error(
          _values(
            repeats: true,
            from: DateTime.utc(2026, 11, 1),
            to: DateTime.utc(2027, 2, 5),
          ),
        ),
        RuleFormError.tooLong,
      );
    });

    test('weekly needs a weekday', () {
      expect(
        _error(_values(repeats: true, cycle: PriceRepeat.weekly, weekdays: {})),
        RuleFormError.weekdays,
      );
    });

    test('29/2 does not repeat yearly on the solar calendar', () {
      final feb = DateTime.utc(2028, 2, 29);
      expect(
        _error(_values(repeats: true, from: feb, to: feb)),
        RuleFormError.leapDay,
      );
      expect(
        _error(
          _values(
            repeats: true,
            from: DateTime.utc(2028, 2, 28),
            to: DateTime.utc(2028, 3, 1),
          ),
        ),
        isNull,
      );
      // On the lunar calendar the same day is just another day.
      expect(
        _error(_values(repeats: true, lunar: true, from: feb, to: feb)),
        isNull,
      );
      // A one-off range may contain it.
      expect(_error(_values(from: feb, to: feb)), isNull);
    });

    test('30 series in the package, or in any package for "Mọi gói"', () {
      expect(_error(_values(), ruleCount: 30), RuleFormError.limit);
      expect(_error(_values(), ruleCount: 29), isNull);
      expect(_error(_values(), ruleCount: 30, creating: false), isNull);
      expect(
        _error(_values(), applyToAll: true, otherCounts: const [3, 30]),
        RuleFormError.limit,
      );
      expect(
        _error(_values(), otherCounts: const [3, 30]),
        isNull,
        reason: 'only "Mọi gói" copies into the others',
      );
    });
  });

  test('server errors map to the line that shows them', () {
    RuleFormError? of(PriceRuleErrorCode c, [String? f]) =>
        ruleFormErrorOfServer(PriceRuleError(c, f));
    expect(of(PriceRuleErrorCode.ruleLimit), RuleFormError.limit);
    expect(of(PriceRuleErrorCode.exceptionLimit), RuleFormError.exceptionLimit);
    expect(
      of(PriceRuleErrorCode.invalidArgument, 'price'),
      RuleFormError.price,
    );
    expect(
      of(PriceRuleErrorCode.invalidArgument, 'weekdays'),
      RuleFormError.weekdays,
    );
    expect(of(PriceRuleErrorCode.invalidArgument, 'to'), RuleFormError.tooLong);
    expect(of(PriceRuleErrorCode.invalidArgument, 'name'), isNull);
    expect(of(PriceRuleErrorCode.network), isNull);
    expect(of(PriceRuleErrorCode.unknown), isNull);
  });
}
