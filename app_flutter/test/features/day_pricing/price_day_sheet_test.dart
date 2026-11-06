import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart' show AppButton, AppIcons;
import 'package:photobooking/data/pricing/price_rule_repository.dart';

import '../../support/day_pricing_world.dart';

DateTime _nov(int day) => DateTime.utc(2026, 11, day);

bool _canSave(WidgetTester tester) =>
    tester.widget<AppButton>(keyed('price-day-save')).onPressed != null;

String _remove(WidgetTester tester) =>
    tester.widget<AppButton>(keyed('price-day-remove')).label;

/// Whether the radio of [scope] shows the filled dot.
bool _picked(WidgetTester tester, String scope) => tester
    .widgetList<Icon>(
      find.descendant(
        of: keyed('price-day-scope-$scope'),
        matching: find.byType(Icon),
      ),
    )
    .any((i) => i.icon == AppIcons.radioOn);

Future<void> _openWeddingDay(
  WidgetTester tester,
  DayPricingWorld world, {
  int day = 17,
  Map<String, Object?> exceptions = const {},
}) async {
  await world.init();
  world.seed(weddingRule(exceptions: exceptions));
  await world.open(tester);
  await tapDay(tester, _nov(day));
}

void main() {
  late DayPricingWorld world;

  setUp(() => world = DayPricingWorld());

  group('what the sheet says', () {
    testWidgets('title, package, the series that applies and the price', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);

      expect(find.text('Thứ 3 17/11'), findsOneWidget);
      expect(find.text('Chân dung'), findsWidgets);
      expect(find.text('Mùa cưới · 2.000.000₫'), findsOneWidget);
      expect(find.text('Hằng năm · 14/11 – 22/11'), findsWidgets);
      expect(find.text('Giá ngày này'), findsOneWidget);
      expect(find.text('2.000.000'), findsOneWidget);
      expect(find.text('Áp dụng cho'), findsOneWidget);
      expect(find.text('Chỉ ngày này'), findsOneWidget);
      expect(find.text('Ngày này và các ngày sau trong chuỗi'), findsOneWidget);
      expect(find.text('Cả chuỗi Mùa cưới'), findsOneWidget);
      expect(find.text('Lưu'), findsOneWidget);
    });

    testWidgets('"Giá ngày này" is the day\'s price, not the series\'', (
      tester,
    ) async {
      await _openWeddingDay(
        tester,
        world,
        day: 15,
        exceptions: {'2026-11-15': 1500000},
      );

      expect(find.text('Chủ nhật 15/11'), findsOneWidget);
      expect(find.text('Mùa cưới · 2.000.000₫'), findsOneWidget);
      expect(find.text('1.500.000'), findsOneWidget);
    });

    testWidgets('a day in two series says which one replaced the other', (
      tester,
    ) async {
      await world.init();
      world.seed(weekendRule());
      world.seed(weddingRule());
      await world.open(tester);
      await tapDay(tester, _nov(15));

      expect(find.text('Mùa cưới · 2.000.000₫'), findsOneWidget);
      expect(find.text('Cuối tuần 1,8M bị Mùa cưới thay'), findsOneWidget);
    });

    testWidgets('a day in one series has no such line', (tester) async {
      await _openWeddingDay(tester, world);
      expect(find.textContaining('bị'), findsNothing);
    });

    testWidgets('the red action follows the radio', (tester) async {
      await _openWeddingDay(tester, world);

      expect(_picked(tester, 'day'), isTrue);
      expect(_remove(tester), 'Bỏ ngày này khỏi chuỗi');
      await tapKey(tester, 'price-day-scope-following');
      expect(_picked(tester, 'following'), isTrue);
      expect(_picked(tester, 'day'), isFalse);
      expect(_remove(tester), 'Kết thúc chuỗi từ ngày này');
      await tapKey(tester, 'price-day-scope-all');
      expect(_remove(tester), 'Xoá chuỗi');
    });
  });

  group('Lưu', () {
    testWidgets('"Chỉ ngày này" writes an exception for that day', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);
      await typePrice(tester, 'price-day-price', '1500000');
      await tapKey(tester, 'price-day-save');

      final e = world.rules.exceptions.single;
      expect(
        (e.ruleId, e.day, e.value),
        ('r-wedding', _nov(17), const PriceException.custom(1500000)),
      );
      expect(world.rules.splits, isEmpty);
      expect(world.rules.saves, isEmpty);
      // Only that day changed.
      expect(_priceText(tester, _nov(17)), '1,5M');
      expect(_priceText(tester, _nov(16)), '2M');
      expect(_priceText(tester, _nov(18)), '2M');
      expect(find.text('Đã lưu giá'), findsOneWidget);
      expect(find.byKey(const Key('price-day-save')), findsNothing);
      expect(world.events.single.name, 'price_rule_exception');
      expect(world.events.single.params, {'kind': 'price'});
    });

    testWidgets('"Ngày này và các ngày sau" splits the series at the day', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);
      await tapKey(tester, 'price-day-scope-following');
      await typePrice(tester, 'price-day-price', '2200000');
      await tapKey(tester, 'price-day-save');

      final s = world.rules.splits.single;
      expect((s.ruleId, s.day, s.price), ('r-wedding', _nov(17), 2200000));
      expect(world.rules.exceptions, isEmpty);
      // The days before keep the old price, from the 17th on it is new.
      expect(world.rules.ownerRules, hasLength(2));
      expect(_priceText(tester, _nov(16)), '2M');
      expect(_priceText(tester, _nov(17)), '2,2M');
      expect(world.events.single.params, {'scope': 'following'});
      expect(world.events.single.name, 'price_rule_save');
    });

    testWidgets('"Cả chuỗi" saves the whole series with the new price', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);
      await tapKey(tester, 'price-day-scope-all');
      await typePrice(tester, 'price-day-price', '2100000');
      await tapKey(tester, 'price-day-save');

      final save = world.rules.saves.single;
      expect(save.ruleId, 'r-wedding');
      expect(save.input.toMap(), {
        'serviceId': 'p1',
        'price': 2100000,
        'repeat': 'yearly',
        'name': 'Mùa cưới',
        'from': '11-14',
        'to': '11-22',
      });
      expect(world.rules.ownerRules.single.price, 2100000);
      expect(world.events.single.params['scope'], 'all');
    });

    testWidgets('the price is checked first', (tester) async {
      await _openWeddingDay(tester, world);
      await typePrice(tester, 'price-day-price', '0');
      expect(find.text('Giá phải lớn hơn 0'), findsOneWidget);
      expect(_canSave(tester), isFalse);
      await typePrice(tester, 'price-day-price', '2000000000');
      expect(find.text('Giá tối đa 1.000.000.000₫'), findsOneWidget);
      expect(_canSave(tester), isFalse);
    });
  });

  group('the red action', () {
    testWidgets('"Bỏ ngày này khỏi chuỗi" drops the day from the series', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);
      await tapKey(tester, 'price-day-remove');

      final e = world.rules.exceptions.single;
      expect(
        (e.ruleId, e.day, e.value),
        ('r-wedding', _nov(17), const PriceException.skip()),
      );
      expect(world.events.single.params, {'kind': 'skip'});
      // The day is plain again.
      expect(_priceText(tester, _nov(17)), '1,5M');
    });

    testWidgets('"Kết thúc chuỗi từ ngày này" splits without a price', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);
      await tapKey(tester, 'price-day-scope-following');
      await tapKey(tester, 'price-day-remove');

      final s = world.rules.splits.single;
      expect((s.ruleId, s.day, s.price), ('r-wedding', _nov(17), null));
      expect(_priceText(tester, _nov(16)), '2M');
      expect(_priceText(tester, _nov(17)), '1,5M');
      expect(world.events.single.name, 'price_rule_delete');
    });

    testWidgets('"Xoá chuỗi" asks first: Giữ lại keeps it, Xoá deletes it', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);
      await tapKey(tester, 'price-day-scope-all');

      await tapKey(tester, 'price-day-remove');
      expect(find.text('Xoá chuỗi này?'), findsOneWidget);
      expect(find.text('Booking đã đặt giữ giá cũ.'), findsOneWidget);
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();
      expect(world.rules.deletes, isEmpty);
      expect(keyed('price-day-save'), findsOneWidget);

      await tapKey(tester, 'price-day-remove');
      await tester.tap(find.text('Xoá'));
      await tester.pumpAndSettle();
      expect(world.rules.deletes, ['r-wedding']);
      expect(find.text('Đã xoá chuỗi'), findsOneWidget);
      expect(world.rules.ownerRules, isEmpty);
    });
  });

  group('failures', () {
    testWidgets('50 exceptions: "Chuỗi này đã có 50 ngoại lệ"', (tester) async {
      await _openWeddingDay(tester, world);
      world.rules.nextErrorCode = 'exception_limit';
      await typePrice(tester, 'price-day-price', '1500000');
      await tapKey(tester, 'price-day-save');

      expect(find.text('Chuỗi này đã có 50 ngoại lệ'), findsOneWidget);
      expect(keyed('price-day-save'), findsOneWidget);
      expect(_canSave(tester), isTrue);
    });

    testWidgets('30 series: "Gói này đã có 30 chuỗi" on a split', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);
      await tapKey(tester, 'price-day-scope-following');
      world.rules.nextErrorCode = 'rule_limit';
      await typePrice(tester, 'price-day-price', '1500000');
      await tapKey(tester, 'price-day-save');

      expect(find.text('Gói này đã có 30 chuỗi'), findsOneWidget);
    });

    testWidgets('any other failure: the generic line, data kept', (
      tester,
    ) async {
      await _openWeddingDay(tester, world);
      world.rules.nextErrorCode = 'unavailable';
      await typePrice(tester, 'price-day-price', '1500000');
      await tapKey(tester, 'price-day-save');

      expect(find.text('Chưa lưu được, thử lại nhé'), findsOneWidget);
      expect(find.text('1.500.000'), findsOneWidget);
    });
  });
}

String _priceText(WidgetTester tester, DateTime d) =>
    tester.widget<Text>(priceLine(d)).data ?? '';
