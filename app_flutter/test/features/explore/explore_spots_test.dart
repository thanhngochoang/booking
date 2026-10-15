import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/features/explore/explore_screen.dart';

import '../../support/explore_world.dart';
import '../../support/screen_host.dart';

SpotEntry _entry({
  required String id,
  required String name,
  double lat = 10.7769,
  double lng = 106.7009,
  bool pinned = false,
  int hotScore = 10,
  bool inSeason = true,
}) =>
    SpotEntry(
      spotId: id,
      name: name,
      city: 'TP. Hồ Chí Minh',
      areaCode: 'hcm',
      cardUrl: 'https://example.com/$id.jpg',
      lat: lat,
      lng: lng,
      radiusM: 1000,
      seasonMonths: const [10, 11, 12],
      inSeason: inSeason,
      pinned: pinned,
      hidden: false,
      hotScore: hotScore,
      openSchedules: 2,
      providersWeek: 3,
      providersWeekend: 2,
      upcomingEvents: 1,
    );

void main() {
  testWidgets('the Địa điểm tab shows spot tiles in orderSpots order and opens /spots/:id',
      (tester) async {
    final world = ExploreWorld();
    await world.init();

    // orderSpots places pinned first, then hot in season by score desc
    world.spots.seedDirectory([
      _entry(id: 'spot-normal', name: 'Điểm thường', hotScore: 10),
      _entry(id: 'spot-pinned', name: 'Điểm ghim', pinned: true, hotScore: 5),
      _entry(id: 'spot-hot', name: 'Điểm hot', hotScore: 90),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
        GoRoute(
          path: '/spots/:id',
          builder: (_, s) => Text('spot page ${s.pathParameters['id']}'),
        ),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: world.overrides,
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Địa điểm" category chip tab
    final placesTab = find.text('Địa điểm');
    expect(placesTab, findsOneWidget);
    await tester.tap(placesTab);
    await tester.pumpAndSettle();

    // Pinned spot should be first
    expect(find.byKey(const Key('spot-tile-spot-pinned')), findsOneWidget);
    expect(find.byKey(const Key('spot-tile-spot-hot')), findsOneWidget);
    expect(find.byKey(const Key('spot-tile-spot-normal')), findsOneWidget);

    // Tap spot-pinned opens /spots/:id
    await tester.tap(find.byKey(const Key('spot-tile-spot-pinned')));
    await tester.pumpAndSettle();
    expect(find.text('spot page spot-pinned'), findsOneWidget);
  });

  testWidgets(
      'with location, "Điểm chụp gần bạn" lists spots within 50 km nearest first above the events',
      (tester) async {
    // exploreFix is (lat: 10.7769, lng: 106.7009)
    final world = ExploreWorld(status: LocationPermissionStatus.granted);
    await world.init();

    // nearSpot is ~2.5km away, midSpot is ~25km away, farSpot is >100km away
    world.spots.seedDirectory([
      _entry(id: 'spot-far', name: 'Điểm rất xa', lat: 12.0, lng: 106.7009),
      _entry(id: 'spot-mid', name: 'Điểm 25km', lat: 11.0, lng: 106.7009),
      _entry(id: 'spot-near', name: 'Điểm gần 2km', lat: 10.80, lng: 106.7009),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
        GoRoute(
          path: '/spots/:id',
          builder: (_, s) => Text('spot page ${s.pathParameters['id']}'),
        ),
      ],
    );

    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: world.overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Điểm chụp gần bạn'), findsOneWidget);
    expect(find.byKey(const Key('nearby-spot-spot-near')), findsOneWidget);
    expect(find.byKey(const Key('nearby-spot-spot-mid')), findsOneWidget);
    expect(find.byKey(const Key('nearby-spot-spot-far')), findsNothing);

    // Order: near comes before mid
    final nearDx = tester.getTopLeft(find.byKey(const Key('nearby-spot-spot-near'))).dx;
    final midDx = tester.getTopLeft(find.byKey(const Key('nearby-spot-spot-mid'))).dx;
    expect(nearDx, lessThan(midDx));

    // Tap spot opens /spots/:id
    await tester.tap(find.byKey(const Key('nearby-spot-spot-near')));
    await tester.pumpAndSettle();
    expect(find.text('spot page spot-near'), findsOneWidget);
  });

  testWidgets('no nearby spot → no row', (tester) async {
    final world = ExploreWorld(status: LocationPermissionStatus.granted);
    await world.init();

    // Only a far spot (>100 km)
    world.spots.seedDirectory([
      _entry(id: 'spot-far', name: 'Điểm rất xa', lat: 12.0, lng: 106.7009),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
      ],
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: world.overrides,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Điểm chụp gần bạn'), findsNothing);
  });
}
