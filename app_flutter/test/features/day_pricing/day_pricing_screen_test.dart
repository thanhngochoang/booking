import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart' show AppColors, AppButton;
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';

import '../../support/day_pricing_world.dart';

DateTime _nov(int day) => DateTime.utc(2026, 11, day);

String _text(WidgetTester tester, Finder f) =>
    tester.widget<Text>(f).data ?? '';

bool _outlined(WidgetTester tester, DateTime d) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: dayCell(d), matching: find.byType(DecoratedBox)),
    )
    .any((e) {
      final dec = e.decoration;
      return dec is BoxDecoration && dec.border?.top.color == AppColors.warning;
    });

void main() {
  late DayPricingWorld world;

  setUp(() => world = DayPricingWorld());

  group('the calendar', () {
    testWidgets('shows the price of every day, the same as monthPrices', (
      tester,
    ) async {
      await world.init();
      world.seed(weekendRule());
      world.seed(weddingRule(exceptions: {'2026-11-15': 1500000}));
      world.seed(tetRule());
      await world.open(tester);

      final prices = monthPrices(
        portrait.priceVnd,
        'p1',
        world.rules.ownerRules,
        2026,
        11,
      );
      expect(prices, hasLength(30));
      for (final e in prices.entries) {
        expect(
          _text(tester, priceLine(e.key)),
          ruleShortPrice(e.value.amount),
          reason: dayKey(e.key),
        );
      }
      // The weekend 1,8M, the wedding week 2M, the exception 1,5M on a Sunday.
      expect(_text(tester, priceLine(_nov(7))), '1,8M');
      expect(_text(tester, priceLine(_nov(10))), '1,5M');
      expect(_text(tester, priceLine(_nov(14))), '2M');
      expect(_text(tester, priceLine(_nov(15))), '1,5M');
    });

    testWidgets('a day in a series is bold, the base price is dim', (
      tester,
    ) async {
      await world.init();
      world.seed(weekendRule());
      await world.open(tester);

      FontWeight? weight(DateTime d) => tester
          .widget<Text>(find.byKey(ValueKey('app-calendar-solar-${dayKey(d)}')))
          .style
          ?.fontWeight;
      expect(weight(_nov(7)), FontWeight.w700);
      expect(weight(_nov(10)), FontWeight.w500);
      Color? colour(DateTime d) =>
          tester.widget<Text>(priceLine(d)).style?.color;
      expect(colour(_nov(10)), isNot(colour(_nov(7))));
    });

    testWidgets('a day with an exception has the warning outline', (
      tester,
    ) async {
      await world.init();
      world.seed(
        weddingRule(exceptions: {'2026-11-15': 1500000, '2026-11-16': null}),
      );
      await world.open(tester);

      expect(_outlined(tester, _nov(15)), isTrue);
      expect(_outlined(tester, _nov(16)), isTrue);
      expect(_outlined(tester, _nov(14)), isFalse);
      expect(_outlined(tester, _nov(10)), isFalse);
    });

    testWidgets('shows the lunar day and moves between months', (tester) async {
      await world.init();
      await world.open(tester);

      expect(find.text('Tháng 11 / 2026'), findsOneWidget);
      // 9/11/2026 is the 1st of the 10th lunar month.
      expect(find.text('1/10'), findsOneWidget);
      await tester.tap(find.byTooltip('Tháng sau'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 12 / 2026'), findsOneWidget);
      expect(priceLine(DateTime.utc(2026, 12, 25)), findsOneWidget);
    });

    testWidgets('one legend line: series, exception, dim', (tester) async {
      await world.init();
      await world.open(tester);

      final legend = find.byKey(const Key('day-pricing-legend'));
      for (final t in ['chuỗi', 'ngoại lệ', 'mờ = giá thường']) {
        expect(
          find.descendant(of: legend, matching: find.text(t)),
          findsOneWidget,
        );
      }
    });
  });

  group('the package chips', () {
    testWidgets('active packages first, the hidden one last and dimmed', (
      tester,
    ) async {
      await world.init(packages: const [product, portrait, couple]);
      await world.open(tester, location: '/me/day-pricing');

      final chips = tester
          .widgetList<Opacity>(
            find.descendant(
              of: keyed('day-pricing-packages'),
              matching: find.byType(Opacity),
            ),
          )
          .toList();
      expect(chips.map((o) => o.opacity), [1, 1, 0.6]);
      expect(find.text('Chân dung · 1,5M'), findsOneWidget);
      expect(find.text('Cặp đôi · 3,2M'), findsOneWidget);
      expect(find.text('Sản phẩm · 1,2M'), findsOneWidget);
      // No ?service=: the first package that is on.
      expect(_text(tester, priceLine(_nov(10))), '1,5M');
    });

    testWidgets('?service= picks the package; a chip switches it', (
      tester,
    ) async {
      await world.init();
      world.seed(weekendRule(id: 'r2', serviceId: 'p2'));
      await world.open(tester, location: '/me/day-pricing?service=p2');
      expect(_text(tester, priceLine(_nov(10))), '3,2M');
      expect(_text(tester, priceLine(_nov(7))), '1,8M');

      await tapKey(tester, 'day-pricing-package-p1');
      expect(_text(tester, priceLine(_nov(10))), '1,5M');
      expect(_text(tester, priceLine(_nov(7))), '1,5M');
    });
  });

  group('the series card', () {
    testWidgets('weekly first, then the soonest, ended one-offs hidden', (
      tester,
    ) async {
      await world.init();
      world.seed(tetRule());
      world.seed(weddingRule());
      world.seed(weekendRule());
      world.seed(
        const PriceRule(
          id: 'old',
          serviceId: 'p1',
          price: 3000000,
          repeat: PriceRepeat.none,
          name: 'Kỷ yếu cũ',
          from: '2026-10-01',
          to: '2026-10-03',
        ),
      );
      world.seed(weddingRule(id: 'other', serviceId: 'p2'));
      await world.open(tester);

      expect(keyed('price-rule-old'), findsNothing);
      expect(keyed('price-rule-other'), findsNothing);
      final tops = [
        for (final id in ['r-weekend', 'r-wedding', 'r-tet'])
          tester.getTopLeft(keyed('price-rule-$id')).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(find.text('Hằng tuần · T7, CN'), findsOneWidget);
      expect(find.text('Hằng năm · 14/11 – 22/11'), findsOneWidget);
      expect(
        find.text('Hằng năm · 23 Chạp – 5 Giêng (âm lịch)'),
        findsOneWidget,
      );
    });

    testWidgets('a package without series says so', (tester) async {
      await world.init();
      await world.open(tester);
      expect(find.text('Chưa có chuỗi · mọi ngày 1,5M'), findsOneWidget);
    });

    testWidgets('a row opens the whole series to edit', (tester) async {
      await world.init();
      world.seed(weddingRule());
      await world.open(tester);

      await tapKey(tester, 'price-rule-r-wedding');
      expect(find.text('2.000.000'), findsOneWidget);
      expect(keyed('price-rule-delete'), findsOneWidget);
      expect(keyed('price-rule-apply'), findsNothing);
    });
  });

  group('taps', () {
    testWidgets('a day in a series opens the day sheet', (tester) async {
      await world.init();
      world.seed(weddingRule());
      await world.open(tester);

      await tapDay(tester, _nov(17));
      expect(keyed('price-day-title'), findsOneWidget);
      expect(find.text('Thứ 3 17/11'), findsOneWidget);
      expect(keyed('price-rule-save'), findsNothing);
    });

    testWidgets('another day opens "Đặt giá" with that day as from and to', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);

      await tapDay(tester, _nov(10));
      expect(find.text('Đặt giá'), findsWidgets);
      expect(find.text('T3 10/11/2026'), findsNWidgets(2));
      // No template chips when a day was tapped.
      expect(keyed('price-rule-templates'), findsNothing);
    });

    testWidgets('a day the series dropped opens it, to take that back', (
      tester,
    ) async {
      await world.init();
      world.seed(weddingRule(exceptions: {'2026-11-16': null}));
      await world.open(tester);

      await tapDay(tester, _nov(16));
      expect(keyed('price-day-title'), findsOneWidget);
      expect(keyed('price-day-clear'), findsOneWidget);
      expect(keyed('price-rule-save'), findsNothing);
    });
  });

  group('selecting a range', () {
    testWidgets('press, hold and drag, then "Đặt giá" uses the range', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);

      await dragRange(tester, _nov(10), _nov(12));
      expect(
        keyed('price-rule-save'),
        findsNothing,
        reason: 'a drag opens no sheet',
      );

      await tapKey(tester, 'day-pricing-add');
      expect(find.text('T3 10/11/2026'), findsOneWidget);
      expect(find.text('T5 12/11/2026'), findsOneWidget);
      expect(keyed('price-rule-templates'), findsNothing);
    });

    testWidgets('a tap clears the range and the sheet is for that day', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);

      await dragRange(tester, _nov(10), _nov(12));
      await tapDay(tester, _nov(20));
      expect(find.text('T6 20/11/2026'), findsNWidgets(2));
      await tapKey(tester, 'price-rule-close');
      // Back on the calendar: "Đặt giá" starts from today, with templates.
      await tapKey(tester, 'day-pricing-add');
      expect(keyed('price-rule-templates'), findsOneWidget);
    });

    testWidgets('two plain taps are two sheets, never a range', (tester) async {
      await world.init();
      await world.open(tester);

      await tapDay(tester, _nov(10));
      await tapKey(tester, 'price-rule-close');
      await tapDay(tester, _nov(12));
      expect(find.text('T5 12/11/2026'), findsNWidgets(2));
      expect(find.text('T3 10/11/2026'), findsNothing);
    });
  });

  group('"Đặt giá"', () {
    testWidgets('with nothing selected opens from today with the templates', (
      tester,
    ) async {
      await world.init();
      await world.open(tester);

      final add = find.byKey(const Key('day-pricing-add'));
      expect(tester.widget<AppButton>(add).onPressed, isNotNull);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(keyed('price-rule-templates'), findsOneWidget);
      expect(find.text('T6 6/11/2026'), findsNWidgets(2));
    });
  });

  group('states', () {
    testWidgets('no packages: add one first', (tester) async {
      await world.init(packages: const []);
      await world.open(tester);

      expect(find.text('Thêm gói trước ở Gói dịch vụ'), findsOneWidget);
      expect(keyed('day-pricing-add'), findsNothing);
      await tester.tap(find.text('Thêm gói'));
      await tester.pumpAndSettle();
      expect(find.text('stub /me/packages/new'), findsOneWidget);
    });

    testWidgets('a failed load shows the error with retry', (tester) async {
      await world.init();
      world.rules.failWatch = true;
      await world.open(tester);

      expect(find.text('Không tải được giá theo ngày'), findsOneWidget);
      world.rules.failWatch = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(keyed('day-pricing-calendar'), findsOneWidget);
    });

    testWidgets('the list icon opens the series list', (tester) async {
      await world.init();
      world.seed(weekendRule());
      await world.open(tester);

      await tapKey(tester, 'day-pricing-list');
      expect(find.text('Chuỗi giá'), findsOneWidget);
      expect(find.text('Chân dung · giá thường 1,5M'), findsOneWidget);
    });

    testWidgets('fits 320 dp at text scale 1.3 without overflow', (
      tester,
    ) async {
      await world.init();
      world.seed(weekendRule());
      world.seed(tetRule());
      await world.open(tester, width: 320, height: 900, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
}
