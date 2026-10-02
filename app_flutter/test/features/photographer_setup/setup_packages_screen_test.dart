import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';

import '../../support/photographer_world.dart';

final _routes = <RouteBase>[
  GoRoute(path: '/setup/1', builder: (_, _) => const Text('step 1')),
  GoRoute(path: '/setup/2', builder: (_, _) => const SetupPackagesScreen()),
];

const _portrait = ServicePackage(
  id: 'a',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  editedCount: 40,
  deliveryDays: 3,
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

Future<void> _fill(
  WidgetTester tester, {
  String name = 'Cặp đôi nửa ngày',
  String price = '3200000',
  int minutes = 240,
}) async {
  await tester.enterText(_key('package-name'), name);
  await tester.enterText(_key('package-price'), price);
  await tester.ensureVisible(_key('package-duration'));
  await tester.tap(_key('package-duration'));
  await tester.pumpAndSettle();
  await tester.tap(_key('duration-$minutes'));
  await tester.pumpAndSettle();
}

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
  });

  testWidgets('adds a package that shows at once and unlocks the next step', (
    tester,
  ) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await _fill(tester);
    expect(
      find.text('3.200.000'),
      findsOneWidget,
      reason: 'the price field groups thousands',
    );
    await tester.enterText(_key('package-edited'), '80');
    await tester.enterText(_key('package-delivery'), '5');
    await tester.ensureVisible(_key('package-submit'));
    await tester.tap(_key('package-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Đã thêm gói.'), findsOneWidget);
    expect(
      w.packages.stored(w.uid).single.input,
      const ServicePackageInput(
        name: 'Cặp đôi nửa ngày',
        priceVnd: 3200000,
        durationMinutes: 240,
        editedCount: 80,
        deliveryDays: 5,
      ),
    );
    expect(find.text('4 giờ · 80 ảnh · giao 5 ngày'), findsOneWidget);
    expect(find.text('3,2M'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('package-name')).controller!.text,
      isEmpty,
      reason: 'the form is ready for the next one',
    );
    expect(_enabled(tester, 'setup-next'), isTrue);
  });

  testWidgets('says what is wrong and stores nothing', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('package-submit'));
    await tester.tap(_key('package-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên gói từ 2 đến 60 ký tự'), findsOneWidget);
    expect(find.text('Nhập giá lớn hơn 0'), findsOneWidget);
    expect(find.text('Chọn thời lượng'), findsOneWidget);
    expect(w.packages.writes, 0);
  });

  testWidgets('edits a package from the list', (tester) async {
    final w = await _world(seed: const [_portrait]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_key('package-a'));
    await tester.pump();
    expect(
      tester.widget<TextField>(_key('package-name')).controller!.text,
      'Chân dung 2 giờ',
    );
    await tester.enterText(_key('package-price'), '1800000');
    await tester.ensureVisible(_key('package-submit'));
    expect(find.text('Lưu gói'), findsOneWidget);
    await tester.tap(_key('package-submit'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.uid).single.priceVnd, 1800000);
    expect(find.text('Đã lưu gói.'), findsOneWidget);
  });

  testWidgets('hiding asks first; "Giữ lại" keeps the package', (tester) async {
    final w = await _world(seed: const [_portrait]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_key('package-hide-a'));
    await tester.pumpAndSettle();
    expect(find.text('Ẩn gói này?'), findsOneWidget);
    await tester.tap(_key('package-hide-keep'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.uid).single.active, isTrue);

    await tester.tap(_key('package-hide-a'));
    await tester.pumpAndSettle();
    await tester.tap(_key('package-hide-confirm'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.uid).single.active, isFalse);
    expect(_key('package-a'), findsNothing);
    expect(find.text('Đã ẩn gói.'), findsOneWidget);
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

  testWidgets('a half-filled form comes back after leaving', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await _fill(tester, name: 'Gia đình', price: '2000000', minutes: 180);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_key('package-name')).controller!.text,
      'Gia đình',
    );
    expect(
      tester.widget<TextField>(_key('package-price')).controller!.text,
      '2.000.000',
    );
  });

  testWidgets('a failed save keeps the form and says so', (tester) async {
    final w = await _world();
    w.packages.failWrites = true;
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await _fill(tester);
    await tester.ensureVisible(_key('package-submit'));
    await tester.tap(_key('package-submit'));
    await tester.pumpAndSettle();
    expect(
      find.text('Không lưu được thiết lập. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(_key('package-name')).controller!.text,
      'Cặp đôi nửa ngày',
    );
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      usePhone(tester, width: 320, height: 640);
      final w = await _world(
        seed: const [
          _portrait,
          ServicePackage(
            id: 'b',
            name: 'Cưới cả ngày, hai thợ, album in cao cấp',
            priceVnd: 18000000,
            durationMinutes: 480,
            editedCount: 300,
            deliveryDays: 30,
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
}
