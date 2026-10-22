import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';

Switch _switch(WidgetTester tester, String key) =>
    tester.widget<Switch>(find.byKey(Key(key)));

void main() {
  setUp(resetNotificationPrimerState);

  testWidgets(
    'shows the price table with customer and photographer amounts and "Bản 1 · đã đồng ý"',
    (tester) async {
      final repo = FakeInstantRepository(
        presence: presenceOf(),
        config: const InstantConfig(
          enabled: true,
          priceListVersion: 1,
          platformFeeBp: 2000,
          packages: [
            InstantPackage(
              code: 'p30',
              durationMin: 30,
              photos: 15,
              priceVnd: 390000,
            ),
            InstantPackage(
              code: 'p60',
              durationMin: 60,
              photos: 30,
              priceVnd: 690000,
            ),
            InstantPackage(
              code: 'p120',
              durationMin: 120,
              photos: 60,
              priceVnd: 1190000,
            ),
          ],
        ),
      );
      await pumpLiveShutter(tester, InstantWorld(repo: repo));

      expect(find.text('Chụp ngay'), findsOneWidget);
      expect(find.text('Live Shutter'), findsOneWidget);
      expect(find.text('Bản 1 · đã đồng ý'), findsOneWidget);
      expect(find.text('30 phút · 15 ảnh'), findsOneWidget);
      expect(find.text('1 giờ · 30 ảnh'), findsOneWidget);
      expect(find.text('2 giờ · 60 ảnh'), findsOneWidget);
      expect(find.text('Khách trả 390K'), findsOneWidget);
      expect(find.text('Khách trả 1,19M'), findsOneWidget);
      // 20% fee in this config: 390K → 312K, 1,19M → 952K (the mock's values).
      expect(find.text('312K'), findsOneWidget);
      expect(find.text('552K'), findsOneWidget);
      expect(find.text('952K'), findsOneWidget);
      expect(find.text('Bạn nhận'), findsNWidgets(3));
      expect(
        find.text(
          'Không mở app trong 30 phút thì tạm ngừng nhận lời mời; mở lại app là nhận tiếp. Huỷ sau khi nhận làm giảm điểm tin cậy.',
        ),
        findsOneWidget,
      );
      // The dry run on open asks for the reasons, and writes nothing.
      expect(repo.callsOf('setLiveShutter').single.args, {
        'online': true,
        'dryRun': true,
        'location': null,
      });
      expect(find.byKey(const Key('live-shutter-reasons')), findsNothing);
      expect(_switch(tester, 'live-shutter-switch').onChanged, isNotNull);
      expect(find.text('Tắt khi xong việc hôm nay'), findsNothing);
      expect(find.byType(AppButton), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.dispose();
    },
  );

  testWidgets(
    'not accepted: switch disabled, primary "Đồng ý bảng giá" calls saveSettings(acceptPriceListVersion: 1)',
    (tester) async {
      final repo = FakeInstantRepository(
        presence: presenceOf(priceListVersion: null),
      )..liveShutterReasons = [LiveShutterReason.priceListNotAccepted];
      await pumpLiveShutter(tester, InstantWorld(repo: repo));

      expect(find.text('Bản 1 · chưa đồng ý'), findsOneWidget);
      expect(_switch(tester, 'live-shutter-switch').onChanged, isNull);
      expect(find.text('Sẵn sàng hỗ trợ'), findsNothing);
      expect(find.byKey(const Key('live-shutter-reasons')), findsNothing);
      expect(
        find.text(
          'Giá do nền tảng đặt, giống nhau cho mọi nhiếp ảnh gia trong một lượt gợi ý. Đồng ý để bật Live Shutter.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Đồng ý bảng giá'));
      await settleInstant(tester);

      expect(repo.callsOf('saveSettings').single.args, {
        'acceptPriceListVersion': 1,
        'helpReady': null,
      });
      expect(find.text('Bản 1 · đã đồng ý'), findsOneWidget);
      expect(find.text('Đồng ý bảng giá'), findsNothing);
      expect(_switch(tester, 'live-shutter-switch').onChanged, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.dispose();
    },
  );

  testWidgets(
    'locked: lists reasons in order with "Thêm số" opening /profile/phone?returnTo=/work/instant',
    (tester) async {
      final repo = FakeInstantRepository(presence: presenceOf())
        ..liveShutterReasons = [
          LiveShutterReason.phoneRequired,
          LiveShutterReason.notAcceptingOrders,
        ];
      final router = await pumpLiveShutter(tester, InstantWorld(repo: repo));

      expect(find.text('Chưa bật được Live Shutter'), findsOneWidget);
      final rows = [
        find.text('Hoàn tất xác minh và hồ sơ để nhận đơn'),
        find.text('Thêm số điện thoại'),
      ];
      expect(rows[0], findsOneWidget);
      expect(rows[1], findsOneWidget);
      expect(
        tester.getTopLeft(rows[0]).dy,
        lessThan(tester.getTopLeft(rows[1]).dy),
      );
      expect(_switch(tester, 'live-shutter-switch').onChanged, isNull);
      expect(find.text('Sẵn sàng hỗ trợ'), findsNothing);
      // The mock has no footer button and no note in this state.
      expect(find.byType(AppFooterBar), findsNothing);

      await tester.tap(find.text('Thêm số'));
      await settleInstant(tester);

      final uri = router.state.uri;
      expect(uri.path, '/profile/phone');
      expect(uri.queryParameters['returnTo'], '/work/instant');
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.dispose();
    },
  );

  testWidgets(
    'location denied shows "Cho phép dùng vị trí để nhận lời mời ở gần" and "Mở cài đặt"',
    (tester) async {
      final repo = FakeInstantRepository(presence: presenceOf());
      final world = InstantWorld(
        repo: repo,
        location: FakeLocationRepository(
          status: LocationPermissionStatus.deniedForever,
        ),
      );
      await pumpLiveShutter(tester, world);

      expect(
        find.text('Cho phép dùng vị trí để nhận lời mời ở gần'),
        findsOneWidget,
      );
      expect(_switch(tester, 'live-shutter-switch').onChanged, isNull);

      await tester.tap(find.text('Mở cài đặt'));
      await settleInstant(tester);
      expect(world.location.openSettingsCalls, 1);

      // Back from Settings with the permission granted: the lock goes.
      world.location.status = LocationPermissionStatus.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleInstant(tester);
      expect(find.byKey(const Key('live-shutter-reasons')), findsNothing);
      expect(_switch(tester, 'live-shutter-switch').onChanged, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.dispose();
    },
  );

  testWidgets(
    'turning on asks permission, takes a fix and calls setLiveShutter(online: true, location)',
    (tester) async {
      final repo = FakeInstantRepository(presence: presenceOf());
      final world = InstantWorld(
        repo: repo,
        location: FakeLocationRepository(position: taoDan),
      );
      await pumpLiveShutter(tester, world);
      repo.calls.clear();

      await tester.tap(find.byKey(const Key('live-shutter-switch')));
      await settleInstant(tester);

      expect(world.location.requestCalls, 1);
      expect(world.location.positionCalls, 1);
      expect(repo.callsOf('setLiveShutter').single.args, {
        'online': true,
        'dryRun': false,
        'location': (lat: taoDan.lat, lng: taoDan.lng, accuracyM: 500.0),
      });
      expect(_switch(tester, 'live-shutter-switch').value, isTrue);
      expect(find.text('Tắt khi xong việc hôm nay'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.dispose();
    },
  );

  testWidgets(
    'turning on with a server reason shows it and leaves the switch off',
    (tester) async {
      final repo = FakeInstantRepository(presence: presenceOf());
      await pumpLiveShutter(tester, InstantWorld(repo: repo));
      repo.liveShutterReasons = [LiveShutterReason.outsideServiceArea];

      await tester.tap(find.byKey(const Key('live-shutter-switch')));
      await settleInstant(tester);

      expect(
        find.text('Bạn đang ở ngoài khu vực có Chụp ngay'),
        findsOneWidget,
      );
      expect(_switch(tester, 'live-shutter-switch').value, isFalse);
      // Being outside does not lock: the photographer may move and retry.
      expect(_switch(tester, 'live-shutter-switch').onChanged, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.dispose();
    },
  );

  testWidgets(
    'footer "Tắt khi xong việc hôm nay" only while online and turns it off',
    (tester) async {
      final repo = FakeInstantRepository(presence: presenceOf(online: true));
      await pumpLiveShutter(tester, InstantWorld(repo: repo));
      expect(_switch(tester, 'live-shutter-switch').value, isTrue);
      repo.calls.clear();

      await tester.tap(find.text('Tắt khi xong việc hôm nay'));
      await settleInstant(tester);

      expect(repo.callsOf('setLiveShutter').single.args, {
        'online': false,
        'dryRun': false,
        'location': null,
      });
      expect(_switch(tester, 'live-shutter-switch').value, isFalse);
      expect(find.text('Tắt khi xong việc hôm nay'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.dispose();
    },
  );

  testWidgets('helpReady switch calls saveSettings(helpReady: true)', (
    tester,
  ) async {
    final repo = FakeInstantRepository(presence: presenceOf());
    await pumpLiveShutter(tester, InstantWorld(repo: repo));

    await tester.tap(find.byKey(const Key('help-ready-switch')));
    await settleInstant(tester);

    expect(repo.callsOf('saveSettings').single.args, {
      'acceptPriceListVersion': null,
      'helpReady': true,
    });
    expect(_switch(tester, 'help-ready-switch').value, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.dispose();
  });

  testWidgets('a failed call shows "Mất kết nối. Thử lại nhé."', (
    tester,
  ) async {
    final repo = FakeInstantRepository(presence: presenceOf());
    await pumpLiveShutter(tester, InstantWorld(repo: repo));
    repo.failNext('saveSettings', 'network');

    await tester.tap(find.byKey(const Key('help-ready-switch')));
    await settleInstant(tester);

    expect(find.text('Mất kết nối. Thử lại nhé.'), findsOneWidget);
    expect(_switch(tester, 'help-ready-switch').value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.dispose();
  });

  testWidgets('the switch reads as "Live Shutter"', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = FakeInstantRepository(presence: presenceOf());
    await pumpLiveShutter(tester, InstantWorld(repo: repo));
    expect(
      tester.getSemantics(find.byKey(const Key('live-shutter-switch'))),
      matchesSemantics(
        label: 'Live Shutter',
        hasToggledState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.dispose();
  });

  for (final brightness in Brightness.values) {
    for (final state in ['online', 'terms', 'locked']) {
      testWidgets('fits 320dp at 1.3× text, ${brightness.name}, $state', (
        tester,
      ) async {
        final repo = FakeInstantRepository(
          presence: presenceOf(
            online: state == 'online',
            priceListVersion: state == 'terms' ? null : 1,
          ),
        );
        if (state == 'locked') {
          repo.liveShutterReasons = [
            LiveShutterReason.notAcceptingOrders,
            LiveShutterReason.phoneRequired,
          ];
        }
        final world = InstantWorld(
          repo: repo,
          location: FakeLocationRepository(
            status: state == 'locked'
                ? LocationPermissionStatus.denied
                : LocationPermissionStatus.granted,
          ),
        );
        await pumpLiveShutter(
          tester,
          world,
          brightness: brightness,
          textScale: 1.3,
          viewSize: const Size(320, 640),
        );
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await repo.dispose();
      });
    }
  }
}
