import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/packages/widgets/package_price_line.dart';

import '../../support/packages_world.dart';
import '../../support/screen_host.dart';

Future<void> _show(WidgetTester tester, ServicePackage p) async {
  await tester.pumpWidget(screenApp(home: Scaffold(body: PackagePriceLine(p))));
}

void main() {
  testWidgets('one price on every day reads as the full amount', (
    tester,
  ) async {
    await _show(tester, hiddenPackage);
    expect(find.text('900.000₫'), findsOneWidget);
    await _show(
      tester,
      const ServicePackage(
        id: 'x',
        name: 'x',
        priceVnd: 1500000,
        durationMinutes: 60,
      ),
    );
    expect(find.text('1.500.000₫'), findsOneWidget);
  });

  testWidgets('weekday and weekend prices with a special price', (
    tester,
  ) async {
    await _show(tester, twoLevelPackage);
    expect(find.text('T2–T6 1,5M · T7–CN 1,8M · Lễ 2,2M'), findsOneWidget);
  });

  testWidgets('weekday and weekend prices without a special price', (
    tester,
  ) async {
    await _show(
      tester,
      ServicePackage(
        id: 'x',
        name: 'x',
        priceVnd: twoLevelPackage.priceVnd,
        durationMinutes: 60,
        dayPrices: twoLevelPackage.dayPrices,
      ),
    );
    expect(find.text('T2–T6 1,5M · T7–CN 1,8M'), findsOneWidget);
  });

  testWidgets('a price per day reads as a range', (tester) async {
    await _show(tester, perDayPackage);
    expect(find.text('3,2M–4M · theo ngày'), findsOneWidget);
  });

  testWidgets('a single price with a special price', (tester) async {
    await _show(
      tester,
      const ServicePackage(
        id: 'x',
        name: 'x',
        priceVnd: 6000000,
        durationMinutes: 60,
        specialPrice: 7000000,
      ),
    );
    expect(find.text('6.000.000₫ · Lễ 7M'), findsOneWidget);
  });
}
