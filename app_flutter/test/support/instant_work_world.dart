// Test world for the photographer side of Chụp ngay (S14.01, S06.01 card,
// heartbeat): a fake repository, a fake location, a clock the test moves.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant_work/live_shutter_screen.dart';
import 'package:photobooking/features/instant_work/offer_screen.dart';

import 'fake_instant_repository.dart';
import 'fake_push.dart';
import 'screen_host.dart';

/// Thursday 08/10/2026 09:00 in Vietnam.
final instantNow = DateTime.utc(2026, 10, 8, 2);

/// Tao Đàn park, District 1.
const taoDan = (lat: 10.7745, lng: 106.6918);

/// About 350 m north of [taoDan].
const taoDanNorth = (lat: 10.77765, lng: 106.6918);

/// "Now" for tests; moved together with the fake timers by [InstantWorld.wait].
class InstantClock {
  InstantClock([DateTime? now]) : now = now ?? instantNow;
  DateTime now;
}

/// A presence that accepted price list 1, online or not.
LiveShutterState presenceOf({
  bool online = false,
  bool helpReady = false,
  int? priceListVersion = 1,
  DateTime? heartbeatAt,
}) => LiveShutterState(
  online: online,
  helpReady: helpReady,
  priceListVersion: priceListVersion,
  heartbeatAt: heartbeatAt,
);

class InstantWorld {
  InstantWorld({
    FakeInstantRepository? repo,
    FakeLocationRepository? location,
    InstantClock? clock,
    this.enabled = true,
  }) : repo = repo ?? FakeInstantRepository(),
       location =
           location ??
           FakeLocationRepository(
             status: LocationPermissionStatus.granted,
             position: taoDan,
           ),
       clock = clock ?? InstantClock();

  final FakeInstantRepository repo;
  final FakeLocationRepository location;
  final InstantClock clock;
  final bool enabled;

  List<Override> get overrides => [
    instantRepositoryProvider.overrideWithValue(repo),
    instantEnabledProvider.overrideWithValue(enabled),
    locationRepositoryProvider.overrideWithValue(location),
    clockProvider.overrideWithValue(() => clock.now),
    ...grantedNotificationPermissionUnless(const []),
  ];

  /// Moves the clock and the fake timers together.
  Future<void> wait(WidgetTester tester, Duration d) async {
    const step = Duration(seconds: 10);
    var left = d;
    while (left > Duration.zero) {
      final s = left < step ? left : step;
      clock.now = clock.now.add(s);
      await tester.pump(s);
      left -= s;
    }
  }
}

/// Stub pages record where the screen went.
Widget _stub(BuildContext _, GoRouterState s) =>
    Scaffold(body: Text('stub ${s.uri}'));

/// S14.01 at `/work/instant` (pushed over `/bookings`, so back pops).
Future<GoRouter> pumpLiveShutter(
  WidgetTester tester,
  InstantWorld world, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/bookings',
    routes: [
      GoRoute(path: '/bookings', builder: _stub),
      GoRoute(
        path: '/work/instant',
        builder: (_, _) => const LiveShutterScreen(),
      ),
      GoRoute(path: '/work/instant/:id', builder: _stub),
      GoRoute(path: '/profile/phone', builder: _stub),
    ],
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: world.overrides,
      brightness: brightness,
      textScale: textScale,
    ),
  );
  router.push('/work/instant');
  await settleInstant(tester);
  return router;
}

/// Bounded settle: AsyncView's 150/400 ms timers and a few microtasks.
Future<void> settleInstant(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A pending offer (mock S14.02 values) expiring [expiresIn] after [instantNow].
InstantOffer offerOf(
  String id, {
  String requestId = 'req1',
  Duration expiresIn = const Duration(seconds: 47),
  String areaLabel = 'Phường Bến Thành, Quận 1',
  double distanceKm = 2.1,
  int etaMinutes = 8,
  int earningVnd = 552000,
  int durationMin = 60,
  int photos = 30,
  InstantGenre genre = InstantGenre.portrait,
  String note = 'Chụp chân dung ở hồ, mình mặc áo dài trắng.',
  int invitedCount = 3,
}) {
  final expiresAt = instantNow.add(expiresIn);
  return InstantOffer(
    id: id,
    requestId: requestId,
    offeredAt: expiresAt.subtract(const Duration(seconds: 60)),
    expiresAt: expiresAt,
    outcome: OfferOutcome.pending,
    packageCode: 'p$durationMin',
    durationMin: durationMin,
    photos: photos,
    genre: genre,
    areaLabel: areaLabel,
    distanceKm: distanceKm,
    etaMinutes: etaMinutes,
    earningVnd: earningVnd,
    note: note,
    invitedCount: invitedCount,
  );
}

/// The request as its assigned photographer reads it right after winning.
InstantRequest assignedRequestOf(
  String id, {
  String customerName = 'Lan Anh',
  String place = 'Công viên Tao Đàn',
}) => InstantRequest(
  id: id,
  customerId: 'cus1',
  customerName: customerName,
  status: InstantStatus.assigned,
  packageCode: 'p60',
  durationMin: 60,
  photos: 30,
  genre: InstantGenre.portrait,
  meetPoint: InstantMeetPoint(lat: taoDan.lat, lng: taoDan.lng, name: place),
  areaLabel: 'Phường Bến Thành, Quận 1',
  photographerId: 'me',
  etaMinutes: 8,
);

/// S14.02 at `/work/instant/offer/[offerId]`, pushed over `/work/instant`.
Future<GoRouter> pumpOfferScreen(
  WidgetTester tester,
  InstantWorld world, {
  String offerId = 'o1',
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/work/instant',
    routes: [
      GoRoute(path: '/work/instant', builder: _stub),
      GoRoute(
        path: '/work/instant/offer/:offerId',
        builder: (_, s) => OfferScreen(offerId: s.pathParameters['offerId']!),
      ),
      GoRoute(path: '/work/instant/:id', builder: _stub),
    ],
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: world.overrides,
      textScale: textScale,
    ),
  );
  router.push('/work/instant/offer/$offerId');
  await settleInstant(tester);
  return router;
}
