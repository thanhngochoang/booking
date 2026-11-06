import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';

import '../../support/photographer_world.dart';

final _routes = <RouteBase>[
  GoRoute(path: '/setup/1', builder: (_, _) => const Text('step 1')),
  GoRoute(path: '/setup/2', builder: (_, _) => const SetupPackagesScreen()),
  GoRoute(path: '/me/addons', builder: (_, _) => const Text('stub addons')),
  GoRoute(path: '/me/packages/new', builder: (_, s) => Text('stub ${s.uri}')),
  GoRoute(path: '/me/packages/:id', builder: (_, s) => Text('stub ${s.uri}')),
];

const _portrait = ServicePackage(
  id: 'a',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  editedCount: 40,
  deliveryDays: 3,
  dayPrices: {
    Weekday.mon: 1500000,
    Weekday.tue: 1500000,
    Weekday.wed: 1500000,
    Weekday.thu: 1500000,
    Weekday.fri: 1500000,
    Weekday.sat: 1800000,
    Weekday.sun: 1800000,
  },
);

const _couple = ServicePackage(
  id: 'b',
  name: 'Cặp đôi nửa ngày',
  priceVnd: 3200000,
  durationMinutes: 240,
  editedCount: 80,
  deliveryDays: 5,
);

const _hidden = ServicePackage(
  id: 'c',
  name: 'Sản phẩm 10 món',
  priceVnd: 900000,
  durationMinutes: 120,
  active: false,
);

Future<PhotographerWorld> _world({List<ServicePackage> seed = const []}) async {
  final w = PhotographerWorld();
  await w.init();
  for (final p in seed) {
    w.packages.seed(w.uid, p);
  }
  return w;
}

Finder _key(String k) => find.byKey(Key(k));

bool _enabled(WidgetTester tester, String key) =>
    tester
        .widget<FilledButton>(
          find.descendant(of: _key(key), matching: find.byType(FilledButton)),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('without a package, "Tiếp tục" waits and says why', (
    tester,
  ) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(
      find.text('Chưa có gói nào. Thêm gói đầu tiên bên dưới.'),
      findsOneWidget,
    );
    expect(find.text('Thêm ít nhất một gói để tiếp tục.'), findsOneWidget);
    expect(_enabled(tester, 'setup-next'), isFalse);
    expect(_key('setup-add-package'), findsOneWidget);
    expect(find.text('Thêm gói'), findsOneWidget);
  });

  testWidgets('has no inline form any more', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(_key('package-name'), findsNothing);
    expect(_key('package-price'), findsNothing);
    expect(_key('package-submit'), findsNothing);
  });

  testWidgets('lists the active packages with their price line and meta', (
    tester,
  ) async {
    final w = await _world(seed: const [_portrait, _couple, _hidden]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('Chân dung 2 giờ'), findsOneWidget);
    expect(find.text('2 giờ · 40 ảnh · giao 3 ngày'), findsOneWidget);
    expect(find.text('T2–T6 1,5M · T7–CN 1,8M'), findsOneWidget);
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
    expect(find.text('3.200.000₫'), findsOneWidget);
    expect(find.text('Sản phẩm 10 món'), findsNothing, reason: 'hidden');
    expect(
      find.text(
        'Đặt giá cuối tuần, giá từng ngày hoặc giá ngày lễ trong từng gói.',
      ),
      findsOneWidget,
    );
    expect(_enabled(tester, 'setup-next'), isTrue);
  });

  testWidgets('"Thêm gói" opens S08.09 for a new package from setup', (
    tester,
  ) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_key('setup-add-package'));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/packages/new?from=setup'), findsOneWidget);
  });

  testWidgets('tapping a package opens S08.09 to edit it from setup', (
    tester,
  ) async {
    final w = await _world(seed: const [_portrait]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_key('package-a'));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/packages/a?from=setup'), findsOneWidget);
  });

  testWidgets('a package added meanwhile shows at once and unlocks "Tiếp '
      'tục"', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'setup-next'), isFalse);
    await w.packages.add(w.uid, _couple.input);
    await tester.pumpAndSettle();
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
    expect(_enabled(tester, 'setup-next'), isTrue);
    expect(find.text('Thêm ít nhất một gói để tiếp tục.'), findsNothing);
  });

  testWidgets('hiding the only package locks "Tiếp tục" again', (tester) async {
    final w = await _world(seed: const [_couple]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await w.packages.hide(w.uid, 'b');
    await tester.pumpAndSettle();
    expect(find.text('Cặp đôi nửa ngày'), findsNothing);
    expect(_enabled(tester, 'setup-next'), isFalse);
  });

  testWidgets(
    '"Tiếp tục" remembers step 3 and opens it; "Quay lại" goes to step 1',
    (tester) async {
      final w = await _world(seed: const [_portrait]);
      await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
      await tester.pumpAndSettle();
      await tester.tap(_key('setup-next'));
      await tester.pumpAndSettle();
      expect(find.text('stub /setup/3'), findsOneWidget);
      expect(SetupDraftStore(w.prefs).step(w.uid), 3);

      await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
      await tester.pumpAndSettle();
      await tester.tap(_key('setup-back'));
      await tester.pumpAndSettle();
      expect(find.text('step 1'), findsOneWidget);
    },
  );

  testWidgets('a double tap on "Tiếp tục" opens step 3 once', (tester) async {
    final w = await _world(seed: const [_portrait]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    // Two taps before a frame: the second lands while the first is saving.
    await tester.tap(_key('setup-next'));
    await tester.tap(_key('setup-next'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('stub /setup/3'), findsOneWidget);

    w.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('stub /setup/3'), findsNothing);
    expect(find.text('2 / 4'), findsOneWidget, reason: 'one pop, back on 2');
    expect(_enabled(tester, 'setup-next'), isTrue);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      usePhone(tester, width: 320, height: 640);
      final w = await _world(
        seed: const [
          _portrait,
          ServicePackage(
            id: 'x',
            name: 'Cưới cả ngày, hai thợ, album in cao cấp',
            priceVnd: 18000000,
            durationMinutes: 480,
            editedCount: 300,
            deliveryDays: 30,
            specialPrice: 25000000,
          ),
        ],
      );
      await tester.pumpWidget(
        w.app(
          location: '/setup/2',
          routes: _routes,
          brightness: b,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('"Thêm dịch vụ đi kèm" shows once a package exists and opens '
      '/me/addons', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(_key('setup-addons'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    final w2 = await _world(seed: const [_portrait]);
    await tester.pumpWidget(w2.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('Thêm dịch vụ đi kèm'), findsOneWidget);
    await tester.ensureVisible(_key('setup-addons'));
    await tester.tap(_key('setup-addons'));
    await tester.pumpAndSettle();
    expect(find.text('stub addons'), findsOneWidget);
  });
}
