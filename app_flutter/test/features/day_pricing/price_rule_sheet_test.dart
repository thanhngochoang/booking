import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart' show AppButton, AppChip;
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/rule_draft.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';

import '../../support/day_pricing_world.dart';

DateTime _nov(int day) => DateTime.utc(2026, 11, day);

bool _canSave(WidgetTester tester) =>
    tester.widget<AppButton>(keyed('price-rule-save')).onPressed != null;

bool _switchOn(WidgetTester tester, String key) => tester
    .widget<Switch>(
      find.descendant(of: keyed(key), matching: find.byType(Switch)),
    )
    .value;

/// Whether the round toggle of [weekday] is filled.
bool _weekdayOn(WidgetTester tester, String weekday, BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: keyed('price-rule-weekday-$weekday'),
          matching: find.byType(DecoratedBox),
        ),
      )
      .any((b) {
        final d = b.decoration;
        return d is BoxDecoration && d.color == primary;
      });
}

Future<void> _chooseMenu(WidgetTester tester, String key, String item) async {
  await tester.tap(keyed(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Map<String, Object?> _sent(DayPricingWorld w, [int i = 0]) =>
    w.rules.saves[i].input.toMap();

void main() {
  late DayPricingWorld world;

  setUp(() => world = DayPricingWorld());

  group('create a one-off range', () {
    testWidgets('price, name and the tapped day; Lưu closes and says so', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);

      await tapDay(tester, _nov(10));
      expect(find.text('Giá · Chân dung'), findsOneWidget);
      expect(keyed('price-rule-repeat-section'), findsNothing);
      expect(keyed('price-rule-delete'), findsNothing);
      expect(_canSave(tester), isFalse, reason: 'no price yet');

      await typePrice(tester, 'price-rule-price', '2000000');
      await tester.enterText(keyed('price-rule-name'), 'Kỷ yếu');
      await tester.pump();
      expect(find.text('2.000.000'), findsOneWidget);
      await tapKey(tester, 'price-rule-save');

      expect(_sent(world), {
        'serviceId': 'p1',
        'price': 2000000,
        'repeat': 'none',
        'name': 'Kỷ yếu',
        'from': '2026-11-10',
        'to': '2026-11-10',
      });
      expect(world.rules.saves.single.ruleId, isNull);
      expect(world.rules.saves.single.applyToAll, isFalse);
      expect(keyed('price-rule-save'), findsNothing);
      expect(find.text('Đã lưu giá'), findsOneWidget);
      expect(_texts(tester, priceLine(_nov(10))), '2M');
      expect(world.events.single.name, 'price_rule_save');
      expect(world.events.single.params, {
        'repeat': 'none',
        'lunar': false,
        'scope': 'new',
        'applyAll': false,
      });
    });

    testWidgets('price errors under the field', (tester) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(10));

      await typePrice(tester, 'price-rule-price', '0');
      expect(find.text('Giá phải lớn hơn 0'), findsOneWidget);
      expect(_canSave(tester), isFalse);
      await typePrice(tester, 'price-rule-price', '2000000000');
      expect(find.text('Giá tối đa 1.000.000.000₫'), findsOneWidget);
      expect(_canSave(tester), isFalse);
      await typePrice(tester, 'price-rule-price', '1000000000');
      expect(find.textContaining('Giá '), findsWidgets);
      expect(find.text('Giá tối đa 1.000.000.000₫'), findsNothing);
      expect(_canSave(tester), isTrue);
    });

    testWidgets('Từ and Tới open the date picker; Từ pushes Tới along', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(10));

      await tester.tap(keyed('price-rule-to'));
      await tester.pumpAndSettle();
      await tester.tap(dayCell(_nov(12)).last);
      await tester.pump();
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      expect(find.text('T3 10/11/2026'), findsOneWidget);
      expect(find.text('T5 12/11/2026'), findsOneWidget);

      await tester.tap(keyed('price-rule-from'));
      await tester.pumpAndSettle();
      await tester.tap(dayCell(_nov(20)).last);
      await tester.pump();
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      expect(find.text('T6 20/11/2026'), findsNWidgets(2));
    });

    testWidgets('a day in the past: "Chỉ chọn từ hôm nay trở đi"', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(2));

      await typePrice(tester, 'price-rule-price', '2000000');
      expect(find.text('Chỉ chọn từ hôm nay trở đi'), findsOneWidget);
      expect(_canSave(tester), isFalse);
    });

    testWidgets('a range of 93 days: "Khoảng tối đa 92 ngày"', (tester) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(10));
      await typePrice(tester, 'price-rule-price', '2000000');

      // Tới on 12 Feb 2027 (95 days) through the picker: three months on.
      await tester.tap(keyed('price-rule-to'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Tháng sau').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(dayCell(DateTime.utc(2027, 2, 12)).last);
      await tester.pump();
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      expect(find.text('Khoảng tối đa 92 ngày'), findsOneWidget);
      expect(_canSave(tester), isFalse);
    });
  });

  group('Lặp lại', () {
    testWidgets('on: Chu kỳ is Hằng năm, Theo âm lịch is off', (tester) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(10));

      await tapKey(tester, 'price-rule-repeat');
      expect(keyed('price-rule-repeat-section'), findsOneWidget);
      expect(find.text('Chu kỳ'), findsOneWidget);
      expect(find.text('Hằng năm'), findsOneWidget);
      expect(find.text('Theo âm lịch'), findsOneWidget);
      expect(_switchOn(tester, 'price-rule-lunar'), isFalse);
      expect(_texts(tester, keyed('price-rule-helper')), '10/11 mỗi năm');
      expect(keyed('price-rule-weekdays'), findsNothing);

      // Off again: the section folds away.
      await tapKey(tester, 'price-rule-repeat');
      expect(keyed('price-rule-repeat-section'), findsNothing);
    });

    testWidgets('yearly on the solar calendar writes MM-dd', (tester) async {
      await world.init();
      await world.open(tester);
      await dragRange(tester, _nov(14), _nov(22));
      await tapKey(tester, 'day-pricing-add');

      await tapKey(tester, 'price-rule-repeat');
      expect(
        _texts(tester, keyed('price-rule-helper')),
        '14/11 – 22/11 mỗi năm',
      );
      await typePrice(tester, 'price-rule-price', '2000000');
      await tapKey(tester, 'price-rule-save');

      expect(_sent(world), {
        'serviceId': 'p1',
        'price': 2000000,
        'repeat': 'yearly',
        'from': '11-14',
        'to': '11-22',
      });
    });

    testWidgets('yearly on the lunar calendar writes the lunar MM-dd', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await dragRange(tester, _nov(14), _nov(22));
      await tapKey(tester, 'day-pricing-add');
      await tapKey(tester, 'price-rule-repeat');
      await tapKey(tester, 'price-rule-lunar');

      expect(_switchOn(tester, 'price-rule-lunar'), isTrue);
      // 14/11/2026 is lunar 6/10, 22/11 is 14/10; next year 3/11 - 11/11/2027.
      final next = yearlyOccurrenceOf(
        from: '10-06',
        to: '10-14',
        lunar: true,
        year: 2027,
      )!;
      expect(
        _texts(tester, keyed('price-rule-helper')),
        '6/10 – 14/10 âm lịch mỗi năm · năm sau là '
        '${dayRangeText(next.from, next.to)}',
      );
      expect(dayRangeText(next.from, next.to), 'T4 3/11 – T5 11/11/2027');
      await typePrice(tester, 'price-rule-price', '2000000');
      await tapKey(tester, 'price-rule-save');

      expect(_sent(world), {
        'serviceId': 'p1',
        'price': 2000000,
        'repeat': 'yearly',
        'lunar': true,
        'from': '10-06',
        'to': '10-14',
      });
      expect(world.events.single.params['lunar'], isTrue);
    });

    testWidgets('a day in the leap month: main month and the note (R14)', (
      tester,
    ) async {
      await world.init(today: DateTime.utc(2025, 7, 20));
      await world.open(tester);
      await tapDay(tester, DateTime.utc(2025, 7, 25));
      await tapKey(tester, 'price-rule-repeat');
      expect(keyed('price-rule-leap-note'), findsNothing);
      await tapKey(tester, 'price-rule-lunar');

      expect(
        _texts(tester, keyed('price-rule-leap-note')),
        'Tháng 6 năm nay nhuận, chuỗi lặp theo tháng 6 chính',
      );
      await typePrice(tester, 'price-rule-price', '2000000');
      await tapKey(tester, 'price-rule-save');
      expect((_sent(world)['from'], _sent(world)['to']), ('06-01', '06-01'));
    });

    testWidgets('29/2 does not repeat yearly on the solar calendar', (
      tester,
    ) async {
      await world.init(today: DateTime.utc(2028, 2, 20));
      await world.open(tester);
      await tapDay(tester, DateTime.utc(2028, 2, 29));
      await typePrice(tester, 'price-rule-price', '2000000');
      expect(_canSave(tester), isTrue);

      await tapKey(tester, 'price-rule-repeat');
      expect(find.text('Ngày 29/2 không lặp hằng năm được'), findsOneWidget);
      expect(_canSave(tester), isFalse);

      await tapKey(tester, 'price-rule-lunar');
      expect(find.text('Ngày 29/2 không lặp hằng năm được'), findsNothing);
      expect(_canSave(tester), isTrue);
    });

    testWidgets('Hằng tuần: seven round toggles filled from the range', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await dragRange(tester, _nov(14), _nov(15));
      await tapKey(tester, 'day-pricing-add');
      await tapKey(tester, 'price-rule-repeat');
      await _chooseMenu(tester, 'price-rule-cycle', 'Hằng tuần');

      // The days are gone, the toggles are there; no lunar switch.
      expect(keyed('price-rule-from'), findsNothing);
      expect(keyed('price-rule-to'), findsNothing);
      expect(keyed('price-rule-lunar'), findsNothing);
      expect(keyed('price-rule-weekdays'), findsOneWidget);
      for (final t in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
        expect(
          find.descendant(
            of: keyed('price-rule-weekdays'),
            matching: find.text(t),
          ),
          findsOneWidget,
        );
      }
      final context = tester.element(keyed('price-rule-weekdays'));
      expect(_weekdayOn(tester, 'sat', context), isTrue);
      expect(_weekdayOn(tester, 'sun', context), isTrue);
      expect(_weekdayOn(tester, 'mon', context), isFalse);

      await typePrice(tester, 'price-rule-price', '1800000');
      await tapKey(tester, 'price-rule-save');
      expect(_sent(world), {
        'serviceId': 'p1',
        'price': 1800000,
        'repeat': 'weekly',
        'weekdays': ['sat', 'sun'],
      });
    });

    testWidgets('Hằng tuần needs a weekday', (tester) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(14));
      await tapKey(tester, 'price-rule-repeat');
      await _chooseMenu(tester, 'price-rule-cycle', 'Hằng tuần');
      await typePrice(tester, 'price-rule-price', '1800000');
      expect(_canSave(tester), isTrue);

      await tapKey(tester, 'price-rule-weekday-sat');
      expect(find.text('Chọn ít nhất một thứ'), findsOneWidget);
      expect(_canSave(tester), isFalse);
      await tapKey(tester, 'price-rule-weekday-mon');
      expect(find.text('Chọn ít nhất một thứ'), findsNothing);
      expect(_canSave(tester), isTrue);
    });

    testWidgets('what was picked stays while the switch is off and on', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(14));
      await tapKey(tester, 'price-rule-repeat');
      await _chooseMenu(tester, 'price-rule-cycle', 'Hằng tuần');
      await tapKey(tester, 'price-rule-weekday-sun');
      await tapKey(tester, 'price-rule-repeat');
      await tapKey(tester, 'price-rule-repeat');

      expect(find.text('Hằng tuần'), findsWidgets);
      final context = tester.element(keyed('price-rule-weekdays'));
      expect(_weekdayOn(tester, 'sat', context), isTrue);
      expect(_weekdayOn(tester, 'sun', context), isTrue);
    });
  });

  group('templates', () {
    testWidgets('chips only from "Đặt giá" with nothing selected', (
      tester,
    ) async {
      await world.init();
      world.seed(tetRule());
      await world.open(tester);
      await tapKey(tester, 'day-pricing-add');

      expect(keyed('price-rule-templates'), findsOneWidget);
      expect(find.text('Giỗ Tổ Hùng Vương'), findsOneWidget);
      expect(
        tester.widget<AppChip>(keyed('price-rule-template-tet')).enabled,
        isFalse,
        reason: 'Tết is already a series of this package',
      );
      expect(
        tester.widget<AppChip>(keyed('price-rule-template-hung_kings')).enabled,
        isTrue,
      );
    });

    testWidgets('a lunar template fills name, days, repeat and lunar', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapKey(tester, 'day-pricing-add');
      await tapKey(tester, 'price-rule-template-tet');

      expect(
        tester.widget<TextField>(keyed('price-rule-name')).controller?.text,
        'Tết Nguyên đán',
      );
      expect(_switchOn(tester, 'price-rule-repeat'), isTrue);
      expect(_switchOn(tester, 'price-rule-lunar'), isTrue);
      // The next Tết from 6/11/2026 is 30/1 - 10/2/2027.
      expect(find.text('T7 30/1/2027'), findsOneWidget);
      expect(find.text('T4 10/2/2027'), findsOneWidget);
      await typePrice(tester, 'price-rule-price', '2500000');
      await tapKey(tester, 'price-rule-save');

      expect(_sent(world), {
        'serviceId': 'p1',
        'price': 2500000,
        'repeat': 'yearly',
        'name': 'Tết Nguyên đán',
        'lunar': true,
        'from': '12-23',
        'to': '01-05',
        'template': 'tet',
      });
    });

    testWidgets('a solar template, then another day changes the dates', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapKey(tester, 'day-pricing-add');
      await tapKey(tester, 'price-rule-template-christmas');
      expect(_switchOn(tester, 'price-rule-lunar'), isFalse);
      expect(
        _texts(tester, keyed('price-rule-helper')),
        '24/12 – 25/12 mỗi năm',
      );
      await typePrice(tester, 'price-rule-price', '2000000');
      await tapKey(tester, 'price-rule-save');
      expect(
        (_sent(world)['from'], _sent(world)['to'], _sent(world)['template']),
        ('12-24', '12-25', 'christmas'),
      );
    });
  });

  group('Áp cho', () {
    testWidgets('"Mọi gói, cùng tỉ lệ" makes one series per package', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(10));

      expect(find.text('Chỉ gói Chân dung'), findsOneWidget);
      await _chooseMenu(tester, 'price-rule-apply', 'Mọi gói, cùng tỉ lệ');
      await typePrice(tester, 'price-rule-price', '2000000');
      await tapKey(tester, 'price-rule-save');

      expect(world.rules.saves.single.applyToAll, isTrue);
      final rules = world.rules.ownerRules;
      expect(rules, hasLength(2));
      expect(
        {for (final r in rules) r.serviceId: r.price},
        {'p1': 2000000, 'p2': scaledPrice(2000000, 1500000, 3200000)},
      );
      expect(rules.firstWhere((r) => r.serviceId == 'p2').price, 4270000);
      expect(world.events.single.params['applyAll'], isTrue);
    });

    testWidgets('one package: nothing to choose, the dropdown is not there', (
      tester,
    ) async {
      await world.init(packages: const [portrait]);
      await world.open(tester);
      await tapDay(tester, _nov(10));
      expect(keyed('price-rule-apply'), findsNothing);
    });
  });

  group('limits and failures', () {
    testWidgets('30 series: "Gói này đã có 30 chuỗi", Lưu is off', (
      tester,
    ) async {
      await world.init();
      for (var i = 1; i <= 30; i++) {
        world.seed(
          PriceRule(
            id: 'r$i',
            serviceId: 'p1',
            price: 1600000 + i,
            repeat: PriceRepeat.none,
            from: '2027-01-${i.toString().padLeft(2, '0')}',
            to: '2027-01-${i.toString().padLeft(2, '0')}',
          ),
        );
      }
      await world.open(tester);
      await tapDay(tester, _nov(10));
      await typePrice(tester, 'price-rule-price', '2000000');

      expect(find.text('Gói này đã có 30 chuỗi'), findsOneWidget);
      expect(_canSave(tester), isFalse);
    });

    testWidgets('a server refusal keeps the sheet and says why', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(10));
      await typePrice(tester, 'price-rule-price', '2000000');

      world.rules.nextErrorCode = 'rule_limit';
      await tapKey(tester, 'price-rule-save');
      expect(find.text('Gói này đã có 30 chuỗi'), findsOneWidget);
      expect(keyed('price-rule-save'), findsOneWidget);
      expect(_canSave(tester), isTrue);

      world.rules.nextErrorCode = 'unavailable';
      await tapKey(tester, 'price-rule-save');
      expect(find.text('Chưa lưu được, thử lại nhé'), findsOneWidget);
      expect(find.text('2.000.000'), findsOneWidget, reason: 'data is kept');
    });

    testWidgets('a field error from the server lands on its line', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(10));
      await typePrice(tester, 'price-rule-price', '2000000');

      world.rules.nextErrorCode = 'invalid_argument';
      world.rules.nextErrorField = 'price';
      await tapKey(tester, 'price-rule-save');
      expect(find.text('Giá phải lớn hơn 0'), findsOneWidget);
    });

    testWidgets('contact_leak on the name says so under the name field', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);
      await tapDay(tester, _nov(10));
      await typePrice(tester, 'price-rule-price', '2000000');
      await tester.enterText(keyed('price-rule-name'), 'Gọi 0912345678');
      await tester.pump();

      world.rules.nextErrorCode = 'contact_leak';
      world.rules.nextErrorField = 'name';
      await tapKey(tester, 'price-rule-save');
      expect(
        find.text('Tên không được chứa số điện thoại hay đường link'),
        findsOneWidget,
      );
      expect(find.text('Chưa lưu được, thử lại nhé'), findsNothing);
      expect(keyed('price-rule-save'), findsOneWidget);
      expect(find.text('Gọi 0912345678'), findsOneWidget, reason: 'kept');

      // Typing again takes the line away.
      await tester.enterText(keyed('price-rule-name'), 'Gọi');
      await tester.pump();
      expect(
        find.text('Tên không được chứa số điện thoại hay đường link'),
        findsNothing,
      );
    });

    testWidgets('while saving the button loads and the sheet stays', (
      tester,
    ) async {
      await world.init();
      world.rules.holdSave = true;
      await world.open(tester);
      await tapDay(tester, _nov(10));
      await typePrice(tester, 'price-rule-price', '2000000');

      await tester.tap(keyed('price-rule-save'));
      await tester.pump();
      expect(
        tester.widget<AppButton>(keyed('price-rule-save')).loading,
        isTrue,
      );
      expect(
        tester.widget<IconButton>(keyed('price-rule-close')).onPressed,
        isNull,
      );

      world.rules.releaseSave();
      await tester.pumpAndSettle();
      expect(keyed('price-rule-save'), findsNothing);
    });
  });

  group('edit the whole series', () {
    testWidgets('a weekly series: price, name and weekdays prefilled', (
      tester,
    ) async {
      await world.init();
      world.seed(weekendRule());
      await world.open(tester);
      await tapKey(tester, 'price-rule-r-weekend');

      expect(find.text('1.800.000'), findsOneWidget);
      expect(
        tester.widget<TextField>(keyed('price-rule-name')).controller?.text,
        'Cuối tuần',
      );
      expect(_switchOn(tester, 'price-rule-repeat'), isTrue);
      expect(find.text('Hằng tuần'), findsWidgets);
      expect(keyed('price-rule-from'), findsNothing);
      final context = tester.element(keyed('price-rule-weekdays'));
      expect(_weekdayOn(tester, 'sat', context), isTrue);
      expect(_weekdayOn(tester, 'fri', context), isFalse);
      expect(keyed('price-rule-apply'), findsNothing);
      expect(keyed('price-rule-templates'), findsNothing);

      await typePrice(tester, 'price-rule-price', '1900000');
      await tapKey(tester, 'price-rule-save');
      expect(world.rules.saves.single.ruleId, 'r-weekend');
      expect(_sent(world), {
        'serviceId': 'p1',
        'price': 1900000,
        'repeat': 'weekly',
        'name': 'Cuối tuần',
        'weekdays': ['sat', 'sun'],
      });
      expect(_texts(tester, priceLine(_nov(7))), '1,9M');
      expect(world.events.single.params['scope'], 'all');
    });

    testWidgets('a lunar series shows its next occurrence and keeps its days', (
      tester,
    ) async {
      await world.init();
      world.seed(tetRule());
      await world.open(tester);
      await tapKey(tester, 'price-rule-r-tet');

      expect(find.text('T7 30/1/2027'), findsOneWidget);
      expect(find.text('T4 10/2/2027'), findsOneWidget);
      expect(_switchOn(tester, 'price-rule-lunar'), isTrue);
      await typePrice(tester, 'price-rule-price', '2600000');
      await tapKey(tester, 'price-rule-save');

      expect(_sent(world), {
        'serviceId': 'p1',
        'price': 2600000,
        'repeat': 'yearly',
        'name': 'Tết Nguyên đán',
        'lunar': true,
        'from': '12-23',
        'to': '01-05',
        'template': 'tet',
      });
    });

    testWidgets('a one-off range of a past day can still be edited', (
      tester,
    ) async {
      await world.init();
      world.seed(
        const PriceRule(
          id: 'run',
          serviceId: 'p1',
          price: 2200000,
          repeat: PriceRepeat.none,
          from: '2026-11-04',
          to: '2026-11-08',
        ),
      );
      await world.open(tester);
      await tapKey(tester, 'price-rule-run');

      expect(find.text('T4 4/11/2026'), findsOneWidget);
      expect(find.text('Chỉ chọn từ hôm nay trở đi'), findsNothing);
      await typePrice(tester, 'price-rule-price', '2300000');
      await tapKey(tester, 'price-rule-save');
      expect(_sent(world)['from'], '2026-11-04');
    });

    testWidgets('Xoá chuỗi asks first, then deletes', (tester) async {
      await world.init();
      world.seed(weddingRule());
      await world.open(tester);
      await tapKey(tester, 'price-rule-r-wedding');

      await tapKey(tester, 'price-rule-delete');
      expect(find.text('Xoá chuỗi này?'), findsOneWidget);
      expect(find.text('Booking đã đặt giữ giá cũ.'), findsOneWidget);
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();
      expect(world.rules.deletes, isEmpty);
      expect(keyed('price-rule-delete'), findsOneWidget);

      await tapKey(tester, 'price-rule-delete');
      await tester.tap(find.text('Xoá'));
      await tester.pumpAndSettle();
      expect(world.rules.deletes, ['r-wedding']);
      expect(keyed('price-rule-delete'), findsNothing);
      expect(find.text('Đã xoá chuỗi'), findsOneWidget);
      expect(world.events.single.name, 'price_rule_delete');
    });
  });
}

String _texts(WidgetTester tester, Finder f) {
  final w = tester.widget(f);
  if (w is Text) {
    return w.data ?? '';
  }
  return tester
      .widgetList<Text>(find.descendant(of: f, matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .join();
}
