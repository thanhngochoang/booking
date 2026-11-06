import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart' show AppButton, AppColors;
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';

import '../../support/packages_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<PackagesWorld> _world({
  List<ServicePackage> packages = const [],
  DateTime? today,
}) async {
  final world = PackagesWorld();
  if (today != null) {
    world.w.today = today;
  }
  await world.init(packages: packages);
  return world;
}

Future<void> _open(
  WidgetTester tester,
  PackagesWorld w,
  String location, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  double width = 390,
  double height = 2200,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    w.app(
      location: location,
      editor: true,
      brightness: brightness,
      textScale: textScale,
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 100));
}

String _text(WidgetTester tester, String key) => tester
    .widget<TextField>(
      find.descendant(
        of: _key(key),
        matching: find.byType(TextField),
        matchRoot: true,
      ),
    )
    .controller!
    .text;

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(_key(key), text);
  await tester.pump();
}

Future<void> _fillBasics(
  WidgetTester tester, {
  String name = 'Cặp đôi nửa ngày',
  int minutes = 240,
}) async {
  await _type(tester, 'package-name', name);
  await tester.tap(_key('duration-$minutes'));
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(_key('package-save'));
  await tester.tap(_key('package-save'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

ServicePackage _stored(PackagesWorld w) => w.packages.stored(w.w.uid).single;

void main() {
  testWidgets('a new package opens "Thêm gói" with one price field', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    expect(find.text('Thêm gói'), findsOneWidget);
    expect(find.text('Giá ngày thường'), findsOneWidget);
    expect(_key('package-price'), findsOneWidget);
    // The old price table, special price and preview are gone.
    expect(find.text('Hai mức giá'), findsNothing);
    expect(find.text('Từng ngày'), findsNothing);
    expect(_key('price-weekday'), findsNothing);
    expect(_key('special-switch'), findsNothing);
    expect(_key('preview-note'), findsNothing);
    expect(find.text('Lưu gói'), findsOneWidget);
    expect(find.text('Ẩn gói'), findsNothing);
    expect(find.text('Booking đã đặt giữ giá cũ.'), findsOneWidget);
    expect(
      find.text('Cuối tuần, ngày lễ: đặt ở Giá theo ngày sau khi lưu'),
      findsOneWidget,
    );
    expect(_key('package-rules'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the price field groups digits as typed', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _type(tester, 'package-price', '1500000');
    expect(_text(tester, 'package-price'), '1.500.000');
  });

  testWidgets('saves one price with the details', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'package-price', '3200000');
    await _type(tester, 'package-edited', '80');
    await _type(tester, 'package-delivery', '5');
    await _save(tester);
    final p = _stored(w);
    expect(p.name, 'Cặp đôi nửa ngày');
    expect(p.priceVnd, 3200000);
    expect(p.durationMinutes, 240);
    expect(p.editedCount, 80);
    expect(p.deliveryDays, 5);
    expect(find.text('Đã thêm gói.'), findsOneWidget);
  });

  testWidgets('editing changes the price and keeps the place in the list', (
    tester,
  ) async {
    final w = await _world(packages: [portraitPackage]);
    await _open(tester, w, '/me/packages/p1');
    expect(_text(tester, 'package-price'), '1.500.000');
    await _type(tester, 'package-price', '1600000');
    await _save(tester);
    expect(_stored(w).priceVnd, 1600000);
    expect(_stored(w).order, 0);
    expect(find.text('Đã lưu gói.'), findsOneWidget);
  });

  testWidgets('an existing package shows its live series read-only', (
    tester,
  ) async {
    final w = await _world(packages: [portraitPackage]);
    w.rules.seed(weddingSeries());
    w.rules.seed(weekendSeries());
    w.rules.seed(tetSeries());
    // A series of another package and one that has ended do not show.
    w.rules.seed(weekendSeries(serviceId: 'p2'));
    await _open(tester, w, '/me/packages/p1');
    expect(_key('package-rules'), findsOneWidget);
    expect(find.text('Cuối tuần'), findsOneWidget);
    expect(find.text('Hằng tuần · T7, CN'), findsOneWidget);
    expect(find.text('1,8M'), findsOneWidget);
    expect(find.text('Mùa cưới'), findsOneWidget);
    expect(find.text('Hằng năm · 14/11 – 22/11'), findsOneWidget);
    expect(find.text('Tết'), findsOneWidget);
    expect(find.text('Hằng năm · 23 Chạp – 5 Giêng (âm lịch)'), findsOneWidget);
    expect(find.text('Giá theo ngày'), findsOneWidget);
    expect(
      find.text('Cuối tuần, ngày lễ: đặt ở Giá theo ngày sau khi lưu'),
      findsNothing,
    );
    // Read-only: a row has no chevron and does nothing.
    await tester.tap(find.text('Mùa cưới'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa gói'), findsOneWidget);
  });

  testWidgets('the series card links to S08.10 with this package', (
    tester,
  ) async {
    final w = await _world(packages: [portraitPackage, couplePackage]);
    w.rules.seed(weekendSeries(serviceId: 'p2'));
    await _open(tester, w, '/me/packages/p2');
    await tester.ensureVisible(_key('package-rules-link'));
    await tester.tap(_key('package-rules-link'));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/day-pricing?service=p2'), findsOneWidget);
  });

  testWidgets('a package without series says where to set them', (
    tester,
  ) async {
    final w = await _world(packages: [portraitPackage]);
    w.rules.seed(
      const PriceRule(
        id: 'ended',
        serviceId: 'p1',
        price: 2000000,
        repeat: PriceRepeat.none,
        from: '2026-01-01',
        to: '2026-01-02',
      ),
    );
    await _open(tester, w, '/me/packages/p1');
    expect(_key('package-rules'), findsNothing);
    expect(
      find.text('Cuối tuần, ngày lễ: đặt ở Giá theo ngày sau khi lưu'),
      findsOneWidget,
    );
  });

  testWidgets('from=setup has neither the series card nor the line', (
    tester,
  ) async {
    final w = await _world(packages: [portraitPackage]);
    w.rules.seed(weekendSeries());
    await _open(tester, w, '/me/packages/p1?from=setup');
    expect(_key('package-price'), findsOneWidget);
    expect(_key('package-rules'), findsNothing);
    expect(_key('package-no-rules'), findsNothing);
    expect(find.text('Booking đã đặt giữ giá cũ.'), findsOneWidget);
    await _open(tester, w, '/me/packages/new?from=setup');
    expect(_key('package-no-rules'), findsNothing);
  });

  testWidgets('errors: name length, price 0, price > 1e9', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _type(tester, 'package-name', 'A');
    await _type(tester, 'package-price', '0');
    await _save(tester);
    expect(find.text('Tên 2–60 ký tự'), findsOneWidget);
    expect(find.text('Giá phải lớn hơn 0'), findsOneWidget);
    expect(find.text('Chọn thời lượng'), findsOneWidget);
    expect(w.packages.writes, 0);

    await _type(tester, 'package-price', '1000000001');
    await _save(tester);
    expect(find.text('Giá tối đa 1.000.000.000₫'), findsOneWidget);

    await _type(tester, 'package-name', 'A' * 61);
    await _save(tester);
    expect(find.text('Tên 2–60 ký tự'), findsOneWidget);
    await _type(tester, 'package-name', 'AB');
    expect(
      find.text('Tên 2–60 ký tự'),
      findsNothing,
      reason: 'cleared on edit',
    );
  });

  testWidgets('a failed save keeps the form and says so', (tester) async {
    final w = await _world();
    w.packages.failWrites = true;
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'package-price', '1500000');
    await _save(tester);
    expect(find.text('Chưa lưu được gói, thử lại nhé'), findsOneWidget);
    expect(_text(tester, 'package-name'), 'Cặp đôi nửa ngày');
    expect(_text(tester, 'package-price'), '1.500.000');
  });

  testWidgets('"Ẩn gói" asks, hides and leaves; "Giữ lại" keeps', (
    tester,
  ) async {
    final w = await _world(packages: [portraitPackage]);
    await _open(tester, w, '/me/packages/p1');
    expect(find.text('Sửa gói'), findsOneWidget);
    await tester.tap(_key('package-hide'));
    await tester.pumpAndSettle();
    expect(find.text('Ẩn gói này?'), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(_stored(w).active, isTrue);

    await tester.tap(_key('package-hide'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ẩn gói'));
    await tester.pumpAndSettle();
    expect(_stored(w).active, isFalse);
  });

  group('leaving with changes', () {
    Future<PackagesWorld> openFromList(
      WidgetTester tester, {
      List<ServicePackage> packages = const [portraitPackage],
    }) async {
      final w = await _world(packages: packages);
      await _open(tester, w, '/me/packages');
      await tester.tap(_key('package-p1'));
      await tester.pumpAndSettle();
      return w;
    }

    testWidgets('without a change back leaves at once', (tester) async {
      await openFromList(tester);
      expect(find.text('Sửa gói'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsNothing);
      expect(find.text('Gói dịch vụ'), findsOneWidget);
    });

    testWidgets('after a change the sheet asks; "Tiếp tục sửa" stays', (
      tester,
    ) async {
      final w = await openFromList(tester);
      await _type(tester, 'package-price', '1600000');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục sửa'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa gói'), findsOneWidget);
      expect(_text(tester, 'package-price'), '1.600.000');
      expect(_stored(w).priceVnd, 1500000);
    });

    testWidgets('"Bỏ" is a red button and leaves without saving', (
      tester,
    ) async {
      final w = await openFromList(tester);
      await _type(tester, 'package-price', '1600000');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final red = tester.widget<FilledButton>(
        find.descendant(
          of: find.widgetWithText(AppButton, 'Bỏ'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(red.style?.backgroundColor?.resolve({}), AppColors.error);
      await tester.tap(find.widgetWithText(AppButton, 'Bỏ'));
      await tester.pumpAndSettle();
      expect(find.text('Gói dịch vụ'), findsOneWidget);
      expect(_stored(w).priceVnd, 1500000);
    });

    testWidgets('typing the old value back is no change', (tester) async {
      await openFromList(tester);
      await _type(tester, 'package-price', '1600000');
      await _type(tester, 'package-price', '1500000');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsNothing);
    });

    testWidgets('a new package asks once something is typed', (tester) async {
      final w = await _world();
      await _open(tester, w, '/me/packages');
      await tester.tap(_key('packages-add'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsNothing, reason: 'still empty');

      await tester.tap(_key('packages-add'));
      await tester.pumpAndSettle();
      await _type(tester, 'package-name', 'Gia đình');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsOneWidget);
    });

    testWidgets('saving leaves without asking', (tester) async {
      await openFromList(tester);
      await _type(tester, 'package-price', '1600000');
      await _save(tester);
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsNothing);
      expect(find.text('Gói dịch vụ'), findsOneWidget);
    });
  });

  testWidgets('a package that does not exist says so with a retry', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/nope');
    expect(find.text('Không tải được gói'), findsOneWidget);
    expect(_key('package-save'), findsNothing);
  });

  testWidgets('from=setup returns to /setup/2 after save', (tester) async {
    final w = await _world();
    await _open(tester, w, '/setup/2');
    await tester.tap(_key('setup-add-package'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm gói'), findsWidgets);
    expect(_key('package-save'), findsOneWidget);
    await _fillBasics(tester);
    await _type(tester, 'package-price', '1500000');
    await _save(tester);
    await tester.pumpAndSettle();
    expect(_key('package-save'), findsNothing);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
    expect(find.text('1.500.000₫'), findsOneWidget);
  });

  testWidgets('from=setup opened directly goes to /setup/2 after save', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new?from=setup');
    await _fillBasics(tester);
    await _type(tester, 'package-price', '1500000');
    await _save(tester);
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
  });

  testWidgets('without from=setup a saved package returns to the list', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages');
    await tester.tap(_key('packages-add'));
    await tester.pumpAndSettle();
    await _fillBasics(tester);
    await _type(tester, 'package-price', '1500000');
    await _save(tester);
    await tester.pumpAndSettle();
    expect(find.text('Gói dịch vụ'), findsOneWidget);
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
  });

  testWidgets('the setup form is kept as a draft until saved', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new?from=setup');
    await _fillBasics(tester, name: 'Gia đình', minutes: 180);
    await _type(tester, 'package-price', '2000000');
    final draft = SetupDraftStore(w.w.prefs).package(w.w.uid)!;
    expect(draft.name, 'Gia đình');
    expect(draft.price, '2.000.000');
    expect(draft.durationMinutes, 180);

    await tester.pumpWidget(const SizedBox());
    await _open(tester, w, '/me/packages/new?from=setup');
    expect(_text(tester, 'package-name'), 'Gia đình');
    expect(_text(tester, 'package-price'), '2.000.000');

    await _save(tester);
    expect(SetupDraftStore(w.w.prefs).package(w.w.uid), isNull);
  });

  testWidgets('a plain new package keeps no draft', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _type(tester, 'package-name', 'Gia đình');
    expect(SetupDraftStore(w.w.prefs).package(w.w.uid), isNull);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      final w = await _world(packages: [portraitPackage]);
      w.rules.seed(weekendSeries());
      w.rules.seed(weddingSeries());
      w.rules.seed(tetSeries());
      await _open(
        tester,
        w,
        '/me/packages/p1',
        brightness: b,
        textScale: 1.3,
        width: 320,
        height: 640,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
