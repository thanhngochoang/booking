import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/packages/widgets/package_price_line.dart';

import '../../support/packages_world.dart';
import '../../support/screen_host.dart';

final _today = DateTime.utc(2026, 11, 6);

Future<void> _show(
  WidgetTester tester,
  ServicePackage p, {
  List<PriceRule> rules = const [],
}) async {
  await tester.pumpWidget(
    screenApp(
      home: Scaffold(
        body: PackagePriceLine(p, rules: rules, today: _today),
      ),
    ),
  );
}

PriceRule _once(String id, String name, int price, String from, String to) =>
    PriceRule(
      id: id,
      serviceId: 'p1',
      price: price,
      repeat: PriceRepeat.none,
      name: name,
      from: from,
      to: to,
    );

void main() {
  testWidgets('without series it is the base price', (tester) async {
    await _show(tester, portraitPackage);
    expect(find.text('1.500.000₫'), findsOneWidget);
  });

  testWidgets('without a day the series are not read', (tester) async {
    await tester.pumpWidget(
      screenApp(
        home: Scaffold(
          body: PackagePriceLine(portraitPackage, rules: [weekendSeries()]),
        ),
      ),
    );
    expect(find.text('1.500.000₫'), findsOneWidget);
  });

  testWidgets('weekly series and the nearest other one follow the price', (
    tester,
  ) async {
    await _show(
      tester,
      portraitPackage,
      rules: [tetSeries(), weekendSeries(), weddingSeries()],
    );
    expect(
      find.text('1.500.000₫ · cuối tuần 1,8M · Mùa cưới 2M'),
      findsOneWidget,
    );
  });

  testWidgets('only a weekly series, only a yearly one', (tester) async {
    await _show(tester, portraitPackage, rules: [weekendSeries()]);
    expect(find.text('1.500.000₫ · cuối tuần 1,8M'), findsOneWidget);
    await _show(tester, portraitPackage, rules: [tetSeries()]);
    expect(find.text('1.500.000₫ · Tết 2,5M'), findsOneWidget);
  });

  testWidgets('at most two extras, however many series there are', (
    tester,
  ) async {
    await _show(
      tester,
      portraitPackage,
      rules: [
        weekendSeries(),
        _once('a', 'Noel', 2200000, '2026-12-24', '2026-12-25'),
        _once('b', 'Cưới sớm', 2100000, '2026-11-20', '2026-11-21'),
        tetSeries(),
      ],
    );
    expect(
      find.text('1.500.000₫ · cuối tuần 1,8M · Cưới sớm 2,1M'),
      findsOneWidget,
    );
  });

  testWidgets('a series that is running counts as the nearest', (tester) async {
    await _show(
      tester,
      portraitPackage,
      rules: [
        _once('now', 'Mùa hoa', 1900000, '2026-11-01', '2026-11-10'),
        _once('next', 'Noel', 2200000, '2026-12-24', '2026-12-25'),
      ],
    );
    expect(find.text('1.500.000₫ · Mùa hoa 1,9M'), findsOneWidget);
  });

  testWidgets('a one-off that has passed is not mentioned', (tester) async {
    await _show(
      tester,
      portraitPackage,
      rules: [_once('old', 'Noel cũ', 2200000, '2025-12-24', '2025-12-25')],
    );
    expect(find.text('1.500.000₫'), findsOneWidget);
  });

  testWidgets('an unnamed series reads "Giá riêng"', (tester) async {
    await _show(
      tester,
      portraitPackage,
      rules: [
        const PriceRule(
          id: 'x',
          serviceId: 'p1',
          price: 2000000,
          repeat: PriceRepeat.yearly,
          from: '12-20',
          to: '12-26',
        ),
      ],
    );
    expect(find.text('1.500.000₫ · Giá riêng 2M'), findsOneWidget);
  });

  testWidgets('the base price is bold and the extras are muted', (
    tester,
  ) async {
    await _show(tester, portraitPackage, rules: [weekendSeries()]);
    final text = tester.widget<Text>(find.byType(Text));
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.style?.fontWeight, FontWeight.w600);
    expect(spans.last.style?.fontWeight, isNull);
    expect(spans.last.style?.color, isNot(spans.first.style?.color));
  });
}
