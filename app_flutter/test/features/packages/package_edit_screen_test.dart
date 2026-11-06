import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/special_days.dart';
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
  world.seedHolidays2026();
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
  testWidgets('a new package opens "Thêm gói" with two levels', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    expect(find.text('Thêm gói'), findsOneWidget);
    expect(find.text('Hai mức giá'), findsOneWidget);
    expect(find.text('Từng ngày'), findsOneWidget);
    expect(find.text('Ngày thường · T2–T6'), findsOneWidget);
    expect(find.text('Cuối tuần · T7–CN'), findsOneWidget);
    expect(find.text('Lưu gói'), findsOneWidget);
    expect(find.text('Ẩn gói'), findsNothing);
    expect(_key('price-special'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing the weekday price first fills the weekend', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _type(tester, 'price-weekday', '1500000');
    expect(_text(tester, 'price-weekday'), '1.500.000');
    expect(_text(tester, 'price-weekend'), '1.500.000');

    await _type(tester, 'price-weekend', '1800000');
    await _type(tester, 'price-weekday', '1600000');
    expect(
      _text(tester, 'price-weekend'),
      '1.800.000',
      reason: 'a typed weekend price stays',
    );
  });

  testWidgets('two levels → per day fills 7 values', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _type(tester, 'price-weekday', '1500000');
    await _type(tester, 'price-weekend', '1800000');
    await tester.tap(find.text('Từng ngày'));
    await tester.pump();
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) {
      expect(_text(tester, 'price-day-$d'), '1.500.000', reason: d);
    }
    for (final d in ['sat', 'sun']) {
      expect(_text(tester, 'price-day-$d'), '1.800.000', reason: d);
    }
    expect(find.text('Thứ 2'), findsOneWidget);
    expect(find.text('Chủ nhật'), findsOneWidget);
    expect(find.text('cuối tuần'), findsNWidgets(2));
  });

  testWidgets('per day with Friday 3.5M → two levels asks and uses '
      'Monday/Saturday', (tester) async {
    final w = await _world(packages: [perDayPackage]);
    await _open(tester, w, '/me/packages/p2');
    expect(_text(tester, 'price-day-fri'), '3.500.000');

    await tester.tap(find.text('Hai mức giá'));
    await tester.pumpAndSettle();
    expect(
      find.text('Dùng giá Thứ 2 cho ngày thường và giá Thứ 7 cho cuối tuần?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Giữ từng ngày'));
    await tester.pumpAndSettle();
    expect(_key('price-day-fri'), findsOneWidget, reason: 'still per day');
    expect(_text(tester, 'price-day-fri'), '3.500.000');

    await tester.tap(find.text('Hai mức giá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dùng hai mức'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'price-weekday'), '3.200.000');
    expect(_text(tester, 'price-weekend'), '4.000.000');
  });

  testWidgets('per day that is already two levels switches back without '
      'asking', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _type(tester, 'price-weekday', '1500000');
    await _type(tester, 'price-weekend', '1800000');
    await tester.tap(find.text('Từng ngày'));
    await tester.pump();
    await tester.tap(find.text('Hai mức giá'));
    await tester.pumpAndSettle();
    expect(find.text('Dùng hai mức'), findsNothing);
    expect(_text(tester, 'price-weekday'), '1.500.000');
    expect(_text(tester, 'price-weekend'), '1.800.000');
  });

  testWidgets('saves two levels: price is Monday, dayPrices has 7, mode kept', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'price-weekday', '3200000');
    await _type(tester, 'price-weekend', '4000000');
    await _type(tester, 'package-edited', '80');
    await _type(tester, 'package-delivery', '5');
    await _save(tester);
    final p = _stored(w);
    expect(p.name, 'Cặp đôi nửa ngày');
    expect(p.priceVnd, 3200000);
    expect(p.durationMinutes, 240);
    expect(p.editedCount, 80);
    expect(p.deliveryDays, 5);
    expect(p.priceMode, PriceMode.twoLevels);
    expect(p.specialPrice, isNull);
    expect(p.dayPrices, {
      for (final d in Weekday.values) d: d.isWeekend ? 4000000 : 3200000,
    });
    expect(find.text('Đã thêm gói.'), findsOneWidget);
  });

  testWidgets('per day saves 7 prices and reopens per day', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'price-weekday', '3200000');
    await tester.tap(find.text('Từng ngày'));
    await tester.pump();
    await _type(tester, 'price-day-fri', '3500000');
    await _save(tester);
    final p = _stored(w);
    expect(p.priceMode, PriceMode.perDay);
    expect(p.priceVnd, 3200000);
    expect(p.dayPrices![Weekday.fri], 3500000);
    expect(p.dayPrices![Weekday.sat], 3200000);

    await tester.pumpWidget(const SizedBox());
    await _open(tester, w, '/me/packages/${p.id}');
    expect(_key('price-day-fri'), findsOneWidget);
    expect(_text(tester, 'price-day-fri'), '3.500.000');
  });

  testWidgets('all seven equal saves without dayPrices', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'price-weekday', '1500000');
    await _type(tester, 'price-weekend', '1500000');
    await _save(tester);
    final p = _stored(w);
    expect(p.dayPrices, isNull);
    expect(p.priceVnd, 1500000);
    expect(p.priceMode, PriceMode.twoLevels);
  });

  testWidgets('per day with seven equal prices also saves a single price', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'price-weekday', '1500000');
    await tester.tap(find.text('Từng ngày'));
    await tester.pump();
    await _type(tester, 'price-day-sat', '1500000');
    await _type(tester, 'price-day-sun', '1500000');
    await _save(tester);
    final p = _stored(w);
    expect(p.dayPrices, isNull);
    expect(p.priceVnd, 1500000);
  });

  testWidgets('the special switch off saves without specialPrice', (
    tester,
  ) async {
    final w = await _world(packages: [twoLevelPackage]);
    await _open(tester, w, '/me/packages/p1');
    expect(tester.widget<Switch>(_key('special-switch')).value, isTrue);
    expect(_text(tester, 'price-special'), '2.200.000');

    await tester.ensureVisible(_key('special-switch'));
    await tester.tap(_key('special-switch'));
    await tester.pump();
    expect(_key('price-special'), findsNothing);
    expect(find.text('Đang tắt · ngày lễ tính như thứ đó'), findsOneWidget);
    await _save(tester);
    expect(_stored(w).specialPrice, isNull);
    expect(_stored(w).order, 0, reason: 'its place in the list is kept');
  });

  testWidgets('the special switch on needs a price and saves it', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'price-weekday', '1500000');
    await tester.ensureVisible(_key('special-switch'));
    await tester.tap(_key('special-switch'));
    await tester.pump();
    await _save(tester);
    expect(find.text('Giá phải lớn hơn 0'), findsOneWidget);
    expect(w.packages.writes, 0);

    await _type(tester, 'price-special', '2200000');
    await _save(tester);
    expect(_stored(w).specialPrice, 2200000);
  });

  testWidgets('the special line counts holidays and own ranges and "Xem" '
      'opens S08.10', (tester) async {
    final w = await _world(packages: [twoLevelPackage]);
    w.seedRange('r1', 'Mùa cưới', '2026-11-14', '2026-11-22');
    w.seedRange('r2', 'Noel', '2026-12-24', '2026-12-25');
    await _open(tester, w, '/me/packages/p1');
    expect(
      find.text('Áp cho 8 ngày lễ chung, 2 khoảng ngày của bạn · '),
      findsOneWidget,
    );
    await tester.ensureVisible(_key('special-see'));
    await tester.tap(_key('special-see'));
    await tester.pumpAndSettle();
    expect(find.text('Ngày riêng của bạn'), findsOneWidget);
  });

  testWidgets('preview marks 14/11 weekend 1,8M and 17/11 Lễ 2,2M', (
    tester,
  ) async {
    final w = await _world(
      packages: [twoLevelPackage],
      today: DateTime.utc(2026, 11, 12),
    );
    w.holidays.seed(2026, const [
      Holiday(day: '2026-11-17', name: 'Ngày hội thử'),
    ]);
    await _open(tester, w, '/me/packages/p1');
    expect(find.text('T5 12 · 1,5M'), findsOneWidget);
    expect(find.text('T7 14 · 1,8M'), findsOneWidget);
    expect(find.text('CN 15 · 1,8M'), findsOneWidget);
    expect(find.text('Lễ T3 17 · 2,2M'), findsOneWidget);
    expect(find.text('T4 18 · 1,5M'), findsOneWidget);
    expect(_key('preview-2026-11-17'), findsOneWidget);
    expect(
      find.text(
        'Khách đặt T3 17/11 trả 2.200.000₫ (chưa gồm dịch vụ đi kèm). '
        'Booking đã đặt giữ giá cũ.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('preview follows the typed prices and the user\'s own ranges', (
    tester,
  ) async {
    final w = await _world(today: DateTime.utc(2026, 11, 12));
    w.seedRange('r1', 'Mùa cưới', '2026-11-14', '2026-11-22');
    await _open(tester, w, '/me/packages/new');
    expect(_key('preview-note'), findsNothing, reason: 'no prices yet');
    await _type(tester, 'price-weekday', '1500000');
    await _type(tester, 'price-weekend', '1800000');
    expect(find.text('T7 14 · 1,8M'), findsOneWidget);
    await tester.ensureVisible(_key('special-switch'));
    await tester.tap(_key('special-switch'));
    await tester.pump();
    await _type(tester, 'price-special', '2500000');
    expect(find.text('Lễ T7 14 · 2,5M'), findsOneWidget);
    expect(find.text('T6 13 · 1,5M'), findsOneWidget);
  });

  testWidgets('errors: name length, price 0, price > 1e9', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _type(tester, 'package-name', 'A');
    await _type(tester, 'price-weekday', '0');
    await _type(tester, 'price-weekend', '1000000001');
    await _save(tester);
    expect(find.text('Tên 2–60 ký tự'), findsOneWidget);
    expect(find.text('Giá phải lớn hơn 0'), findsOneWidget);
    expect(find.text('Giá tối đa 1.000.000.000₫'), findsOneWidget);
    expect(find.text('Chọn thời lượng'), findsOneWidget);
    expect(w.packages.writes, 0);

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

  testWidgets('a per day price of 0 shows under that day', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'price-weekday', '1500000');
    await tester.tap(find.text('Từng ngày'));
    await tester.pump();
    await _type(tester, 'price-day-wed', '0');
    await _save(tester);
    expect(find.text('Giá phải lớn hơn 0'), findsOneWidget);
    expect(w.packages.writes, 0);
  });

  testWidgets('a failed save keeps the form and says so', (tester) async {
    final w = await _world();
    w.packages.failWrites = true;
    await _open(tester, w, '/me/packages/new');
    await _fillBasics(tester);
    await _type(tester, 'price-weekday', '1500000');
    await _save(tester);
    expect(find.text('Chưa lưu được gói, thử lại nhé'), findsOneWidget);
    expect(_text(tester, 'package-name'), 'Cặp đôi nửa ngày');
    expect(_text(tester, 'price-weekday'), '1.500.000');
  });

  testWidgets('"Ẩn gói" asks, hides and leaves; "Giữ lại" keeps', (
    tester,
  ) async {
    final w = await _world(packages: [twoLevelPackage]);
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
    await _type(tester, 'price-weekday', '1500000');
    await _type(tester, 'price-weekend', '1800000');
    await _save(tester);
    await tester.pumpAndSettle();
    expect(_key('package-save'), findsNothing);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
    expect(find.text('T2–T6 1,5M · T7–CN 1,8M'), findsOneWidget);
  });

  testWidgets('from=setup opened directly goes to /setup/2 after save', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new?from=setup');
    await _fillBasics(tester);
    await _type(tester, 'price-weekday', '1500000');
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
    await _type(tester, 'price-weekday', '1500000');
    await _save(tester);
    await tester.pumpAndSettle();
    expect(find.text('Gói dịch vụ'), findsOneWidget);
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
  });

  testWidgets('the setup form is kept as a draft until saved', (tester) async {
    final w = await _world();
    await _open(tester, w, '/me/packages/new?from=setup');
    await _fillBasics(tester, name: 'Gia đình', minutes: 180);
    await _type(tester, 'price-weekday', '2000000');
    final draft = SetupDraftStore(w.w.prefs).package(w.w.uid)!;
    expect(draft.name, 'Gia đình');
    expect(draft.price, '2.000.000');
    expect(draft.durationMinutes, 180);

    await tester.pumpWidget(const SizedBox());
    await _open(tester, w, '/me/packages/new?from=setup');
    expect(_text(tester, 'package-name'), 'Gia đình');
    expect(_text(tester, 'price-weekday'), '2.000.000');
    expect(_text(tester, 'price-weekend'), '2.000.000');

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
    for (final perDay in [false, true]) {
      testWidgets(
        'fits 320dp at 1.3x text (${b.name}, ${perDay ? 'per day' : 'two'})',
        (tester) async {
          final w = await _world(
            packages: [perDay ? perDayPackage : twoLevelPackage],
          );
          await _open(
            tester,
            w,
            perDay ? '/me/packages/p2' : '/me/packages/p1',
            brightness: b,
            textScale: 1.3,
            width: 320,
            height: 640,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
