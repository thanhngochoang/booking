import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant_work/live_shutter_card.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';
import '../../support/screen_host.dart';

InstantRequest _job() => const InstantRequest(
  id: 'req1',
  customerId: 'cus1',
  customerName: 'Lan Anh',
  status: InstantStatus.enRoute,
  packageCode: 'p60',
  durationMin: 60,
  photos: 30,
  genre: InstantGenre.portrait,
  meetPoint: InstantMeetPoint(
    lat: 10.7745,
    lng: 106.6918,
    name: 'Công viên Tao Đàn',
  ),
);

Future<GoRouter> _pump(WidgetTester tester, InstantWorld world) async {
  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  final router = GoRouter(
    initialLocation: '/bookings',
    routes: [
      GoRoute(
        path: '/bookings',
        builder: (_, _) =>
            Scaffold(body: ListView(children: const [LiveShutterCard()])),
      ),
      GoRoute(path: '/work/instant', builder: stub),
      GoRoute(path: '/work/instant/:id', builder: stub),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(router: router, overrides: world.overrides),
  );
  await settleInstant(tester);
  return router;
}

void main() {
  testWidgets('off/on/job texts', (tester) async {
    final repo = FakeInstantRepository(presence: presenceOf());
    await _pump(tester, InstantWorld(repo: repo));

    expect(find.text('Live Shutter'), findsOneWidget);
    expect(find.text('Đang tắt · bật để nhận việc chụp ngay'), findsOneWidget);
    expect(find.byKey(const Key('instant-job-req1')), findsNothing);

    repo.emitPresence(presenceOf(online: true));
    await settleInstant(tester);
    expect(find.text('Đang bật · nhận lời mời ở gần bạn'), findsOneWidget);

    repo.emitActiveJob(_job());
    await settleInstant(tester);
    expect(find.text('Việc chụp ngay · Lan Anh'), findsOneWidget);
    expect(find.text('Chân dung 1 giờ · Công viên Tao Đàn'), findsOneWidget);
    expect(find.text('ĐANG ĐẾN'), findsOneWidget);
    // The job card sits under the Live Shutter card.
    expect(
      tester.getTopLeft(find.text('Live Shutter')).dy,
      lessThan(tester.getTopLeft(find.text('Việc chụp ngay · Lan Anh')).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.dispose();
  });

  testWidgets('a presence never created reads as off', (tester) async {
    final repo = FakeInstantRepository();
    await _pump(tester, InstantWorld(repo: repo));
    expect(find.text('Đang tắt · bật để nhận việc chụp ngay'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.dispose();
  });

  testWidgets('tap opens /work/instant or /work/instant/:id', (tester) async {
    final repo = FakeInstantRepository(
      presence: presenceOf(online: true),
      activeJob: _job(),
    );
    final router = await _pump(tester, InstantWorld(repo: repo));

    await tester.tap(find.byKey(const Key('live-shutter-card')));
    await settleInstant(tester);
    expect(router.state.uri.toString(), '/work/instant');

    router.pop();
    await settleInstant(tester);
    await tester.tap(find.text('Việc chụp ngay · Lan Anh'));
    await settleInstant(tester);
    expect(router.state.uri.toString(), '/work/instant/req1');
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.dispose();
  });

  testWidgets('hidden when instantEnabledProvider is false', (tester) async {
    final repo = FakeInstantRepository(presence: presenceOf(online: true));
    await _pump(tester, InstantWorld(repo: repo, enabled: false));
    expect(find.text('Live Shutter'), findsNothing);
    expect(find.byKey(const Key('live-shutter-card')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.dispose();
  });
}
