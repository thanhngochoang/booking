import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/day_pricing_world.dart';

final _l = AppLocalizationsVi();
final _today = DateTime.utc(2026, 11, 6);

PriceRule _once(
  String id, {
  String from = '2026-11-14',
  String to = '2026-11-15',
  int price = 2000000,
  String? name,
}) => PriceRule(
  id: id,
  serviceId: 'p1',
  price: price,
  repeat: PriceRepeat.none,
  name: name,
  from: from,
  to: to,
);

void main() {
  group('short days', () {
    test('weekday, day and month without leading zeros', () {
      expect(weekdayDayText(DateTime.utc(2026, 11, 14)), 'T7 14/11');
      expect(weekdayDayText(DateTime.utc(2026, 3, 4)), 'T4 4/3');
      expect(
        weekdayDayText(DateTime.utc(2026, 11, 15), year: true),
        'CN 15/11/2026',
      );
      expect(dayMonthText(DateTime.utc(2026, 2, 3)), '3/2');
    });

    test('a range closes with the year, and opens with it across years', () {
      expect(
        dayRangeText(DateTime.utc(2027, 1, 30), DateTime.utc(2027, 2, 10)),
        'T7 30/1 – T4 10/2/2027',
      );
      expect(
        dayRangeText(DateTime.utc(2026, 12, 24), DateTime.utc(2027, 1, 2)),
        'T5 24/12/2026 – T7 2/1/2027',
      );
      expect(
        dayRangeText(DateTime.utc(2027, 2, 3), DateTime.utc(2027, 2, 3)),
        'T4 3/2/2027',
      );
    });
  });

  group('rule rows', () {
    test('title falls back to "Giá riêng"', () {
      expect(ruleTitle(_l, weekendRule()), 'Cuối tuần');
      expect(ruleTitle(_l, _once('a')), 'Giá riêng');
      expect(ruleTitle(_l, _once('a', name: '  ')), 'Giá riêng');
    });

    test('weekly lists the days in week order', () {
      expect(rulePattern(_l, weekendRule()), 'Hằng tuần · T7, CN');
      const shuffled = PriceRule(
        id: 'w',
        serviceId: 'p1',
        price: 1,
        repeat: PriceRepeat.weekly,
        weekdays: {Weekday.sun, Weekday.mon, Weekday.fri},
      );
      expect(rulePattern(_l, shuffled), 'Hằng tuần · T2, T6, CN');
    });

    test('yearly solar, one day, and lunar with Chạp and Giêng', () {
      expect(rulePattern(_l, weddingRule()), 'Hằng năm · 14/11 – 22/11');
      expect(
        rulePattern(
          _l,
          const PriceRule(
            id: 'n',
            serviceId: 'p1',
            price: 1,
            repeat: PriceRepeat.yearly,
            from: '02-14',
            to: '02-14',
          ),
        ),
        'Hằng năm · 14/2',
      );
      expect(
        rulePattern(_l, tetRule()),
        'Hằng năm · 23 Chạp – 5 Giêng (âm lịch)',
      );
      expect(
        rulePattern(
          _l,
          const PriceRule(
            id: 'g',
            serviceId: 'p1',
            price: 1,
            repeat: PriceRepeat.yearly,
            lunar: true,
            from: '03-10',
            to: '03-10',
          ),
        ),
        'Hằng năm · 10/3 (âm lịch)',
      );
    });

    test('one-off range, with the year closing it', () {
      expect(rulePattern(_l, _once('a')), 'Một lần · T7 14/11 – CN 15/11/2026');
      expect(
        rulePattern(_l, _once('a', from: '2026-11-14', to: '2026-11-14')),
        'Một lần · T7 14/11/2026',
      );
    });

    test('exceptions: a count, spelled out for one or two in the list', () {
      final one = weddingRule(exceptions: {'2026-11-15': 1500000});
      expect(ruleSummary(_l, one), 'Hằng năm · 14/11 – 22/11 · 1 ngoại lệ');
      expect(
        ruleSummary(_l, one, detail: true),
        'Hằng năm · 14/11 – 22/11 · 1 ngoại lệ (CN 15/11: 1,5M)',
      );
      final two = weddingRule(
        exceptions: {'2026-11-15': 1500000, '2026-11-16': null},
      );
      expect(
        ruleSummary(_l, two, detail: true),
        'Hằng năm · 14/11 – 22/11 · 2 ngoại lệ (CN 15/11: 1,5M; T2 16/11: bỏ)',
      );
      final three = weddingRule(
        exceptions: {
          '2026-11-15': 1500000,
          '2026-11-16': null,
          '2026-11-17': 1600000,
        },
      );
      expect(
        ruleSummary(_l, three, detail: true),
        'Hằng năm · 14/11 – 22/11 · 3 ngoại lệ',
      );
    });

    test('invalid exception values do not count', () {
      final rule = weddingRule(
        exceptions: {
          '2026-11-15': 'abc',
          '2026-11-16': 0,
          '2026-11-17': 2000000000,
          'nope': 5,
          '2026-11-18': 1700000,
        },
      );
      expect(ruleExceptions(rule).map((e) => e.day.day), [18]);
    });

    test('a lunar series says when it comes next, in the list', () {
      expect(
        ruleSummary(_l, tetRule(), today: _today, withNext: true),
        'Hằng năm · 23 Chạp – 5 Giêng (âm lịch) · lần tới T7 30/1 – T4 10/2/2027',
      );
      expect(
        ruleSummary(_l, weddingRule(), today: _today, withNext: true),
        'Hằng năm · 14/11 – 22/11',
      );
    });
  });

  group('listedRules', () {
    test('weekly first, then soonest next occurrence', () {
      final list = listedRules([
        tetRule(),
        _once('soon', from: '2026-11-10', to: '2026-11-11'),
        weekendRule(),
        weddingRule(),
      ], _today);
      expect(list.map((r) => r.id), [
        'r-weekend',
        'soon',
        'r-wedding',
        'r-tet',
      ]);
    });

    test('a one-off that ended and a series past its until are hidden', () {
      final list = listedRules([
        _once('ended', from: '2026-10-01', to: '2026-10-05'),
        _once('running', from: '2026-11-05', to: '2026-11-08'),
        const PriceRule(
          id: 'over',
          serviceId: 'p1',
          price: 1,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.sat},
          until: '2026-10-31',
        ),
      ], _today);
      expect(list.map((r) => r.id), ['running']);
    });
  });

  group('endedRules', () {
    test('the series listedRules leaves out, the last to end first', () {
      final rules = [
        _once('ended-a', from: '2026-09-01', to: '2026-09-03'),
        _once('ended-b', from: '2026-10-01', to: '2026-10-05'),
        _once('running', from: '2026-11-05', to: '2026-11-08'),
        weekendRule(),
        const PriceRule(
          id: 'over',
          serviceId: 'p1',
          price: 1,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.sat},
          until: '2026-10-31',
        ),
      ];
      expect(endedRules(rules, _today).map((r) => r.id), [
        'over',
        'ended-b',
        'ended-a',
      ]);
      expect(listedRules(rules, _today).map((r) => r.id), [
        'r-weekend',
        'running',
      ]);
    });
  });
}
