import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/spots/slot_pick_sheet.dart';
import 'package:photobooking/features/spots/spot_screen.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/fake_safety_repository.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/screen_host.dart';

final fixedClock = DateTime.utc(2026, 10, 15, 7); // Thursday 15 Oct 2026

Spot _spot({
  String id = 'spot1',
  String name = 'Hồ Tây',
  String city = 'Hà Nội',
  String areaCode = 'hn',
  double lat = 21.05,
  double lng = 105.82,
  int radiusM = 2000,
  SpotCover? cover = const SpotCover(
    url: 'https://img.test/cover.jpg',
    cardUrl: 'https://img.test/card.jpg',
  ),
  String description = 'Hồ nước ngọt tự nhiên lớn nhất Hà Nội với hoàng hôn tuyệt đẹp.',
  List<String> tips = const [
    'Thời điểm đẹp nhất là lúc hoàng hôn từ 17:00–18:00.',
    'Nên chọn góc chụp hướng chùa Trấn Quốc.',
  ],
  List<int> seasonMonths = const [10, 11, 12],
  bool pinned = false,
  bool hidden = false,
  bool archived = false,
  SpotStats stats = const SpotStats(
    posts14d: 12,
    events: 2,
    bookings14d: 5,
    openSchedules: 3,
    providersWeek: 3,
    providersWeekend: 2,
  ),
}) =>
    Spot(
      id: id,
      name: name,
      city: city,
      areaCode: areaCode,
      lat: lat,
      lng: lng,
      radiusM: radiusM,
      cover: cover,
      description: description,
      tips: tips,
      seasonMonths: seasonMonths,
      pinned: pinned,
      hidden: hidden,
      archived: archived,
      stats: stats,
    );

SpotSchedule _schedule({
  String id = 'sched1',
  String providerId = 'p1',
  String? assigneeId,
  String spotId = 'spot1',
  List<String> days = const ['2026-10-18'],
  SpotWindow window = const SpotWindow(start: '06:00', end: '11:00'),
  int priceFrom = 500000,
  bool open = true,
}) =>
    SpotSchedule(
      id: id,
      providerId: providerId,
      assigneeId: assigneeId,
      spotId: spotId,
      days: days,
      window: window,
      serviceIds: const ['s1'],
      priceFrom: priceFrom,
      open: open,
    );

SlotOffer _offer({
  String id = 'off1',
  String providerId = 'p1',
  String scheduleId = 'sched1',
  String spotId = 'spot1',
  String name = 'Bình minh Hồ Tây 30 phút',
  int price = 490000,
  int slotMinutes = 30,
  int gapMinutes = 10,
  int photoCount = 20,
  int editedCount = 5,
  int deliveryDays = 3,
  bool open = true,
}) =>
    SlotOffer(
      id: id,
      providerId: providerId,
      scheduleId: scheduleId,
      spotId: spotId,
      name: name,
      price: price,
      slotMinutes: slotMinutes,
      gapMinutes: gapMinutes,
      photoCount: photoCount,
      editedCount: editedCount,
      deliveryDays: deliveryDays,
      open: open,
    );

EventSummary _event({
  String id = 'ev1',
  String title = 'Photo Walk Hoàng Hôn',
}) =>
    EventSummary(
      id: id,
      title: title,
      hostName: 'Minh Trí',
      hostVerified: true,
      type: EventType.photoWalk,
      // eventsAt filters by the wall clock, so the event must be upcoming whenever the test runs.
      startsAt: DateTime.now().toUtc().add(const Duration(days: 30)),
      priceVnd: 100000,
      capacity: 10,
      registeredCount: 3,
      heldCount: 0,
      status: EventStatus.open,
      createdAt: DateTime.utc(2026, 10, 1),
      locationName: 'Hồ Tây, Hà Nội',
      lat: 21.05,
      lng: 105.82,
    );

Future<DiscoveryWorld> _makeWorld({UserRole role = UserRole.customer}) async {
  final w = DiscoveryWorld(role: role, clock: () => fixedClock);
  await w.init();
  return w;
}

void main() {
  testWidgets('blocks appear in spec order (header, description, tips, map, providers, offers, events, photos)', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    fakeSpots.seedSchedule(_schedule());
    fakeSpots.seedOffer(_offer());
    fakeSpots.seedEvents('spot1', [_event()]);
    fakeSpots.seedPosts('spot1', [fixturePost('post1')]);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
    );

    tester.view.physicalSize = const Size(390, 3000);
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

    // Verify presence
    final headerFinder = find.text('Hồ Tây').first;
    final descFinder = find.text('Hồ nước ngọt tự nhiên lớn nhất Hà Nội với hoàng hôn tuyệt đẹp.');
    final tipsFinder = find.text('Mẹo chụp');
    final mapFinder = find.text('Chỉ đường');
    final providersFinder = find.text('Thợ nhận chụp ở đây');
    final offersFinder = find.text('Gói chụp tại điểm');
    final eventsFinder = find.text('Sự kiện ở đây');
    final photosFinder = find.text('Ảnh chụp ở đây');

    expect(headerFinder, findsOneWidget);
    expect(descFinder, findsOneWidget);
    expect(tipsFinder, findsOneWidget);
    expect(mapFinder, findsOneWidget);
    expect(providersFinder, findsOneWidget);
    expect(offersFinder, findsOneWidget);
    expect(eventsFinder, findsOneWidget);
    expect(photosFinder, findsOneWidget);

    // Verify vertical ordering (top to bottom)
    final headerY = tester.getTopLeft(headerFinder).dy;
    final descY = tester.getTopLeft(descFinder).dy;
    final tipsY = tester.getTopLeft(tipsFinder).dy;
    final mapY = tester.getTopLeft(mapFinder).dy;
    final providersY = tester.getTopLeft(providersFinder).dy;
    final offersY = tester.getTopLeft(offersFinder).dy;
    final eventsY = tester.getTopLeft(eventsFinder).dy;
    final photosY = tester.getTopLeft(photosFinder).dy;

    expect(headerY, lessThan(descY));
    expect(descY, lessThan(tipsY));
    expect(tipsY, lessThan(mapY));
    expect(mapY, lessThan(providersY));
    expect(providersY, lessThan(offersY));
    expect(offersY, lessThan(eventsY));
    expect(eventsY, lessThan(photosY));
  });

  testWidgets('date chips: Hôm nay + days with schedules within 14 days + Chọn ngày', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    // 2026-10-18 is Sunday (CN 18/10), within 14 days of 2026-10-15
    fakeSpots.seedSchedule(_schedule(days: const ['2026-10-18']));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    expect(find.byKey(const Key('chip-day-today')), findsOneWidget);
    expect(find.byKey(const Key('chip-day-2026-10-18')), findsOneWidget);
    expect(find.byKey(const Key('chip-day-pick')), findsOneWidget);
  });

  testWidgets('a provider card shows "Có mặt CN 18/10 · 06:00–11:00", the price from and the tomato %', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    fakeSpots.seedSchedule(_schedule(days: const ['2026-10-18'], priceFrom: 500000));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    expect(find.text('Có mặt CN 18/10 · 06:00–11:00'), findsOneWidget);
    expect(find.text('từ 500K'), findsOneWidget);
    expect(find.text('97%'), findsOneWidget); // Minh Trí has 56 tomatoes / 58 total ~ 97%
  });

  testWidgets('providers whose acceptingOrders is false are hidden', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    // p1 has acceptingOrders: true, p2 will have acceptingOrders: false
    final p2 = fixturePhotographer('p2', name: 'Hồng Nhung', acceptingOrders: false);
    world.photographers.add(p2);

    fakeSpots.seedSpot(_spot());
    fakeSpots.seedSchedule(_schedule(id: 'sched1', providerId: 'p1', days: const ['2026-10-18']));
    fakeSpots.seedSchedule(_schedule(id: 'sched2', providerId: 'p2', days: const ['2026-10-18']));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    expect(find.byKey(const Key('spot-provider-sched1')), findsOneWidget);
    expect(find.byKey(const Key('spot-provider-sched2')), findsNothing);
  });

  testWidgets('"Đặt" calls startBooking with photographerId, scheduleId and chosen date', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    fakeSpots.seedSchedule(_schedule(days: const ['2026-10-18']));

    String? pushedUri;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
        GoRoute(
          path: '/u/:uid/book',
          builder: (_, state) {
            pushedUri = state.uri.toString();
            return Text('Booking Screen: $pushedUri');
          },
        ),
      ],
      initialLocation: '/spots/spot1',
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

    await tester.tap(find.text('Đặt'));
    await tester.pumpAndSettle();

    expect(pushedUri, isNotNull);
    expect(pushedUri, contains('/u/p1/book'));
    expect(pushedUri, contains('scheduleId=sched1'));
    expect(pushedUri, contains('date=2026-10-18'));
  });

  testWidgets('"Hồ sơ" opens /u/:uid', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    fakeSpots.seedSchedule(_schedule(days: const ['2026-10-18']));

    String? openedUid;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
        GoRoute(
          path: '/u/:uid',
          builder: (_, state) {
            openedUid = state.pathParameters['uid'];
            return Text('Profile: $openedUid');
          },
        ),
      ],
      initialLocation: '/spots/spot1',
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

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    expect(openedUid, equals('p1'));
  });

  testWidgets('an offer card counts free slots of the chosen day', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    // Schedule window 06:00 to 07:40 (100 min)
    // Offer slot 30 min, gap 10 min -> 06:00–06:30, 06:40–07:10 (2 slots total)
    fakeSpots.seedSchedule(
      _schedule(
        id: 'sched1',
        days: const ['2026-10-18'],
        window: const SpotWindow(start: '06:00', end: '07:40'),
      ),
    );
    fakeSpots.seedOffer(
      _offer(
        id: 'off1',
        scheduleId: 'sched1',
        slotMinutes: 30,
        gapMinutes: 10,
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    expect(
      find.textContaining(RegExp(r'còn 2 suất CN 18/10', caseSensitive: false)),
      findsOneWidget,
    );
  });

  testWidgets('an offer card shows "hết suất" when all slots are taken', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    fakeSpots.seedSchedule(
      _schedule(
        id: 'sched1',
        days: const ['2026-10-18'],
        window: const SpotWindow(start: '06:00', end: '07:40'),
      ),
    );
    fakeSpots.seedOffer(
      _offer(
        id: 'off1',
        scheduleId: 'sched1',
        slotMinutes: 30,
        gapMinutes: 10,
      ),
    );
    fakeSpots.seedSpotDay(
      const SpotDay(
        scheduleId: 'sched1',
        day: '2026-10-18',
        taken: [
          SpotInterval(start: '06:00', end: '06:30'),
          SpotInterval(start: '06:40', end: '07:10'),
        ],
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    expect(
      find.textContaining(RegExp(r'hết suất', caseSensitive: false)),
      findsOneWidget,
    );
  });

  testWidgets('a day without providers shows "Chưa có thợ nhận chụp ngày này · Xem ngày khác"', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    // Schedule only on 2026-10-18
    fakeSpots.seedSchedule(_schedule(days: const ['2026-10-18']));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-15', // date with no providers
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    expect(find.text('Chưa có thợ nhận chụp ngày này · Xem ngày khác'), findsOneWidget);
    expect(find.text('Xem ngày khác'), findsOneWidget);
  });

  testWidgets('the provider hint shows only to providers', (tester) async {
    // 1. As photographer: hint visible
    final pWorld = await _makeWorld(role: UserRole.photographer);
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedSpot(_spot());

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot1',
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...pWorld.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn là thợ ảnh? Thêm lịch chụp ở điểm này trong Công việc.'),
      findsOneWidget,
    );

    // 2. As customer: hint hidden
    final cWorld = await _makeWorld(role: UserRole.customer);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...cWorld.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn là thợ ảnh? Thêm lịch chụp ở điểm này trong Công việc.'),
      findsNothing,
    );
  });

  testWidgets('archived shows the band and hides providers and offers', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot(archived: true));
    fakeSpots.seedSchedule(_schedule(days: const ['2026-10-18']));
    fakeSpots.seedOffer(_offer());

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    expect(find.text('Điểm này không còn nhận lịch mới'), findsOneWidget);
    expect(find.text('Thợ nhận chụp ở đây'), findsNothing);
    expect(find.text('Gói chụp tại điểm'), findsNothing);
  });

  testWidgets('off-season shows the season line', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    // season months 5, 6 (May, June) - off season in October
    fakeSpots.seedSpot(_spot(seasonMonths: const [5, 6]));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    expect(find.byType(SeasonTag), findsNothing);
    expect(find.text('Mùa đẹp: tháng 5–6'), findsOneWidget);
  });

  testWidgets('photos load and show 9 tiles then Xem thêm', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    final postList = List.generate(
      12,
      (i) => fixturePost('post-$i', age: Duration(hours: i + 1)),
    );
    fakeSpots.seedPosts('spot1', postList);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot1',
    );

    tester.view.physicalSize = const Size(390, 3000);
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

    expect(find.text('Ảnh chụp ở đây'), findsOneWidget);
    expect(find.byKey(const Key('spot-photo-post-0')), findsOneWidget);
    expect(find.byKey(const Key('spot-photo-post-8')), findsOneWidget);
    expect(find.byKey(const Key('spot-photo-post-9')), findsNothing);
    expect(find.text('Xem thêm'), findsOneWidget);

    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spot-photo-post-9')), findsOneWidget);
    expect(find.byKey(const Key('spot-photo-post-11')), findsOneWidget);
  });

  Future<void> pumpSpot(
    WidgetTester tester,
    FakeSpotRepository fakeSpots, {
    List<Override> extra = const [],
  }) async {
    final world = await _makeWorld();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
    );
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          spotRepositoryProvider.overrideWithValue(fakeSpots),
          ...extra,
        ],
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('a failed schedules read shows the providers error with retry, not "no providers"', (tester) async {
    final fakeSpots = FakeSpotRepository()
      ..seedSpot(_spot())
      ..seedSchedule(_schedule())
      ..openSchedulesError = Exception('boom');
    await pumpSpot(tester, fakeSpots);
    await settle(tester);

    expect(find.byKey(const Key('spot-providers-error')), findsOneWidget);
    expect(find.text('Chưa có thợ nhận chụp ngày này · Xem ngày khác'), findsNothing);
    expect(find.byKey(const Key('spot-provider-sched1')), findsNothing);

    fakeSpots.openSchedulesError = null;
    await tester.tap(find.descendant(
      of: find.byKey(const Key('spot-providers-error')),
      matching: find.byKey(const Key('error-retry')),
    ));
    await settle(tester);

    expect(find.byKey(const Key('spot-providers-error')), findsNothing);
    expect(find.byKey(const Key('spot-provider-sched1')), findsOneWidget);
  });

  testWidgets('a failed offers read shows the offers error with retry; the providers still show', (tester) async {
    final fakeSpots = FakeSpotRepository()
      ..seedSpot(_spot())
      ..seedSchedule(_schedule())
      ..seedOffer(_offer())
      ..openOffersError = Exception('boom');
    await pumpSpot(tester, fakeSpots);
    await settle(tester);

    expect(find.byKey(const Key('spot-offers-error')), findsOneWidget);
    expect(find.text('Gói chụp tại điểm'), findsOneWidget);
    expect(find.byKey(const Key('spot-offer-off1')), findsNothing);
    expect(find.byKey(const Key('spot-provider-sched1')), findsOneWidget);

    fakeSpots.openOffersError = null;
    await tester.tap(find.descendant(
      of: find.byKey(const Key('spot-offers-error')),
      matching: find.byKey(const Key('error-retry')),
    ));
    await settle(tester);

    expect(find.byKey(const Key('spot-offers-error')), findsNothing);
    expect(find.byKey(const Key('spot-offer-off1')), findsOneWidget);
  });

  testWidgets('failed events and photos reads show their own errors', (tester) async {
    final fakeSpots = FakeSpotRepository()
      ..seedSpot(_spot())
      ..eventsError = Exception('boom')
      ..postsError = Exception('boom');
    await pumpSpot(tester, fakeSpots);
    await settle(tester);

    expect(find.byKey(const Key('spot-events-error')), findsOneWidget);
    expect(find.byKey(const Key('spot-photos-error')), findsOneWidget);
  });

  testWidgets('while schedules and offers load, their blocks show skeletons', (tester) async {
    final fakeSpots = FakeSpotRepository()..seedSpot(_spot());
    final schedules = Completer<List<SpotSchedule>>();
    final offers = Completer<List<SlotOffer>>();
    await pumpSpot(tester, fakeSpots, extra: [
      spotSchedulesAtProvider.overrideWith((ref, spotId) => schedules.future),
      spotOffersAtProvider.overrideWith((ref, spotId) => offers.future),
    ]);
    // The spot loads, then each block waits 150 ms before its skeleton shows.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('spot-providers-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('spot-offers-skeleton')), findsOneWidget);
    expect(find.text('Chưa có thợ nhận chụp ngày này · Xem ngày khác'), findsNothing);

    schedules.complete([_schedule()]);
    offers.complete([_offer()]);
    await settle(tester);

    expect(find.byKey(const Key('spot-providers-skeleton')), findsNothing);
    expect(find.byKey(const Key('spot-provider-sched1')), findsOneWidget);
    expect(find.byKey(const Key('spot-offer-off1')), findsOneWidget);
  });

  testWidgets('posts by blocked users are hidden', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    fakeSpots.seedPosts('spot1', [
      fixturePost('post-ok', photographerId: 'p1'),
      fixturePost('post-blocked', photographerId: 'blocked-user'),
      fixturePost('post-blocked-author', authorId: 'blocker-of-me'),
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot1',
    );

    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          // The real #144 block index (people I blocked + people who
          // blocked me) feeds the S29.02 posts, not a stub.
          safetyRepositoryProvider.overrideWithValue(
            FakeSafetyRepository(
              initialIndex: const BlockIndex(
                blockedIds: {'blocked-user'},
                blockedByIds: {'blocker-of-me'},
              ),
            ),
          ),
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spot-photo-post-ok')), findsOneWidget);
    expect(find.byKey(const Key('spot-photo-post-blocked')), findsNothing);
    expect(
      find.byKey(const Key('spot-photo-post-blocked-author')),
      findsNothing,
    );
  });

  testWidgets('share copies the link and shows SnackBar', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedSpot(_spot(id: 'spot123'));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot123',
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

    await tester.tap(find.byIcon(AppIcons.share));
    await tester.pumpAndSettle();

    expect(copied, equals('/spots/spot123'));
    expect(find.text('Đã sao chép liên kết điểm chụp'), findsOneWidget);
  });

  testWidgets('Chỉ đường opens Google Maps URL with lat,lng', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();
    fakeSpots.seedSpot(_spot(lat: 21.05, lng: 105.82));

    final launcher = FakeExternalLauncher();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot1',
    );

    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...world.overrides,
          externalLauncherProvider.overrideWithValue(launcher),
          spotRepositoryProvider.overrideWithValue(fakeSpots),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chỉ đường'));
    await tester.pumpAndSettle();

    expect(launcher.opened, hasLength(1));
    expect(
      launcher.opened.first.toString(),
      equals('https://www.google.com/maps/dir/?api=1&destination=21.05,105.82'),
    );
  });

  testWidgets('unknown spot shows ErrorState "Không tìm thấy điểm chụp."', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/unknown-spot',
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

    expect(find.text('Không tìm thấy điểm chụp.'), findsOneWidget);
  });

  testWidgets('no AppButton.primary on SpotScreen', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository();

    fakeSpots.seedSpot(_spot());
    fakeSpots.seedSchedule(_schedule(days: const ['2026-10-18']));
    fakeSpots.seedOffer(_offer());

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    // Verify there are no AppButtons anywhere on the screen (no sticky gradient CTA)
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('320 dp, 1.3×, dark and light layout without overflow', (tester) async {
    for (final dark in [false, true]) {
      final world = await _makeWorld();
      final fakeSpots = FakeSpotRepository();

      fakeSpots.seedSpot(_spot());
      fakeSpots.seedSchedule(_schedule(days: const ['2026-10-18']));
      fakeSpots.seedOffer(_offer());
      fakeSpots.seedEvents('spot1', [_event()]);
      fakeSpots.seedPosts('spot1', [fixturePost('post1')]);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/spots/:spotId',
            builder: (_, state) => SpotScreen(
              spotId: state.pathParameters['spotId']!,
              date: '2026-10-18',
            ),
          ),
        ],
        initialLocation: '/spots/spot1',
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
      expect(find.text('Hồ Tây'), findsWidgets);
    }
  });

  testWidgets('"Chọn suất" opens S29.06 on the viewed day', (tester) async {
    final world = await _makeWorld();
    final fakeSpots = FakeSpotRepository()
      ..seedSpot(_spot())
      ..seedSchedule(_schedule())
      ..seedOffer(_offer());

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) => SpotScreen(
            spotId: state.pathParameters['spotId']!,
            date: '2026-10-18',
          ),
        ),
      ],
      initialLocation: '/spots/spot1',
    );
    tester.view.physicalSize = const Size(390, 3000);
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

    await tester.tap(find.text('Chọn suất'));
    await tester.pumpAndSettle();

    expect(find.byType(SlotPickSheet), findsOneWidget);
    final sheet = find.byType(SlotPickSheet);
    expect(
      find.descendant(of: sheet, matching: find.widgetWithText(AppChip, 'CN 18/10')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(AppButton, 'Tiếp tục · 490.000₫'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Hôm nay" is the Vietnamese day: 18:00Z on 17/10 is 18/10', (
    tester,
  ) async {
    final world = DiscoveryWorld(clock: () => DateTime.utc(2026, 10, 17, 18));
    await world.init();
    final fakeSpots = FakeSpotRepository()
      ..seedSpot(_spot())
      ..seedSchedule(_schedule(days: const ['2026-10-18', '2026-10-19']));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, state) =>
              SpotScreen(spotId: state.pathParameters['spotId']!),
        ),
      ],
      initialLocation: '/spots/spot1',
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

    // 18/10 is today, so it has no chip of its own and is the chosen day.
    final today = tester.widget<AppChip>(find.byKey(const Key('chip-day-today')));
    expect(today.selected, isTrue);
    expect(find.byKey(const Key('chip-day-2026-10-18')), findsNothing);
    expect(find.byKey(const Key('chip-day-2026-10-19')), findsOneWidget);
    expect(find.textContaining('CN 18/10'), findsWidgets);
  });
}
