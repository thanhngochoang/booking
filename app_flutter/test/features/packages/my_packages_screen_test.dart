import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart' show AppButton, AppColors;

import '../../support/packages_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<PackagesWorld> _world() async {
  final world = PackagesWorld();
  await world.init(packages: [twoLevelPackage, perDayPackage, hiddenPackage]);
  world.seedHolidays2026();
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

void main() {
  testWidgets('lists the packages with switches and the special-days row '
      'counts', (tester) async {
    final w = await _world();
    w.seedRange('r1', 'Mùa cưới', '2026-11-14', '2026-11-22');
    w.seedRange('r2', 'Noel', '2026-12-24', '2026-12-25');
    await _open(tester, w);

    expect(find.text('Gói dịch vụ'), findsOneWidget);
    expect(find.text('2 gói đang bật'), findsOneWidget);
    expect(find.text('Chân dung 2 giờ'), findsOneWidget);
    expect(find.text('2 giờ · 40 ảnh · giao 3 ngày'), findsOneWidget);
    expect(find.text('T2–T6 1,5M · T7–CN 1,8M · Lễ 2,2M'), findsOneWidget);
    expect(find.text('3,2M–4M · theo ngày'), findsOneWidget);
    expect(find.text('Đang ẩn · khách không thấy'), findsOneWidget);
    expect(tester.widget<Switch>(_key('package-switch-p1')).value, isTrue);
    expect(tester.widget<Switch>(_key('package-switch-p2')).value, isTrue);
    expect(tester.widget<Switch>(_key('package-switch-p3')).value, isFalse);
    expect(find.text('Ngày đặc biệt'), findsOneWidget);
    expect(
      find.text('8 ngày lễ chung · 2 khoảng ngày của bạn'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Thêm gói'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a switch shows and hides a package', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('package-switch-p3'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.w.uid).last.active, isTrue);
    expect(find.text('3 gói đang bật'), findsOneWidget);
    await tester.tap(_key('package-switch-p2'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.w.uid)[1].active, isFalse);
    expect(find.text('2 gói đang bật'), findsOneWidget);
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
    expect(find.text('0 gói đang bật'), findsOneWidget);
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

  testWidgets('reorder by drag calls reorder with the new ids', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await _dragDown(tester, _key('package-handle-p1'), 120);
    expect(
      [for (final p in w.packages.stored(w.w.uid)) p.id],
      ['p2', 'p1', 'p3'],
    );
    expect([for (final p in w.packages.stored(w.w.uid)) p.order], [0, 1, 2]);
    final top = tester.getTopLeft(_key('package-p2')).dy;
    expect(top, lessThan(tester.getTopLeft(_key('package-p1')).dy));
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

  testWidgets('without packages: the empty text and the add button', (
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
    expect(_key('packages-special-days'), findsOneWidget);
  });

  testWidgets('tapping a package, Thêm gói and Ngày đặc biệt navigate', (
    tester,
  ) async {
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
    w.router.pop();
    await tester.pumpAndSettle();
    await tester.tap(_key('packages-special-days'));
    await tester.pumpAndSettle();
    expect(_key('special-days-note'), findsOneWidget);
    expect(
      find.text(
        'Gói có giá ngày đặc biệt dùng giá đó cho các ngày này. '
        'Gói không có giá đặc biệt tính như ngày thường. '
        'Muốn nghỉ hẳn thì đánh dấu nghỉ trong Lịch.',
      ),
      findsOneWidget,
    );
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
    });
  }
}
