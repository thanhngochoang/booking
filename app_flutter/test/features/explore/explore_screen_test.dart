// test/features/explore/explore_screen_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/explore/explore_screen.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/widgets/event_tile.dart';

import '../../support/explore_world.dart';
import '../../support/screen_host.dart';

Future<Widget> _app(
  ExploreWorld w, {
  double textScale = 1,
  GoRouter? router,
}) async {
  await w.init();
  return router == null
      ? screenApp(
          home: const ExploreScreen(),
          overrides: w.overrides,
          textScale: textScale,
        )
      : screenRouterApp(
          router: router,
          overrides: w.overrides,
          textScale: textScale,
        );
}

double _top(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  group('S13 before any location choice', () {
    testWidgets('asks nothing at start: only the card with Cho phép / Để sau', (
      tester,
    ) async {
      final w = ExploreWorld();
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      expect(find.text('Sự kiện gần bạn'), findsOneWidget);
      expect(find.text('Cho phép'), findsOneWidget);
      expect(w.location.requestCalls, 0);
      expect(find.text('Quanh bạn · vị trí gần đúng'), findsNothing);
    });

    testWidgets('Cho phép asks the OS once and switches to the nearby layout', (
      tester,
    ) async {
      // A phone width: from 600dp the rows are in two columns.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = ExploreWorld();
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-allow')));
      await tester.pumpAndSettle();
      expect(w.location.requestCalls, 1);
      expect(find.text('Quanh bạn · vị trí gần đúng'), findsOneWidget);
      expect(
        find.byType(NearbyEventTile),
        findsNWidgets(3),
        reason: 'default 25 km',
      );
      expect(
        _top(tester, 'Photo walk phố cổ'),
        lessThan(_top(tester, 'Mini session mùa thu')),
      );
      expect(
        _top(tester, 'Mini session mùa thu'),
        lessThan(_top(tester, 'Workshop ánh sáng')),
      );
      expect(find.text('1,1 km · Công viên Bạch Đằng'), findsOneWidget);
    });

    testWidgets('Để sau turns the card into a chip and it stays away', (
      tester,
    ) async {
      final w = ExploreWorld();
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-later')));
      await tester.pumpAndSettle();
      expect(find.text('Cho phép'), findsNothing);
      expect(find.byKey(const Key('location-choose-area')), findsOneWidget);
      expect(w.location.requestCalls, 0);
    });

    testWidgets('picking an area from the chip shows its events', (
      tester,
    ) async {
      final w = ExploreWorld();
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-choose-area')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-hcm-q1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-use')));
      await tester.pumpAndSettle();
      expect(
        find.text('Quanh Quận 1, TP.HCM · vị trí gần đúng'),
        findsOneWidget,
      );
      expect(find.byType(NearbyEventTile), findsWidgets);
    });

    testWidgets('upcoming events are listed when there is no location', (
      tester,
    ) async {
      final w = ExploreWorld(status: LocationPermissionStatus.denied);
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      expect(find.text('Sự kiện chụp ảnh'), findsOneWidget);
      expect(find.byType(NearbyEventTile), findsWidgets);
      expect(w.repo.upcomingCalls, 1);
    });

    testWidgets('the events section disappears when there are none', (
      tester,
    ) async {
      final w = ExploreWorld(
        status: LocationPermissionStatus.denied,
        events: [],
      );
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      expect(find.text('Sự kiện chụp ảnh'), findsNothing);
    });
  });

  group('S36 from denied-forever', () {
    testWidgets('the picker offers the Settings shortcut', (tester) async {
      final w = ExploreWorld(status: LocationPermissionStatus.deniedForever);
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-choose-area')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('area-open-settings')), findsOneWidget);
    });
  });

  group('S35 nearby', () {
    Future<ExploreWorld> nearby(
      WidgetTester tester, {
      double textScale = 1,
    }) async {
      final w = ExploreWorld(
        status: LocationPermissionStatus.granted,
        prefsValues: {
          LocationController.areaKey: jsonEncode(
            builtInAreas.first.toSaved().toJson(),
          ),
        },
      );
      await tester.pumpWidget(await _app(w, textScale: textScale));
      await tester.pumpAndSettle();
      return w;
    }

    testWidgets(
      'radius chips filter, and the empty state offers a wider radius',
      (tester) async {
        await nearby(tester);
        expect(find.byType(NearbyEventTile), findsNWidgets(3));
        await tester.tap(find.byKey(const Key('filter-radius-10')));
        await tester.pumpAndSettle();
        expect(find.byType(NearbyEventTile), findsNWidgets(2));
        await tester.tap(find.byKey(const Key('filter-free')));
        await tester.pumpAndSettle();
        expect(find.text('Chưa có sự kiện gần bạn'), findsOneWidget);
        await tester.tap(find.byKey(const Key('explore-widen')));
        await tester.pumpAndSettle();
        expect(
          find.byType(NearbyEventTile),
          findsNWidgets(1),
          reason: '25 km, free only',
        );
      },
    );

    testWidgets('weekend and this-week chips narrow the list', (tester) async {
      await nearby(tester);
      await tester.tap(find.byKey(const Key('filter-weekend')));
      await tester.pumpAndSettle();
      expect(find.byType(NearbyEventTile), findsNWidgets(1));
      expect(find.text('Photo walk phố cổ'), findsOneWidget);
    });

    testWidgets('free events carry the tag, paid ones the short price', (
      tester,
    ) async {
      await nearby(tester);
      final free = find.descendant(
        of: find.byKey(const Key('event-tile-free')),
        matching: find.text('Không thu phí'),
      );
      expect(free, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('event-tile-mid')),
          matching: find.text('600K'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Đổi" opens the area picker', (tester) async {
      await nearby(tester);
      await tester.tap(find.byKey(const Key('explore-change')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn khu vực của bạn'), findsOneWidget);
    });

    testWidgets('fits 320x640 at 1.3x', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await nearby(tester, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two columns from 600dp', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await nearby(tester);
      final a = tester.getTopLeft(find.byKey(const Key('event-tile-near')));
      final b = tester.getTopLeft(find.byKey(const Key('event-tile-mid')));
      expect(a.dy, b.dy);
      expect(b.dx, greaterThan(a.dx));
    });
  });

  group('navigation', () {
    testWidgets(
      'event rows and "Xem tất cả" stay inert until the event routes exist',
      (tester) async {
        await tester.pumpWidget(
          await _app(ExploreWorld(status: LocationPermissionStatus.denied)),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('explore-see-all')), findsNothing);
        final tile = tester.widget<NearbyEventTile>(
          find.byType(NearbyEventTile).first,
        );
        expect(tile.onTap, isNull);
      },
    );

    testWidgets(
      'with event routes ready, tapping a row and "Xem tất cả" navigate',
      (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
            GoRoute(
              path: '/events',
              builder: (_, _) => const Text('events-list'),
            ),
            GoRoute(
              path: '/e/:id',
              builder: (_, s) => Text('event-${s.pathParameters['id']}'),
            ),
          ],
        );
        await tester.pumpWidget(
          await _app(
            ExploreWorld(
              status: LocationPermissionStatus.denied,
              routesReady: true,
            ),
            router: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('explore-see-all')));
        await tester.pumpAndSettle();
        expect(find.text('events-list'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('event-tile-near')));
        await tester.pumpAndSettle();
        expect(find.text('event-near'), findsOneWidget);
      },
    );

    testWidgets(
      'a customer taps a service tile and lands on Find with the filter',
      (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
            GoRoute(
              path: '/action',
              builder: (_, s) => Text('find ${s.uri.query}'),
            ),
          ],
        );
        await tester.pumpWidget(
          await _app(
            ExploreWorld(status: LocationPermissionStatus.denied),
            router: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('category-services-portrait')));
        await tester.pumpAndSettle();
        expect(find.text('find specialty=portrait'), findsOneWidget);
      },
    );

    testWidgets('a photographer sees the tiles but they do not navigate', (
      tester,
    ) async {
      final w = ExploreWorld(
        status: LocationPermissionStatus.denied,
        role: UserRole.photographer,
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
          GoRoute(path: '/action', builder: (_, _) => const Text('find')),
        ],
      );
      await tester.pumpWidget(await _app(w, router: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-services-portrait')));
      await tester.pumpAndSettle();
      expect(find.text('find'), findsNothing);
    });

    testWidgets('the four category tabs switch the tiles', (tester) async {
      await tester.pumpWidget(
        await _app(ExploreWorld(status: LocationPermissionStatus.denied)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Địa điểm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-places-hcm-q1')), findsOneWidget);
      await tester.tap(find.text('Phong cách'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-styles-film')), findsOneWidget);
      await tester.tap(find.text('Thợ ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Xem tất cả nhiếp ảnh gia'), findsOneWidget);
    });
  });

  testWidgets('a failing events source shows the error state with retry', (
    tester,
  ) async {
    final w = ExploreWorld(status: LocationPermissionStatus.denied);
    w.repo.failWith = StateError('offline');
    await tester.pumpWidget(await _app(w));
    await tester.pumpAndSettle();
    expect(
      find.text('Không tải được sự kiện. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    w.repo.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.byType(NearbyEventTile), findsWidgets);
  });
}
