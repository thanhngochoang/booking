import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart' show AppButton, AppColors;
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/special_days.dart';

import '../../support/packages_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<PackagesWorld> _world({
  List<ServicePackage> packages = const [twoLevelPackage, perDayPackage],
}) async {
  final world = PackagesWorld();
  await world.init(packages: packages);
  world.seedHolidays2026();
  return world;
}

Future<void> _open(WidgetTester tester, PackagesWorld w) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w.app(location: '/me/special-days'));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Taps a day of the sheet's calendar: its number in the visible month. The
/// grid also shows the neighbouring months' days (22 and later before the
/// month, up to 13 after it).
Future<void> _tapDay(WidgetTester tester, int day) async {
  final cells = find.descendant(
    of: _key('special-day-calendar'),
    matching: find.text('$day'),
  );
  await tester.tap(day >= 22 ? cells.last : cells.first);
  await tester.pump();
}

Future<void> _month(WidgetTester tester, String tooltip, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pump();
  }
}

Future<void> _nextMonth(WidgetTester tester, int times) =>
    _month(tester, 'Tháng sau', times);

void main() {
  testWidgets('shows the year\'s holidays and the user\'s ranges', (
    tester,
  ) async {
    final w = await _world();
    w.seedRange('r1', 'Mùa cưới tháng 11', '2026-11-14', '2026-11-22');
    w.seedRange('r2', 'Noel', '2026-12-24', '2026-12-25');
    w.seedRange('old', 'Mùa hoa cũ', '2026-03-01', '2026-03-05');
    await _open(tester, w);

    expect(find.text('Ngày đặc biệt'), findsOneWidget);
    expect(find.text('Ngày lễ chung'), findsOneWidget);
    expect(find.text('Tết Nguyên đán'), findsOneWidget);
    expect(find.text('T2 16/02 – CN 22/02'), findsOneWidget);
    expect(find.text('Giỗ Tổ Hùng Vương'), findsOneWidget);
    expect(find.text('CN 26/04'), findsOneWidget);
    expect(find.text('Ngày riêng của bạn'), findsOneWidget);
    expect(find.text('Mùa cưới tháng 11'), findsOneWidget);
    expect(find.text('T7 14/11 – CN 22/11 · 9 ngày'), findsOneWidget);
    expect(find.text('Noel'), findsOneWidget);
    expect(find.text('T5 24/12 – T6 25/12 · 2 ngày'), findsOneWidget);
    expect(find.text('Mùa hoa cũ'), findsNothing, reason: 'ended ranges hide');
    expect(_key('special-days-note'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Thêm khoảng ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the year chips switch the holiday list', (tester) async {
    final w = await _world();
    w.holidays.seed(2027, const [
      Holiday(day: '2027-01-01', name: 'Tết dương'),
    ]);
    await _open(tester, w);
    expect(find.text('Tết Nguyên đán'), findsOneWidget);
    await tester.tap(_key('special-year-2027'));
    await tester.pumpAndSettle();
    expect(find.text('Tết dương'), findsOneWidget);
    expect(find.text('Tết Nguyên đán'), findsNothing);
  });

  testWidgets('a year without holidays says so, no ranges says so', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('special-year-2027'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch ngày lễ năm 2027'), findsOneWidget);
    expect(
      find.text(
        'Chưa có ngày riêng · Thêm mùa cưới, mùa hoa hay ngày bạn muốn giá '
        'cao hơn',
      ),
      findsOneWidget,
    );
  });

  testWidgets('adding a range saves it', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('special-days-add'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm khoảng ngày'), findsNWidgets(2));
    expect(_key('special-day-delete'), findsNothing);
    expect(
      tester.widget<AppButton>(_key('special-day-save')).onPressed,
      isNull,
    );

    await tester.enterText(_key('special-day-name'), 'Mùa cưới');
    await _tapDay(tester, 14);
    await _tapDay(tester, 22);
    expect(
      find.text('9 ngày · 1 gói có giá ngày đặc biệt sẽ dùng giá đó'),
      findsOneWidget,
    );
    await tester.tap(_key('special-day-save'));
    await tester.pumpAndSettle();

    expect(w.specialDays.stored(w.w.uid).map((r) => (r.name, r.from, r.to)), [
      ('Mùa cưới', '2026-10-14', '2026-10-22'),
    ]);
    expect(find.text('Đã lưu khoảng ngày'), findsOneWidget);
    expect(find.text('Mùa cưới'), findsOneWidget);
  });

  testWidgets('without special prices the sheet points to the packages', (
    tester,
  ) async {
    final w = await _world(packages: const [perDayPackage]);
    await _open(tester, w);
    await tester.tap(_key('special-days-add'));
    await tester.pumpAndSettle();
    await _tapDay(tester, 14);
    await _tapDay(tester, 15);
    expect(
      find.text(
        '2 ngày · Chưa gói nào có giá ngày đặc biệt · Thêm ở Gói dịch vụ',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the sheet rejects a 61-day range and a range beyond 365 days', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('special-days-add'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('special-day-name'), 'Mùa dài');

    // 2 Oct to 1 Dec 2026 is 61 days.
    await _tapDay(tester, 2);
    await _nextMonth(tester, 2);
    await _tapDay(tester, 1);
    expect(find.text('Khoảng tối đa 60 ngày'), findsOneWidget);
    expect(
      tester.widget<AppButton>(_key('special-day-save')).onPressed,
      isNull,
    );

    // 60 days is fine: start again on 2 Oct and end on 30 Nov.
    await _month(tester, 'Tháng trước', 2);
    await _tapDay(tester, 2);
    await _nextMonth(tester, 1);
    await _tapDay(tester, 30);
    expect(find.text('Khoảng tối đa 60 ngày'), findsNothing);
    expect(
      tester.widget<AppButton>(_key('special-day-save')).onPressed,
      isNotNull,
    );

    // A day 366 days out (2 Oct 2027) is too far: a new start there.
    await _nextMonth(tester, 11);
    await _tapDay(tester, 2);
    expect(find.text('Chỉ chọn trong 365 ngày tới'), findsOneWidget);
    expect(
      tester.widget<AppButton>(_key('special-day-save')).onPressed,
      isNull,
    );
    expect(w.specialDays.stored(w.w.uid), isEmpty);
  });

  testWidgets('a name of one character shows the name error', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('special-days-add'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('special-day-name'), 'a');
    await tester.pump();
    expect(find.text('Tên 2–40 ký tự'), findsOneWidget);
    expect(
      tester.widget<AppButton>(_key('special-day-save')).onPressed,
      isNull,
    );
  });

  testWidgets('the 21st range is refused', (tester) async {
    final w = await _world();
    for (var i = 0; i < 20; i++) {
      final day = (i + 1).toString().padLeft(2, '0');
      w.seedRange('r$i', 'Khoảng $i', '2026-11-$day', '2026-11-30');
    }
    await _open(tester, w);
    await tester.tap(_key('special-days-add'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã có 20 khoảng ngày'), findsOneWidget);
    expect(
      tester.widget<AppButton>(_key('special-day-save')).onPressed,
      isNull,
    );
  });

  testWidgets('editing a range keeps its id and renames it', (tester) async {
    final w = await _world();
    w.seedRange('r1', 'Mùa cưới', '2026-11-14', '2026-11-22');
    await _open(tester, w);
    await tester.tap(_key('special-range-r1'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa khoảng ngày'), findsOneWidget);
    expect(_key('special-day-delete'), findsOneWidget);
    expect(find.text('T7 14/11'), findsOneWidget);
    expect(find.text('CN 22/11'), findsOneWidget);
    await tester.enterText(_key('special-day-name'), 'Mùa cưới lớn');
    await tester.tap(_key('special-day-save'));
    await tester.pumpAndSettle();
    expect(w.specialDays.stored(w.w.uid).single.id, 'r1');
    expect(w.specialDays.stored(w.w.uid).single.name, 'Mùa cưới lớn');
  });

  testWidgets('delete asks with a red button', (tester) async {
    final w = await _world();
    w.seedRange('r1', 'Mùa cưới', '2026-11-14', '2026-11-22');
    await _open(tester, w);
    await tester.tap(_key('special-range-r1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('special-day-delete'));
    await tester.pumpAndSettle();
    expect(find.text('Booking đã đặt giữ giá cũ.'), findsOneWidget);
    expect(w.specialDays.stored(w.w.uid), hasLength(1));

    final red = tester.widget<FilledButton>(
      find.descendant(
        of: find.widgetWithText(AppButton, 'Xoá'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(red.style?.backgroundColor?.resolve({}), AppColors.error);

    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(w.specialDays.stored(w.w.uid), hasLength(1));

    await tester.tap(_key('special-day-delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Xoá'));
    await tester.pumpAndSettle();
    expect(w.specialDays.stored(w.w.uid), isEmpty);
    expect(find.text('Đã xoá khoảng ngày'), findsOneWidget);
  });

  testWidgets('a failed save keeps the sheet and says so', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await tester.tap(_key('special-days-add'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('special-day-name'), 'Mùa cưới');
    await _tapDay(tester, 14);
    w.specialDays.failWrites = true;
    await tester.tap(_key('special-day-save'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu được, thử lại nhé'), findsOneWidget);
    expect(_key('special-day-save'), findsOneWidget);
    expect(w.specialDays.stored(w.w.uid), isEmpty);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = await _world();
      w.seedRange('r1', 'Mùa cưới tháng 11', '2026-11-14', '2026-11-22');
      await tester.pumpWidget(
        w.app(location: '/me/special-days', brightness: b, textScale: 1.3),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.tap(_key('special-days-add'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
