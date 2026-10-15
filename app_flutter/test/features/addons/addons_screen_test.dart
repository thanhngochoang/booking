import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart' show GlassCard;
import 'package:photobooking/features/addons/addons_controller.dart';
import 'package:photobooking/features/addons/addons_screen.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/photographer/service_package.dart';

import '../../support/addons_world.dart';
import '../../support/photographer_world.dart';

const _portrait = ServicePackage(
  id: 'p1',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
);
const _couple = ServicePackage(
  id: 'p2',
  name: 'Cặp đôi nửa ngày',
  priceVnd: 3200000,
  durationMinutes: 240,
);

Finder _key(String k) => find.byKey(Key(k));

Future<AddonsWorld> _world({
  void Function(AddonsWorld)? seed,
  List<ServicePackage> packages = const [_portrait, _couple],
}) async {
  final world = AddonsWorld();
  await world.init(packages: packages);
  seed?.call(world);
  return world;
}

void _seedFour(AddonsWorld w) {
  w.seed(
    'a-outfit',
    name: 'Thuê áo dài',
    kind: AddonKind.outfit,
    price: 250000,
    unit: AddonUnit.perItem,
    active: false,
  );
  w.seed('a-makeup', name: 'Trang điểm');
  w.seed('a-hair', name: 'Làm tóc', price: 300000, serviceIds: ['p1', 'p2']);
  w.seed(
    'a-retouch',
    name: 'Chỉnh thêm ảnh',
    kind: AddonKind.retouch,
    price: 20000,
    unit: AddonUnit.perItem,
    maxQty: 10,
  );
  w.seed(
    'a-car',
    name: 'Xe đón',
    kind: AddonKind.transport,
    price: 300000,
    unit: AddonUnit.perBooking,
    maxQty: 1,
  );
}

Future<void> _open(
  WidgetTester tester,
  AddonsWorld w, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(w.app(brightness: brightness, textScale: textScale));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'shows "4/10 dịch vụ đang bật" and groups by kind in kind order',
    (tester) async {
      usePhone(tester, height: 1400);
      final w = await _world(seed: _seedFour);
      await _open(tester, w);
      expect(find.text('4/10 dịch vụ đang bật'), findsOneWidget);
      final order = [
        for (final k in ['makeup', 'retouch', 'transport', 'outfit'])
          tester.getTopLeft(_key('addons-group-$k')).dy,
      ];
      expect(order, [...order]..sort());
      expect(_key('addons-group-other'), findsNothing);
    },
  );

  testWidgets('row shows price label and the package names it applies to', (
    tester,
  ) async {
    usePhone(tester, height: 1400);
    final w = await _world(seed: _seedFour);
    await _open(tester, w);
    expect(find.text('800.000₫ / người'), findsOneWidget);
    expect(find.text('300.000₫ · một lần'), findsOneWidget);
    expect(find.text('20.000₫ / ảnh'), findsOneWidget);
    expect(find.text('250.000₫ / bộ'), findsOneWidget);
    expect(
      find.text('Áp dụng: Chân dung 2 giờ, Cặp đôi nửa ngày'),
      findsOneWidget,
    );
    expect(find.text('Áp dụng: mọi gói'), findsWidgets);
  });

  testWidgets('switch off calls save with active false and the other fields '
      'unchanged', (tester) async {
    usePhone(tester, height: 1400);
    final w = await _world(seed: _seedFour);
    await _open(tester, w);
    await tester.tap(_key('addon-switch-a-hair'));
    await tester.pump(const Duration(milliseconds: 100));
    final save = w.addons.saves.single;
    expect(save.addonId, 'a-hair');
    expect(save.input.active, isFalse);
    expect(save.input.name, 'Làm tóc');
    expect(save.input.price, 300000);
    expect(save.input.unit, AddonUnit.perPerson);
    expect(save.input.maxQty, 4);
    expect(save.input.choosePackages, isTrue);
    expect(save.input.serviceIds, ['p1', 'p2']);
    expect(tester.widget<Switch>(_key('addon-switch-a-hair')).value, isFalse);
    expect(find.text('3/10 dịch vụ đang bật'), findsOneWidget);
  });

  testWidgets('after a successful switch-off the live list shows it off and '
      'the optimistic entry is cleared', (tester) async {
    usePhone(tester, height: 1400);
    final w = await _world(seed: _seedFour);
    await _open(tester, w);
    await tester.tap(_key('addon-switch-a-hair'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(w.addons.addons['a-hair']!.active, isFalse);
    expect(tester.widget<Switch>(_key('addon-switch-a-hair')).value, isFalse);
    expect(find.text('3/10 dịch vụ đang bật'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AddonsScreen)),
    );
    expect(container.read(addonsControllerProvider), isEmpty);
  });

  testWidgets('one card per kind holds its rows', (tester) async {
    usePhone(tester, height: 1400);
    final w = await _world(seed: _seedFour);
    await _open(tester, w);
    expect(find.byType(GlassCard), findsNWidgets(4));
    expect(
      find.descendant(
        of: find.byType(GlassCard).first,
        matching: find.byType(Switch),
      ),
      findsNWidgets(2),
      reason: 'Trang điểm and Làm tóc share the first card',
    );
  });

  testWidgets('switching on the 11th returns the switch to off and shows the '
      'limit SnackBar', (tester) async {
    usePhone(tester, height: 1400);
    final w = await _world(seed: _seedFour);
    await _open(tester, w);
    w.addons.nextErrorCode = 'addon_limit';
    await tester.tap(_key('addon-switch-a-outfit'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(w.addons.saves, isEmpty);
    expect(tester.widget<Switch>(_key('addon-switch-a-outfit')).value, isFalse);
    expect(
      find.text(
        'Bạn đã bật đủ 10 dịch vụ. Tắt bớt một dịch vụ để bật dịch vụ này.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tap row opens S08.07 in edit mode', (tester) async {
    usePhone(tester, height: 1400);
    final w = await _world(seed: _seedFour);
    await _open(tester, w);
    await tester.tap(_key('addon-a-makeup'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sửa dịch vụ đi kèm'), findsOneWidget);
    expect(find.text('Xoá dịch vụ'), findsOneWidget);
  });

  testWidgets('"Thêm dịch vụ" opens S08.07 empty', (tester) async {
    usePhone(tester, height: 1400);
    final w = await _world(seed: _seedFour);
    await _open(tester, w);
    await tester.tap(_key('addons-add'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Thêm dịch vụ đi kèm'), findsOneWidget);
    expect(find.text('Xoá dịch vụ'), findsNothing);
    expect(tester.widget<TextField>(_key('addon-name')).controller!.text, '');
  });

  testWidgets('empty state title and body', (tester) async {
    final w = await _world();
    await _open(tester, w);
    expect(find.text('Chưa có dịch vụ đi kèm'), findsOneWidget);
    expect(
      find.text(
        'Thêm trang điểm, chỉnh ảnh hay xe đưa đón để khách chọn khi đặt lịch.',
      ),
      findsOneWidget,
    );
    expect(find.text('Thêm dịch vụ'), findsOneWidget);
  });

  testWidgets('load error shows ErrorState with retry', (tester) async {
    final w = await _world();
    w.addons.failWatch = true;
    await _open(tester, w);
    expect(
      find.text('Không tải được dịch vụ đi kèm. Thử lại.'),
      findsOneWidget,
    );
    expect(_key('error-retry'), findsOneWidget);
    w.addons.failWatch = false;
    await tester.tap(_key('error-retry'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Chưa có dịch vụ đi kèm'), findsOneWidget);
  });

  testWidgets('320 dp width and text scale 1.3 have no overflow', (
    tester,
  ) async {
    usePhone(tester, width: 320, height: 1400);
    final w = await _world(
      seed: (w) {
        _seedFour(w);
        w.seed(
          'a-long',
          name: 'Xe đón trong nội thành và ngoại thành có tài xế riêng',
          kind: AddonKind.transport,
          unit: AddonUnit.perBooking,
          serviceIds: ['p1', 'p2'],
        );
      },
    );
    await _open(tester, w, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.tap(_key('addons-add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Theo số lượng'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tối đa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final b in Brightness.values) {
    testWidgets('renders in ${b.name} theme', (tester) async {
      usePhone(tester, height: 1400);
      final w = await _world(seed: _seedFour);
      await _open(tester, w, brightness: b);
      expect(find.text('4/10 dịch vụ đang bật'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('exactly one AppButton.primary', (tester) async {
    usePhone(tester, height: 1400);
    final w = await _world(seed: _seedFour);
    await _open(tester, w);
    expect(find.text('Thêm dịch vụ'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
