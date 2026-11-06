import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/data/pricing/special_days.dart';
import 'package:photobooking/features/packages/widgets/price_table_sheet.dart';

import '../../support/day_price_packages.dart';
import '../../support/screen_host.dart';

Future<void> _show(
  WidgetTester tester,
  PricedService pricing, {
  VoidCallback? onBook,
  Map<int, List<Holiday>> holidays = const {},
  List<SpecialDayRange> ranges = const [],
}) async {
  final specialRepo = FakeSpecialDayRepository();
  for (final r in ranges) {
    specialRepo.seed('p1', r);
  }
  await tester.pumpWidget(
    screenApp(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime.utc(2026, 11, 6)),
        holidayRepositoryProvider.overrideWithValue(
          FakeHolidayRepository(holidays),
        ),
        specialDayRepositoryProvider.overrideWithValue(specialRepo),
      ],
      home: Scaffold(
        body: PriceTableSheet(
          photographerId: 'p1',
          name: 'Chân dung 2 giờ',
          pricing: pricing,
          onBook: onBook,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PricedService _prices(List<int> week, {int? special}) => PricedService(
  price: week.first,
  dayPrices: {for (final (i, w) in Weekday.values.indexed) w: week[i]},
  specialPrice: special,
);

void main() {
  testWidgets('price table sheet groups equal weekdays ("Thứ 2 – Thứ 6")', (
    tester,
  ) async {
    await _show(tester, dayPricePortrait);
    expect(find.text('Bảng giá · Chân dung 2 giờ'), findsOneWidget);
    expect(find.text('Thứ 2 – Thứ 6'), findsOneWidget);
    expect(find.text('Thứ 7, Chủ nhật'), findsOneWidget);
    expect(find.text('1.500.000₫'), findsOneWidget);
    expect(find.text('1.800.000₫'), findsOneWidget);
  });

  testWidgets('a price per day lists each run of days', (tester) async {
    await _show(tester, dayPriceCouple);
    expect(find.text('Thứ 2 – Thứ 6'), findsOneWidget);
    expect(find.text('Thứ 7'), findsOneWidget);
    expect(find.text('Chủ nhật'), findsOneWidget);
    expect(find.text('3.200.000₫'), findsOneWidget);
    expect(find.text('4.000.000₫'), findsOneWidget);
    expect(find.text('3.600.000₫'), findsOneWidget);
    expect(find.byKey(const Key('price-sheet-special')), findsNothing);

    await _show(tester, _prices([100, 200, 200, 100, 100, 100, 100]));
    expect(find.text('Thứ 2'), findsOneWidget);
    expect(find.text('Thứ 3, Thứ 4'), findsOneWidget);
    expect(find.text('Thứ 5 – Chủ nhật'), findsOneWidget);
  });

  testWidgets('the special row shows the price and the next 3 special days', (
    tester,
  ) async {
    await _show(
      tester,
      dayPricePortrait,
      holidays: {
        2026: [
          // Past: left out.
          const Holiday(day: '2026-09-02', name: 'Quốc khánh'),
          const Holiday(day: '2026-11-20', name: 'Ngày Nhà giáo'),
        ],
        2027: [
          const Holiday(day: '2027-02-06', name: 'Tết'),
          const Holiday(day: '2027-02-07', name: 'Tết'),
          const Holiday(day: '2027-02-08', name: 'Tết'),
          const Holiday(day: '2027-04-30', name: 'Giải phóng'),
        ],
      },
      ranges: [
        const SpecialDayRange(
          id: 'a',
          name: 'Mùa cưới',
          from: '2026-11-14',
          to: '2026-11-22',
        ),
      ],
    );
    expect(find.text('Ngày lễ, ngày đặc biệt'), findsOneWidget);
    expect(find.text('2.200.000₫'), findsOneWidget);
    expect(
      find.text('Mùa cưới 14–22/11 · Ngày Nhà giáo 20/11 · Tết 6–8/2'),
      findsOneWidget,
    );
  });

  testWidgets('a package without a special price has no special row', (
    tester,
  ) async {
    await _show(tester, _prices([100, 100, 100, 100, 100, 200, 200]));
    expect(find.text('Ngày lễ, ngày đặc biệt'), findsNothing);
  });

  testWidgets('"Đặt gói này" is the primary action and closes the sheet', (
    tester,
  ) async {
    var booked = 0;
    await _show(tester, dayPricePortrait, onBook: () => booked++);
    await tester.tap(find.byKey(const Key('price-sheet-book')));
    await tester.pumpAndSettle();
    expect(booked, 1);
  });

  testWidgets('"Đặt gói này" is off when the photographer takes no orders', (
    tester,
  ) async {
    await _show(tester, dayPricePortrait);
    final button = find.byKey(const Key('price-sheet-book'));
    expect(button, findsOneWidget);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Bảng giá · Chân dung 2 giờ'), findsOneWidget);
  });
}
