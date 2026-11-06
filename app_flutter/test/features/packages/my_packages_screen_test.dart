import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart' show AppButton, AppColors;
import 'package:photobooking/data/pricing/price_rules.dart';

import '../../support/packages_world.dart';

Finder _key(String k) => find.byKey(Key(k));

/// Portrait (on, 1,5M, with series), Couple (on, 3,2M), Product (hidden).
Future<PackagesWorld> _world({bool series = true}) async {
  final world = PackagesWorld();
  await world.init(packages: [portraitPackage, couplePackage, hiddenPackage]);
  if (series) {
    world.rules.seed(weekendSeries());
    world.rules.seed(weddingSeries());
    world.rules.seed(tetSeries());
    world.rules.seed(weekendSeries(serviceId: 'p2'));
    world.rules.seed(tetSeries(serviceId: 'p2'));
  }
  return world;
}

Future<void> _open(WidgetTester tester, PackagesWorld w) async {
  await tester.pumpWidget(w.app());
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _dragDown(WidgetTester tester, Finder handle, double dy) async {
  final g = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await g.moveBy(Offset(0, dy / 2));
  await tester.pump();
  await g.moveBy(Offset(0, dy / 2));
  await tester.pump();
  await g.up();
  await tester.pumpAndSettle();
}

List<String> _ids(PackagesWorld w) => [
  for (final p in w.packages.stored(w.w.uid)) p.id,
];

/// The package ids top to bottom as the sort list shows them.
List<String> _sortOrder(WidgetTester tester) {
  final ids = ['p1', 'p2', 'p3'];
  ids.sort(
    (a, b) => tester
        .getTopLeft(_key('package-handle-$a'))
        .dy
        .compareTo(tester.getTopLeft(_key('package-handle-$b')).dy),
  );
  return ids;
}

void main() {
  testWidgets('lists the packages with base price, extras and switches', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);

    expect(find.text('Gói dịch vụ'), findsOneWidget);
    expect(
      find.text('2 gói đang bật · giá dưới là giá ngày thường'),
      findsOneWidget,
    );
    expect(find.text('Chân dung 2 giờ'), findsOneWidget);
    expect(find.text('2 giờ · 40 ảnh chỉnh · giao 3 ngày'), findsOneWidget);
    // Base price, then the weekly series and the nearest other series
    // (Mùa cưới 14/11 comes before Tết).
    expect(
      find.text('1.500.000₫ · cuối tuần 1,8M · Mùa cưới 2M'),
      findsOneWidget,
    );
    // Cặp đôi has no wedding series: the weekly one and Tết.
    expect(find.text('3.200.000₫ · cuối tuần 1,8M · Tết 2,5M'), findsOneWidget);
    // A hidden package: the chip and the base price alone.
    expect(_key('package-hidden-p3'), findsOneWidget);
    expect(find.text('Đang ẩn'), findsOneWidget);
    expect(find.text('900.000₫'), findsOneWidget);
    expect(tester.widget<Switch>(_key('package-switch-p1')).value, isTrue);
    expect(tester.widget<Switch>(_key('package-switch-p2')).value, isTrue);
    expect(tester.widget<Switch>(_key('package-switch-p3')).value, isFalse);
    expect(find.widgetWithText(AppButton, 'Thêm gói'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a package without series shows the base price alone', (
    tester,
  ) async {
    final w = await _world(series: false);
    await _open(tester, w);
    expect(find.text('1.500.000₫'), findsOneWidget);
    expect(find.textContaining('cuối tuần'), findsNothing);
  });

  testWidgets('a series that ended is not an extra', (tester) async {
    final w = await _world(series: false);
    w.rules.seed(
      const PriceRule(
        id: 'old',
        serviceId: 'p1',
        price: 2000000,
        repeat: PriceRepeat.none,
        name: 'Noel cũ',
        from: '2025-12-24',
        to: '2025-12-25',
      ),
    );
    w.rules.seed(
      const PriceRule(
        id: 'next',
        serviceId: 'p1',
        price: 2200000,
        repeat: PriceRepeat.none,
        name: 'Noel',
        from: '2026-12-24',
        to: '2026-12-25',
      ),
    );
    await _open(tester, w);
    expect(find.text('1.500.000₫ · Noel 2,2M'), findsOneWidget);
  });

  testWidgets('"Giá theo ngày" names up to three series and counts them all', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);
    expect(find.text('Giá theo ngày'), findsOneWidget);
    expect(
      find.text('Cuối tuần, Mùa cưới, Tết · 5 chuỗi'),
      findsOneWidget,
      reason: 'names once, all five series counted',
    );
  });

  testWidgets('"Giá theo ngày" with no series says so and offers "Đặt giá"', (
    tester,
  ) async {
    final w = await _world(series: false);
    await _open(tester, w);
    expect(
      find.text('Cuối tuần và ngày lễ lấy bằng giá thường · Đặt giá'),
      findsOneWidget,
    );
  });

  testWidgets('"Giá theo ngày" opens S08.10', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('packages-day-pricing'));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/day-pricing'), findsOneWidget);
  });

  testWidgets('a switch shows and hides a package', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('package-switch-p3'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.w.uid).last.active, isTrue);
    expect(
      find.text('3 gói đang bật · giá dưới là giá ngày thường'),
      findsOneWidget,
    );
    await tester.tap(_key('package-switch-p2'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.w.uid)[1].active, isFalse);
    expect(
      find.text('2 gói đang bật · giá dưới là giá ngày thường'),
      findsOneWidget,
    );
    expect(
      find.text('Khách sẽ không đặt được bạn cho tới khi bật lại một gói'),
      findsNothing,
    );
  });

  testWidgets('turning off the last active package asks first', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('package-switch-p2'));
    await tester.pumpAndSettle();
    expect(
      find.text('Khách sẽ không đặt được bạn cho tới khi bật lại một gói'),
      findsNothing,
    );

    await tester.tap(_key('package-switch-p1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Khách sẽ không đặt được bạn cho tới khi bật lại một gói'),
      findsOneWidget,
    );
    expect(w.packages.stored(w.w.uid).first.active, isTrue);

    await tester.tap(find.text('Giữ bật'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.w.uid).first.active, isTrue);

    await tester.tap(_key('package-switch-p1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Tắt gói'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.w.uid).first.active, isFalse);
    expect(
      find.text('0 gói đang bật · giá dưới là giá ngày thường'),
      findsOneWidget,
    );
  });

  testWidgets('the confirmation of the last package is a red button', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('package-switch-p2'));
    await tester.pumpAndSettle();
    await tester.tap(_key('package-switch-p1'));
    await tester.pumpAndSettle();
    final red = tester.widget<FilledButton>(
      find.descendant(
        of: find.widgetWithText(AppButton, 'Tắt gói'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(red.style?.backgroundColor?.resolve({}), AppColors.error);
  });

  testWidgets('a failed write says so and changes nothing', (tester) async {
    final w = await _world();
    await _open(tester, w);
    w.packages.failWrites = true;
    await tester.tap(_key('package-switch-p3'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu được, thử lại nhé'), findsOneWidget);
    expect(w.packages.stored(w.w.uid).last.active, isFalse);
  });

  testWidgets('without packages: the empty text, the row and the add button', (
    tester,
  ) async {
    final w = PackagesWorld();
    await w.init();
    await _open(tester, w);
    expect(
      find.text('Thêm gói đầu tiên để khách đặt được bạn'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Thêm gói'), findsOneWidget);
    expect(_key('packages-day-pricing'), findsOneWidget);
    expect(_key('packages-sort'), findsNothing);
  });

  testWidgets('tapping a package and Thêm gói navigate', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('package-p2'));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/packages/p2'), findsOneWidget);
    w.router.pop();
    await tester.pumpAndSettle();
    await tester.tap(_key('packages-add'));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/packages/new'), findsOneWidget);
  });

  group('sort mode', () {
    testWidgets('there is no drag handle outside sort mode', (tester) async {
      final w = await _world();
      await _open(tester, w);
      expect(_key('package-handle-p1'), findsNothing);
      expect(_key('package-up-p1'), findsNothing);
      // A long press on a card drags nothing.
      final before = tester.getTopLeft(_key('package-p1'));
      final g = await tester.startGesture(tester.getCenter(_key('package-p1')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveBy(const Offset(0, 160));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_key('package-p1')), before);
      expect(w.packages.writes, 0);
    });

    testWidgets('"Sắp xếp" shows with two packages and not with one', (
      tester,
    ) async {
      final w = PackagesWorld();
      await w.init(packages: [portraitPackage]);
      await _open(tester, w);
      expect(_key('packages-sort'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final w2 = await _world();
      await _open(tester, w2);
      expect(find.text('Sắp xếp'), findsOneWidget);
    });

    testWidgets('enters with the title, "Xong", the hint and cards', (
      tester,
    ) async {
      final w = await _world();
      await _open(tester, w);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();
      expect(find.text('Sắp xếp gói'), findsOneWidget);
      expect(find.text('Xong'), findsOneWidget);
      expect(find.text('Sắp xếp'), findsNothing);
      expect(
        find.text(
          'Kéo, hoặc dùng nút Lên / Xuống. Thứ tự này hiện ở hồ sơ và khi '
          'khách chọn gói.',
        ),
        findsOneWidget,
      );
      // Name and base price only; no switch, no extras, no "Thêm gói".
      expect(find.text('1.500.000₫'), findsOneWidget);
      expect(find.textContaining('cuối tuần'), findsNothing);
      expect(_key('package-switch-p1'), findsNothing);
      expect(_key('packages-add'), findsNothing);
      expect(_key('package-hidden-p3'), findsOneWidget);
      expect(_sortOrder(tester), ['p1', 'p2', 'p3']);
    });

    testWidgets('"Lên" and "Xuống" are off at the ends', (tester) async {
      final w = await _world();
      await _open(tester, w);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();
      bool enabled(String k) =>
          tester.widget<IconButton>(_key(k)).onPressed != null;
      expect(enabled('package-up-p1'), isFalse);
      expect(enabled('package-down-p1'), isTrue);
      expect(enabled('package-up-p2'), isTrue);
      expect(enabled('package-down-p2'), isTrue);
      expect(enabled('package-up-p3'), isTrue);
      expect(enabled('package-down-p3'), isFalse);
    });

    testWidgets('"Xuống" and "Lên" move a card; "Xong" writes one batch', (
      tester,
    ) async {
      final w = await _world();
      await _open(tester, w);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();

      await tester.tap(_key('package-down-p1'));
      await tester.pumpAndSettle();
      expect(_sortOrder(tester), ['p2', 'p1', 'p3']);
      await tester.tap(_key('package-down-p1'));
      await tester.pumpAndSettle();
      expect(_sortOrder(tester), ['p2', 'p3', 'p1']);
      await tester.tap(_key('package-up-p3'));
      await tester.pumpAndSettle();
      expect(_sortOrder(tester), ['p3', 'p2', 'p1']);
      expect(w.packages.writes, 0, reason: 'nothing is written before Xong');

      await tester.tap(_key('packages-sort-done'));
      await tester.pumpAndSettle();
      expect(w.packages.writes, 1, reason: 'one batch');
      expect(_ids(w), ['p3', 'p2', 'p1']);
      expect([for (final p in w.packages.stored(w.w.uid)) p.order], [0, 1, 2]);
      // Back to the normal list, in the new order.
      expect(find.text('Gói dịch vụ'), findsOneWidget);
      expect(_key('package-handle-p1'), findsNothing);
      expect(
        tester.getTopLeft(_key('package-p3')).dy,
        lessThan(tester.getTopLeft(_key('package-p1')).dy),
      );
    });

    testWidgets('the card moved last has the accent border', (tester) async {
      final w = await _world();
      await _open(tester, w);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();
      BoxDecoration decorationOf(String id) {
        final box = find.ancestor(
          of: _key('package-handle-$id'),
          matching: find.byType(DecoratedBox),
        );
        return tester
            .widgetList<DecoratedBox>(box)
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.border != null);
      }

      expect(decorationOf('p2').border!.top.width, 1);
      await tester.tap(_key('package-down-p2'));
      await tester.pumpAndSettle();
      expect(decorationOf('p2').border!.top.width, 2);
      expect(decorationOf('p1').border!.top.width, 1);
    });

    testWidgets('dragging the handle reorders like the buttons', (
      tester,
    ) async {
      final w = await _world();
      await _open(tester, w);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();
      await _dragDown(tester, _key('package-handle-p1'), 70);
      expect(_sortOrder(tester), ['p2', 'p1', 'p3']);
      await tester.tap(_key('packages-sort-done'));
      await tester.pumpAndSettle();
      expect(_ids(w), ['p2', 'p1', 'p3']);
    });

    testWidgets('"Xong" with the order unchanged writes nothing', (
      tester,
    ) async {
      final w = await _world();
      await _open(tester, w);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();
      await tester.tap(_key('package-down-p1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('package-up-p1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('packages-sort-done'));
      await tester.pumpAndSettle();
      expect(w.packages.writes, 0);
      expect(find.text('Gói dịch vụ'), findsOneWidget);
    });

    testWidgets('a failed write says so and keeps the order and the mode', (
      tester,
    ) async {
      final w = await _world();
      await _open(tester, w);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();
      await tester.tap(_key('package-down-p1'));
      await tester.pumpAndSettle();
      w.packages.failWrites = true;
      await tester.tap(_key('packages-sort-done'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa lưu được, thử lại nhé'), findsOneWidget);
      expect(find.text('Sắp xếp gói'), findsOneWidget);
      expect(_sortOrder(tester), ['p2', 'p1', 'p3']);
      expect(_ids(w), ['p1', 'p2', 'p3']);

      // Trying again once it works.
      w.packages.failWrites = false;
      await tester.tap(_key('packages-sort-done'));
      await tester.pumpAndSettle();
      expect(_ids(w), ['p2', 'p1', 'p3']);
      expect(find.text('Gói dịch vụ'), findsOneWidget);
    });

    testWidgets('back leaves sort mode as "Xong" does', (tester) async {
      final w = await _world();
      await _open(tester, w);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();
      await tester.tap(_key('package-down-p1'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_ids(w), ['p2', 'p1', 'p3']);
      expect(find.text('Gói dịch vụ'), findsOneWidget);
    });
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = await _world();
      await tester.pumpWidget(w.app(brightness: b, textScale: 1.3));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.tap(_key('packages-sort'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
