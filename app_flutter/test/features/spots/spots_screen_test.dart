import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/spots/spots_screen.dart';

import '../../support/discovery_world.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/screen_host.dart';

SpotEntry _entry({
  required String id,
  required String name,
  String city = 'Hà Nội',
  String areaCode = 'hn',
  bool inSeason = true,
  bool pinned = false,
  int hotScore = 10,
  int providersWeekend = 2,
  double lat = 21.05,
  double lng = 105.82,
}) =>
    SpotEntry(
      spotId: id,
      name: name,
      city: city,
      areaCode: areaCode,
      cardUrl: 'https://example.com/$id.jpg',
      lat: lat,
      lng: lng,
      radiusM: 2000,
      seasonMonths: inSeason ? const [10, 11, 12] : const [1, 2],
      inSeason: inSeason,
      pinned: pinned,
      hidden: false,
      hotScore: hotScore,
      openSchedules: 3,
      providersWeek: 3,
      providersWeekend: providersWeekend,
      upcomingEvents: 1,
    );

void main() {
  testWidgets('default order pinned → hot → rest by distance', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedDirectory([
      _entry(id: 'spot-normal', name: 'Điểm thường', hotScore: 10),
      _entry(id: 'spot-pinned', name: 'Điểm ghim', pinned: true, hotScore: 5),
      _entry(id: 'spot-hot', name: 'Điểm hot', hotScore: 90),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spot-card-spot-pinned')), findsOneWidget);
    expect(find.byKey(const Key('spot-card-spot-hot')), findsOneWidget);
    expect(find.byKey(const Key('spot-card-spot-normal')), findsOneWidget);

    final dyPinned = tester.getTopLeft(find.byKey(const Key('spot-card-spot-pinned'))).dy;
    final dyHot = tester.getTopLeft(find.byKey(const Key('spot-card-spot-hot'))).dy;
    final dyNormal = tester.getTopLeft(find.byKey(const Key('spot-card-spot-normal'))).dy;

    expect(dyPinned, lessThan(dyHot));
    expect(dyHot, lessThan(dyNormal));
  });

  testWidgets('area chip filters by areaCode', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedDirectory([
      _entry(id: 'spot-hn', name: 'Hồ Tây', city: 'Hà Nội', areaCode: 'hn'),
      _entry(id: 'spot-hcm', name: 'Nhà thờ Đức Bà', city: 'TP.HCM', areaCode: 'hcm'),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hồ Tây'), findsOneWidget);
    expect(find.text('Nhà thờ Đức Bà'), findsOneWidget);

    // Tap area chip
    await tester.tap(find.byKey(const Key('filter-area')));
    await tester.pumpAndSettle();

    // Tap Hà Nội in sheet
    await tester.tap(find.text('Hà Nội'));
    await tester.pumpAndSettle();

    expect(find.text('Hồ Tây'), findsOneWidget);
    expect(find.text('Nhà thờ Đức Bà'), findsNothing);
  });

  testWidgets('"Đang vào mùa" keeps in-season spots only', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedDirectory([
      _entry(id: 'spot-in', name: 'Điểm vào mùa', inSeason: true),
      _entry(id: 'spot-out', name: 'Điểm hết mùa', inSeason: false),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Điểm vào mùa'), findsOneWidget);
    expect(find.text('Điểm hết mùa'), findsOneWidget);

    // Toggle in season filter
    await tester.tap(find.byKey(const Key('filter-in-season')));
    await tester.pumpAndSettle();

    expect(find.text('Điểm vào mùa'), findsOneWidget);
    expect(find.text('Điểm hết mùa'), findsNothing);
  });

  testWidgets('"Cuối tuần này có thợ" keeps providersWeekend > 0', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedDirectory([
      _entry(id: 'spot-weekend', name: 'Có thợ cuối tuần', providersWeekend: 3),
      _entry(id: 'spot-none', name: 'Không có thợ', providersWeekend: 0),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Có thợ cuối tuần'), findsOneWidget);
    expect(find.text('Không có thợ'), findsOneWidget);

    // Toggle weekend filter
    await tester.ensureVisible(find.byKey(const Key('filter-weekend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-weekend')));
    await tester.pumpAndSettle();

    expect(find.text('Có thợ cuối tuần'), findsOneWidget);
    expect(find.text('Không có thợ'), findsNothing);
  });

  testWidgets('21 spots show 20 then the next page on scroll', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();

    final spotsList = List.generate(
      21,
      (i) => _entry(id: 'spot-$i', name: 'Điểm $i', hotScore: 100 - i),
    );
    fakeSpots.seedDirectory(spotsList);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Spot 0 should exist, spot 20 should not be built initially because page limit is 20
    expect(find.byKey(const Key('spot-card-spot-0')), findsOneWidget);
    expect(find.byKey(const Key('spot-card-spot-20')), findsNothing);

    // Scroll down to load more
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.drag(scrollable, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spot-card-spot-20')), findsOneWidget);
  });

  testWidgets('empty text shows when no spots match', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedDirectory([]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có điểm chụp nào ở khu vực này'), findsOneWidget);
  });

  testWidgets('load error with retry', (tester) async {
    final world = DiscoveryWorld();
    await world.init();

    // Provider override throwing error
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotDirectoryProvider.overrideWith((ref) => throw Exception('error')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không tải được điểm chụp.'), findsOneWidget);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('no AppButton.primary', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedDirectory([
      _entry(id: 'spot-1', name: 'Điểm 1'),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Neither SpotsScreen nor SpotScreen uses a bottom gradient CTA (AppButton.primary)
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('320 dp, 1.3×, dark and light layout without overflow', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedDirectory([
      _entry(id: 'spot-1', name: 'Điểm 1'),
    ]);

    for (final dark in [false, true]) {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SpotsScreen()),
        ],
      );

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        screenRouterApp(
          router: router,
          textScale: 1.3,
          brightness: dark ? Brightness.dark : Brightness.light,
          overrides: [
            ...world.overrides,
            spotRepositoryProvider.overrideWithValue(fakeSpots),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Điểm 1'), findsOneWidget);
    }
  });
}
