import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/resilient_recommendation_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/find/find_screen.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

class _Spy extends DelegatingRecommender {
  _Spy(super.inner);
  final signals = <RecommendationSignal>[];
  @override
  Future<void> sendFeedback(List<RecommendationSignal> s) {
    signals.addAll(s);
    return super.sendFeedback(s);
  }
}

GoRouter _router({String start = '/action'}) => GoRouter(
  initialLocation: start,
  routes: [
    GoRoute(
      path: '/action',
      builder: (_, s) => FindPhotographerScreen(
        initialSpecialty: s.uri.queryParameters['specialty'],
        initialStyle: s.uri.queryParameters['style'],
        initialArea: s.uri.queryParameters['area'],
      ),
    ),
    GoRoute(
      path: '/u/:id',
      builder: (_, s) => Text('profile ${s.pathParameters['id']}'),
    ),
    GoRoute(path: '/u/:id/book', builder: (_, s) => Text('book ${s.uri}')),
    GoRoute(
      path: '/profile/phone',
      builder: (_, s) => Text('phone ${s.uri.queryParameters['returnTo']}'),
    ),
  ],
);

/// A phone: 390 wide, tall enough for several one-column cards.
void _phone(WidgetTester tester, [Size size = const Size(390, 2400)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<GoRouter> _open(
  WidgetTester tester,
  DiscoveryWorld w, {
  String start = '/action',
  double textScale = 1,
  Size size = const Size(390, 2400),
}) async {
  _phone(tester, size);
  await w.init();
  final router = _router(start: start);
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: w.overrides,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

double _top(WidgetTester t, String id) =>
    t.getTopLeft(find.byKey(Key('find-card-$id'))).dy;

/// The chip row scrolls sideways: bring the chip into view before using it.
Future<void> _tapChip(WidgetTester tester, String chipKey) async {
  await tester.ensureVisible(find.byKey(Key(chipKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(chipKey)));
  await tester.pumpAndSettle();
}

Future<void> _choose(
  WidgetTester tester,
  String chipKey,
  String optionText,
) async {
  await _tapChip(tester, chipKey);
  final option = find.text(optionText);
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('title, chips, count and the cards in recommended order', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld());
    expect(find.text('Tìm thợ ảnh'), findsWidgets);
    for (final key in [
      'find-area-chip',
      'find-date',
      'find-service',
      'find-price',
      'find-rating',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.text('Chọn khu vực'), findsOneWidget, reason: 'no area yet');
    expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
    expect(_top(tester, 'p1'), lessThan(_top(tester, 'p2')));
    expect(_top(tester, 'p2'), lessThan(_top(tester, 'p3')));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('cards show at most two reasons and the ticked name', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld());
    final p1 = find.byKey(const Key('find-card-p1'));
    expect(
      find.descendant(
        of: p1,
        matching: find.textContaining('Minh Trí', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: p1, matching: find.text('Rảnh T7 03/10')),
      findsOneWidget,
    );
  });

  testWidgets('service sheet: choose "Cưới" and the list narrows', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld());
    await _choose(tester, 'find-service', 'Cưới');
    expect(
      find.descendant(
        of: find.byKey(const Key('find-service')),
        matching: find.text('Cưới'),
      ),
      findsOneWidget,
    );
    expect(find.text('2 nhiếp ảnh gia'), findsOneWidget);
    expect(find.byKey(const Key('find-card-p3')), findsNothing);
  });

  testWidgets('budget and rating sheets', (tester) async {
    await _open(tester, DiscoveryWorld());
    await _choose(tester, 'find-price', 'Dưới 2M');
    expect(find.text('2 nhiếp ảnh gia'), findsOneWidget);
    await _choose(tester, 'find-rating', '★ 4,8+');
    expect(find.text('1 nhiếp ảnh gia'), findsOneWidget);
    expect(find.byKey(const Key('find-card-p1')), findsOneWidget);
  });

  testWidgets('sort by price puts the cheapest first', (tester) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('find-sort-price')));
    await tester.pumpAndSettle();
    expect(_top(tester, 'p3'), lessThan(_top(tester, 'p1')));
    expect(_top(tester, 'p1'), lessThan(_top(tester, 'p4')));
    expect(_top(tester, 'p4'), lessThan(_top(tester, 'p2')));
  });

  testWidgets(
    'a picked day drops busy photographers and names the day on the buttons',
    (tester) async {
      final w = DiscoveryWorld();
      await w.init();
      w.availability.set('p2', '2026-10-03', DayAvailability.booked);
      _phone(tester);
      final router = _router();
      await tester.pumpWidget(
        screenRouterApp(router: router, overrides: w.overrides),
      );
      await tester.pumpAndSettle();
      await _tapChip(tester, 'find-date');
      await tester.tap(find.text('3').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('date-done')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('find-date')),
          matching: find.text('T7 03/10'),
        ),
        findsOneWidget,
      );
      expect(find.text('3 nhiếp ảnh gia rảnh T7 03/10'), findsOneWidget);
      expect(find.byKey(const Key('find-card-p2')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('find-card-p1')),
          matching: find.text('Rảnh 03/10'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('find-card-p1')),
          matching: find.text('Đặt T7'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('card-book-p1')));
      await tester.pumpAndSettle();
      expect(find.text('book /u/p1/book?date=2026-10-03'), findsOneWidget);
    },
  );

  testWidgets('clearing the day from its sheet brings everyone back', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld());
    await _tapChip(tester, 'find-date');
    await tester.tap(find.byKey(const Key('date-done')));
    await tester.pumpAndSettle();
    await _tapChip(tester, 'find-date');
    await tester.tap(find.byKey(const Key('date-clear')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('find-date')),
        matching: find.text('Ngày'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dismissing a sheet changes nothing', (tester) async {
    await _open(tester, DiscoveryWorld());
    await _tapChip(tester, 'find-service');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
  });

  testWidgets(
    'no match: say so, offer to clear the filters, and clearing works',
    (tester) async {
      await _open(tester, DiscoveryWorld());
      await _choose(tester, 'find-service', 'Ẩm thực');
      expect(find.text('Chưa có ai khớp bộ lọc'), findsOneWidget);
      await tester.tap(find.text('Xoá bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
    },
  );

  testWidgets('a down remote recommender shows the quiet fallback note', (
    tester,
  ) async {
    await _open(
      tester,
      DiscoveryWorld(
        recommenderFactory: (x) => ResilientRecommendationRepository(
          primary: ThrowingRecommender(),
          fallback: x.localRecommender(),
        ),
      ),
    );
    expect(find.text('Đang xếp theo sao và khoảng cách'), findsOneWidget);
    expect(find.byKey(const Key('find-card-p1')), findsOneWidget);
  });

  testWidgets('the local ranking alone shows no note', (tester) async {
    await _open(tester, DiscoveryWorld());
    expect(find.text('Đang xếp theo sao và khoảng cách'), findsNothing);
  });

  testWidgets(
    'opening a profile sends a click signal; booking goes through the phone gate',
    (tester) async {
      late _Spy spy;
      final w = DiscoveryWorld(
        recommenderFactory: (x) => spy = _Spy(x.localRecommender()),
        hasPhone: false,
      );
      await _open(tester, w);
      await tester.tap(find.byKey(const Key('card-book-p1')));
      await tester.pumpAndSettle();
      expect(find.text('phone /u/p1/book'), findsOneWidget);
      final router = _router();
      await tester.pumpWidget(
        screenRouterApp(router: router, overrides: w.overrides),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('card-profile-p2')));
      await tester.pumpAndSettle();
      expect(find.text('profile p2'), findsOneWidget);
      expect(spy.signals.single.photographerId, 'p2');
    },
  );

  testWidgets(
    'the pin in the bar opens the area picker, and an area becomes the chip',
    (tester) async {
      await _open(tester, DiscoveryWorld());
      await tester.tap(find.byKey(const Key('find-area')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn khu vực của bạn'), findsOneWidget);
      await tester.tap(find.byKey(const Key('area-hcm-q1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-use')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('find-area-chip')),
          matching: find.text('Quận 1, TP.HCM'),
        ),
        findsOneWidget,
      );
      expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
    },
  );

  group('links from Explore', () {
    testWidgets('?specialty= applies a service filter', (tester) async {
      await _open(tester, DiscoveryWorld(), start: '/action?specialty=wedding');
      expect(
        find.descendant(
          of: find.byKey(const Key('find-service')),
          matching: find.text('Cưới'),
        ),
        findsOneWidget,
      );
      expect(find.text('2 nhiếp ảnh gia'), findsOneWidget);
    });

    testWidgets(
      '?style= applies a style filter with its own chip that clears on tap',
      (tester) async {
        await _open(tester, DiscoveryWorld(), start: '/action?style=film');
        expect(find.byKey(const Key('find-style')), findsOneWidget);
        expect(find.text('1 nhiếp ảnh gia'), findsOneWidget);
        await _tapChip(tester, 'find-style');
        expect(find.byKey(const Key('find-style')), findsNothing);
        expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
      },
    );

    testWidgets('?area= selects that area for good', (tester) async {
      final w = DiscoveryWorld();
      await _open(tester, w, start: '/action?area=hcm-q1');
      final saved =
          jsonDecode(w.prefs.getString(LocationController.areaKey)!) as Map;
      expect(saved['id'], 'hcm-q1');
      expect(
        find.descendant(
          of: find.byKey(const Key('find-area-chip')),
          matching: find.text('Quận 1, TP.HCM'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a new link while the screen is open changes the filter', (
      tester,
    ) async {
      final router = await _open(
        tester,
        DiscoveryWorld(),
        start: '/action?specialty=wedding',
      );
      router.go('/action?specialty=family');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('find-service')),
          matching: find.text('Gia đình'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 nhiếp ảnh gia'), findsOneWidget);
    });
  });

  testWidgets('paging: "20+" first, all after scrolling to the end', (
    tester,
  ) async {
    final w = DiscoveryWorld(
      photographers: [
        for (var i = 0; i < 30; i++)
          fixturePhotographer(
            'p${i.toString().padLeft(2, '0')}',
            name: 'Thợ $i',
            reviews: 10 + i,
          ),
      ],
    );
    await _open(tester, w);
    expect(find.text('20+ nhiếp ảnh gia'), findsOneWidget);
    // More reviews rank higher, so p00 is the last card.
    await tester.scrollUntilVisible(
      find.byKey(const Key('find-card-p00')),
      600,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 200,
    );
    await tester.pumpAndSettle();
    // The count line is at the top: scroll back up to read it.
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 100000),
      100000,
    );
    await tester.pumpAndSettle();
    expect(find.text('30 nhiếp ảnh gia'), findsOneWidget);
  });

  testWidgets(
    'a rating-filtered first page that does not fill the screen loads the next',
    (tester) async {
      // Page one keeps a single photographer after the rating filter, so
      // nothing scrolls; the next page must still be requested.
      final w = DiscoveryWorld(
        photographers: [
          for (var i = 0; i < 19; i++)
            fixturePhotographer(
              'a${i.toString().padLeft(2, '0')}',
              rating: 4.7,
              reviews: 1000,
              completed: 500,
            ),
          fixturePhotographer(
            'b00',
            rating: 4.85,
            reviews: 500,
            completed: 250,
          ),
          for (var i = 0; i < 20; i++)
            fixturePhotographer(
              'c${i.toString().padLeft(2, '0')}',
              rating: 4.85,
              reviews: 10,
              completed: 5,
            ),
        ],
      );
      await _open(tester, w);
      await _choose(tester, 'find-rating', '★ 4,8+');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('find-card-b00')), findsOneWidget);
      expect(find.byKey(const Key('find-card-c00')), findsOneWidget);
      expect(find.text('21 nhiếp ảnh gia'), findsOneWidget);
    },
  );

  testWidgets('a failing load shows the retry', (tester) async {
    final w = DiscoveryWorld();
    await w.init();
    w.photographers.failWith = StateError('offline');
    _phone(tester);
    await tester.pumpWidget(
      screenRouterApp(router: _router(), overrides: w.overrides),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Không tải được danh sách. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    w.photographers.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('find-card-p1')), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320x640 at 1.3x on ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = DiscoveryWorld();
      await w.init();
      await tester.pumpWidget(
        screenRouterApp(
          router: _router(),
          overrides: w.overrides,
          textScale: 1.3,
          brightness: b,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tapChip(tester, 'find-service');
      expect(tester.takeException(), isNull, reason: 'the sheet fits too');
    });
  }

  testWidgets('from 600dp the cards use two columns', (tester) async {
    await _open(tester, DiscoveryWorld(), size: const Size(900, 1200));
    final a = tester.getTopLeft(find.byKey(const Key('find-card-p1')));
    final b = tester.getTopLeft(find.byKey(const Key('find-card-p2')));
    expect(a.dy, b.dy);
    expect(b.dx, greaterThan(a.dx));
  });
}
