import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/features/packages/widgets/price_table_sheet.dart';

import '../../support/day_price_packages.dart';
import '../../support/fake_price_rule_repository.dart';
import '../../support/screen_host.dart';

/// Today is Fri 2026-11-06.
Future<void> _show(
  WidgetTester tester, {
  List<PriceRule> rules = const [],
  String serviceId = 's1',
  VoidCallback? onBook,
}) async {
  final today = DateTime.utc(2026, 11, 6);
  final repo = FakePriceRuleRepository(today: () => today);
  for (final r in rules) {
    repo.seed(r);
  }
  await tester.pumpWidget(
    screenApp(
      overrides: [
        calendarTodayProvider.overrideWithValue(today),
        priceRuleRepositoryProvider.overrideWithValue(repo),
      ],
      home: Scaffold(
        body: PriceTableSheet(
          photographerId: 'p1',
          serviceId: serviceId,
          name: 'Chân dung 2 giờ',
          basePrice: 1500000,
          onBook: onBook,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the base price, then a row per series with its rule', (
    tester,
  ) async {
    await _show(tester, rules: dayPriceRules());

    expect(find.text('Bảng giá · Chân dung 2 giờ'), findsOneWidget);
    expect(find.text('Giá thường'), findsOneWidget);
    expect(find.text('1.500.000₫'), findsOneWidget);
    expect(find.text('Cuối tuần'), findsOneWidget);
    expect(find.text('Hằng tuần · T7, CN'), findsOneWidget);
    expect(find.text('1.800.000₫'), findsOneWidget);
    expect(find.text('Mùa cưới'), findsOneWidget);
    expect(find.text('Hằng năm · 14/11 – 22/11'), findsOneWidget);
    expect(find.text('2.000.000₫'), findsOneWidget);
    expect(find.text('Tết Nguyên đán'), findsOneWidget);
    expect(find.text('2.500.000₫'), findsOneWidget);
    // A lunar series says where it falls next, in solar days.
    expect(
      find.text(
        'Hằng năm · 23 Chạp – 5 Giêng (âm lịch) · lần tới T7 30/1 – T4 10/2/2027',
      ),
      findsOneWidget,
    );
    // The price of another package's series is not here.
    expect(find.text('5.000.000₫'), findsNothing);

    // Weekly first, then the soonest: Mùa cưới (14/11) before Tết (30/1).
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Giá thường'), lessThan(top('Cuối tuần')));
    expect(top('Cuối tuần'), lessThan(top('Mùa cưới')));
    expect(top('Mùa cưới'), lessThan(top('Tết Nguyên đán')));
  });

  testWidgets('exceptions are not listed', (tester) async {
    await _show(tester, rules: dayPriceRules());
    // 15/11 at 1,5M is an exception of Mùa cưới: no extra row, no count.
    expect(find.textContaining('15/11'), findsNothing);
    expect(find.textContaining('ngoại lệ'), findsNothing);
  });

  testWidgets('a one-off series that has passed is hidden', (tester) async {
    await _show(
      tester,
      rules: [
        const PriceRule(
          id: 'r-old',
          serviceId: 's1',
          price: 4000000,
          repeat: PriceRepeat.none,
          name: 'Đã qua',
          from: '2026-10-01',
          to: '2026-10-05',
        ),
        const PriceRule(
          id: 'r-next',
          serviceId: 's1',
          price: 3000000,
          repeat: PriceRepeat.none,
          name: 'Sắp tới',
          from: '2026-12-24',
          to: '2026-12-25',
        ),
      ],
    );
    expect(find.text('Đã qua'), findsNothing);
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Một lần · T5 24/12 – T6 25/12/2026'), findsOneWidget);
  });

  testWidgets('a package without series shows the base price only', (
    tester,
  ) async {
    await _show(tester, rules: dayPriceRules(), serviceId: 's3');
    expect(find.text('Giá thường'), findsOneWidget);
    expect(find.byKey(const Key('price-sheet-base')), findsOneWidget);
    expect(find.textContaining('Hằng'), findsNothing);
  });

  testWidgets('"Đặt gói này" is the primary action and closes the sheet', (
    tester,
  ) async {
    var booked = 0;
    await _show(tester, rules: dayPriceRules(), onBook: () => booked++);
    await tester.tap(find.byKey(const Key('price-sheet-book')));
    await tester.pumpAndSettle();
    expect(booked, 1);
  });

  testWidgets('"Đặt gói này" is off when the photographer takes no orders', (
    tester,
  ) async {
    await _show(tester, rules: dayPriceRules());
    final button = find.byKey(const Key('price-sheet-book'));
    expect(button, findsOneWidget);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Bảng giá · Chân dung 2 giờ'), findsOneWidget);
  });
}
