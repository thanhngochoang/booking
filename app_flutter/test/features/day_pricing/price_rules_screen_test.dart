import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/pricing/price_rules.dart';

import '../../support/day_pricing_world.dart';

const _rulesLocation = '/me/day-pricing/rules';

double _top(WidgetTester tester, String key) =>
    tester.getTopLeft(keyed(key)).dy;

void main() {
  late DayPricingWorld world;

  setUp(() => world = DayPricingWorld());

  testWidgets('groups by package with the base price, rows like the card', (
    tester,
  ) async {
    await world.init(packages: const [portrait, couple, product]);
    world.seed(weekendRule());
    world.seed(weddingRule(exceptions: {'2026-11-15': 1500000}));
    world.seed(tetRule());
    world.seed(weekendRule(id: 'c-weekend', serviceId: 'p2'));
    await world.open(tester, location: _rulesLocation);

    expect(find.text('Chuỗi giá'), findsOneWidget);
    expect(find.text('Chân dung · giá thường 1,5M'), findsOneWidget);
    expect(find.text('Cặp đôi · giá thường 3,2M'), findsOneWidget);
    expect(find.text('Sản phẩm · giá thường 1,2M'), findsOneWidget);

    // Portrait: weekly first, then Mùa cưới (this month), then Tết.
    final ruleTops = [
      _top(tester, 'price-rule-r-weekend'),
      _top(tester, 'price-rule-r-wedding'),
      _top(tester, 'price-rule-r-tet'),
    ];
    expect(ruleTops, [...ruleTops]..sort());
    // The couple's weekend row sits under the couple's heading.
    expect(
      _top(tester, 'price-rule-c-weekend'),
      greaterThan(_top(tester, 'price-rules-group-p2')),
    );

    expect(find.text('Hằng tuần · T7, CN'), findsNWidgets(2));
    expect(
      find.text('Hằng năm · 14/11 – 22/11 · 1 ngoại lệ (CN 15/11: 1,5M)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Hằng năm · 23 Chạp – 5 Giêng (âm lịch) · lần tới T7 30/1 – T4 10/2/2027',
      ),
      findsOneWidget,
    );
    expect(find.text('1,8M'), findsNWidgets(2));
    expect(find.text('2M'), findsOneWidget);
    expect(find.text('2,5M'), findsOneWidget);
  });

  testWidgets('a package without series says so', (tester) async {
    await world.init(packages: const [portrait, couple, product]);
    world.seed(weekendRule());
    await world.open(tester, location: _rulesLocation);

    expect(find.text('Chưa có chuỗi · mọi ngày 3,2M'), findsOneWidget);
    expect(find.text('Chưa có chuỗi · mọi ngày 1,2M'), findsOneWidget);
    expect(find.text('Chưa có chuỗi · mọi ngày 1,5M'), findsNothing);
  });

  testWidgets('a one-off range that has passed is hidden', (tester) async {
    await world.init();
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
    world.seed(
      const PriceRule(
        id: 'new',
        serviceId: 'p1',
        price: 2200000,
        repeat: PriceRepeat.none,
        name: 'Kỷ yếu mới',
        from: '2026-11-20',
        to: '2026-11-21',
      ),
    );
    await world.open(tester, location: _rulesLocation);

    expect(find.text('Kỷ yếu cũ'), findsNothing);
    expect(find.text('Kỷ yếu mới'), findsOneWidget);
    expect(find.text('Một lần · T6 20/11 – T7 21/11/2026'), findsOneWidget);
  });

  testWidgets('an ended series is under "Đã kết thúc" and can be deleted', (
    tester,
  ) async {
    await world.init();
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
    await world.open(tester, location: _rulesLocation);

    // Collapsed: only the header, with the count; the live row is above it.
    expect(find.text('Đã kết thúc · 1'), findsOneWidget);
    expect(keyed('price-rule-old'), findsNothing);
    expect(keyed('price-rule-r-weekend'), findsOneWidget);

    await tapKey(tester, 'price-rules-ended-p1');
    expect(keyed('price-rule-old'), findsOneWidget);
    expect(find.text('Kỷ yếu cũ'), findsOneWidget);
    expect(
      tester.widget<Opacity>(keyed('price-rules-ended-list-p1')).opacity,
      0.6,
    );
    expect(
      _top(tester, 'price-rule-old'),
      greaterThan(_top(tester, 'price-rule-r-weekend')),
    );

    await tapKey(tester, 'price-rule-old');
    expect(find.text('3.000.000'), findsOneWidget);
    await tapKey(tester, 'price-rule-delete');
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();
    expect(world.rules.deletes, ['old']);
    expect(find.text('Đã kết thúc · 1'), findsNothing);
  });

  testWidgets('a package with only ended series still says "Chưa có chuỗi"', (
    tester,
  ) async {
    await world.init();
    world.seed(
      const PriceRule(
        id: 'old',
        serviceId: 'p1',
        price: 3000000,
        repeat: PriceRepeat.none,
        from: '2026-10-01',
        to: '2026-10-03',
      ),
    );
    await world.open(tester, location: _rulesLocation);
    expect(find.text('Chưa có chuỗi · mọi ngày 1,5M'), findsOneWidget);
    expect(find.text('Đã kết thúc · 1'), findsOneWidget);
  });

  testWidgets('the calendar screen keeps ended series out of its card', (
    tester,
  ) async {
    await world.init();
    world.seed(
      const PriceRule(
        id: 'old',
        serviceId: 'p1',
        price: 3000000,
        repeat: PriceRepeat.none,
        from: '2026-10-01',
        to: '2026-10-03',
      ),
    );
    await world.open(tester);
    expect(keyed('price-rule-old'), findsNothing);
    expect(find.textContaining('Đã kết thúc'), findsNothing);
  });

  testWidgets('the hidden package comes last and is dimmed', (tester) async {
    await world.init(packages: const [product, portrait, couple]);
    await world.open(tester, location: _rulesLocation);

    final tops = [
      for (final id in ['p1', 'p2', 'p3'])
        _top(tester, 'price-rules-group-$id'),
    ];
    expect(tops, [...tops]..sort());
    expect(tester.widget<Opacity>(keyed('price-rules-group-p3')).opacity, 0.6);
    expect(tester.widget<Opacity>(keyed('price-rules-group-p1')).opacity, 1);
  });

  testWidgets('a row opens the series to edit', (tester) async {
    await world.init();
    world.seed(weekendRule());
    await world.open(tester, location: _rulesLocation);

    await tapKey(tester, 'price-rule-r-weekend');
    expect(find.text('1.800.000'), findsOneWidget);
    expect(keyed('price-rule-delete'), findsOneWidget);
  });

  testWidgets('"Đặt giá" opens the sheet with the template chips', (
    tester,
  ) async {
    await world.init();
    await world.open(tester, location: _rulesLocation);

    await tapKey(tester, 'price-rules-add');
    expect(keyed('price-rule-templates'), findsOneWidget);
    expect(find.text('Giá · Chân dung'), findsOneWidget);
  });

  testWidgets('the calendar icon goes back to S08.10', (tester) async {
    await world.init();
    await world.open(tester);
    await tapKey(tester, 'day-pricing-list');
    expect(find.text('Chuỗi giá'), findsOneWidget);

    await tapKey(tester, 'price-rules-calendar');
    expect(find.text('Giá theo ngày'), findsOneWidget);
    expect(keyed('day-pricing-calendar'), findsOneWidget);
    expect(world.router.canPop(), isFalse);
  });

  testWidgets('opened on its own, the calendar icon replaces it', (
    tester,
  ) async {
    await world.init();
    await world.open(tester, location: _rulesLocation);

    await tapKey(tester, 'price-rules-calendar');
    expect(keyed('day-pricing-calendar'), findsOneWidget);
  });

  testWidgets('no packages: add one first, no "Đặt giá"', (tester) async {
    await world.init(packages: const []);
    await world.open(tester, location: _rulesLocation);

    expect(find.text('Thêm gói trước ở Gói dịch vụ'), findsOneWidget);
    expect(keyed('price-rules-add'), findsNothing);
  });

  testWidgets('a failed load shows the error', (tester) async {
    await world.init();
    world.rules.failWatch = true;
    await world.open(tester, location: _rulesLocation);

    expect(find.text('Không tải được giá theo ngày'), findsOneWidget);
  });

  testWidgets('fits 320 dp at text scale 1.3 without overflow', (tester) async {
    await world.init(packages: const [portrait, couple, product]);
    world.seed(weekendRule());
    world.seed(weddingRule(exceptions: {'2026-11-15': 1500000}));
    world.seed(tetRule());
    await world.open(
      tester,
      location: _rulesLocation,
      width: 320,
      height: 900,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
