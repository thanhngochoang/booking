import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/home/home_screen.dart';

import '../../support/discovery_world.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/screen_host.dart';

SpotEntry _entry({
  required String id,
  required String name,
  bool inSeason = true,
  int providersWeek = 2,
}) =>
    SpotEntry(
      spotId: id,
      name: name,
      city: 'Hà Nội',
      areaCode: 'hn',
      cardUrl: 'https://example.com/$id.jpg',
      lat: 21.05,
      lng: 105.82,
      radiusM: 2000,
      seasonMonths: const [10, 11, 12],
      inSeason: inSeason,
      pinned: false,
      hidden: false,
      hotScore: 50,
      openSchedules: 3,
      providersWeek: providersWeek,
      providersWeekend: 2,
      upcomingEvents: 1,
    );

void main() {
  testWidgets('the section reads the ranking once and shows cards in order', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedRanking('all', [
      _entry(id: 'spot-1', name: 'Hồ Tây'),
      _entry(id: 'spot-2', name: 'Phố cổ Hội An'),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/spots', builder: (_, _) => const Text('spots screen')),
        GoRoute(
          path: '/spots/:id',
          builder: (_, s) => Text('spot ${s.pathParameters['id']}'),
        ),
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

    expect(find.text('Điểm chụp đang hot'), findsOneWidget);
    expect(find.text('Hồ Tây'), findsOneWidget);
    expect(find.text('Phố cổ Hội An'), findsOneWidget);
    expect(find.byKey(const Key('hot-spot-spot-1')), findsOneWidget);
    expect(find.byKey(const Key('hot-spot-spot-2')), findsOneWidget);

    // Cards are in order: spot-1 is before spot-2
    final pos1 = tester.getTopLeft(find.byKey(const Key('hot-spot-spot-1'))).dx;
    final pos2 = tester.getTopLeft(find.byKey(const Key('hot-spot-spot-2'))).dx;
    expect(pos1, lessThan(pos2));

    // Tap spot opens /spots/:id
    await tester.tap(find.byKey(const Key('hot-spot-spot-1')));
    await tester.pumpAndSettle();
    expect(find.text('spot spot-1'), findsOneWidget);
  });

  testWidgets('"Xem tất cả" opens /spots', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedRanking('all', [
      _entry(id: 'spot-1', name: 'Hồ Tây'),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/spots', builder: (_, _) => const Text('spots screen')),
        GoRoute(
          path: '/spots/:id',
          builder: (_, s) => Text('spot ${s.pathParameters['id']}'),
        ),
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

    final seeAll = find.byKey(const Key('hot-spots-see-all'));
    expect(seeAll, findsOneWidget);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    expect(find.text('spots screen'), findsOneWidget);
  });

  testWidgets('no entries → no section', (tester) async {
    final world = DiscoveryWorld();
    await world.init();
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedRanking('all', []);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
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

    expect(find.text('Điểm chụp đang hot'), findsNothing);
  });
}
