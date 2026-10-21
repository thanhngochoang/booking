// test/features/spots/my_spot_schedules_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_repository.dart';
import 'package:photobooking/features/spots/my_spot_schedules_screen.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/screen_host.dart';
import '../../support/spot_entry_fixture.dart';

/// Thursday 08/10/2026, 09:00 in Vietnam.
final _now = DateTime.utc(2026, 10, 8, 2);
const _uid = 'provider_1';

/// Mock `#S29.03`: Đồi chè Cầu Đất on six weekend days with two packages and
/// one slot offer; Phố cổ Hội An on two days for every package.
const _s1 = SpotSchedule(
  id: 's1',
  providerId: _uid,
  spotId: 'spot_1',
  assigneeId: null,
  days: [
    '2026-10-10',
    '2026-10-11',
    '2026-10-17',
    '2026-10-18',
    '2026-10-24',
    '2026-10-25',
  ],
  window: SpotWindow(start: '06:00', end: '11:00'),
  serviceIds: ['pkg1', 'pkg2'],
  priceFrom: 900000,
  open: true,
);

const _s2 = SpotSchedule(
  id: 's2',
  providerId: _uid,
  spotId: 'spot_2',
  assigneeId: null,
  days: ['2026-10-31', '2026-11-01'],
  window: SpotWindow(start: '15:00', end: '19:00'),
  serviceIds: [],
  priceFrom: 900000,
  open: true,
);

const _offer = SlotOffer(
  id: 'o1',
  providerId: _uid,
  scheduleId: 's1',
  spotId: 'spot_1',
  name: 'Chụp sương sớm 30 phút',
  price: 490000,
  slotMinutes: 30,
  gapMinutes: 10,
  photoCount: 30,
  editedCount: 15,
  deliveryDays: 3,
  open: true,
);

Booking _booking(String id, String day, BookingStatus status) =>
    makeTestBooking(
      id: id,
      photographerId: _uid,
      day: day,
      status: status,
    ).copyWith(spotId: 'spot_1', spotScheduleId: 's1', source: 'spot');

final _bookings = [
  _booking('b1', '2026-10-10', BookingStatus.requested),
  _booking('b2', '2026-10-18', BookingStatus.accepted),
  _booking('b3', '2026-10-18', BookingStatus.upcoming),
  _booking('b4', '2026-10-11', BookingStatus.cancelled),
];

FakeSpotRepository _repo({bool empty = false}) {
  final repo = FakeSpotRepository()
    ..ownerId = _uid
    ..seedDirectory([
      spotEntryFixture(id: 'spot_1', name: 'Đồi chè Cầu Đất', city: 'Đà Lạt'),
      spotEntryFixture(id: 'spot_2', name: 'Phố cổ Hội An', city: 'Hội An'),
    ]);
  if (!empty) {
    repo
      ..seedSchedule(_s1)
      ..seedSchedule(_s2)
      ..seedOffer(_offer);
  }
  return repo;
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  FakeSpotRepository? spots,
  List<Booking>? bookings,
  PhotographerIntro intro = const PhotographerIntro(acceptingOrders: true),
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  final router = GoRouter(
    initialLocation: '/me/spot-schedules',
    routes: [
      GoRoute(
        path: '/me/spot-schedules',
        builder: (_, _) => const MySpotSchedulesScreen(),
      ),
      GoRoute(path: '/me/spot-schedules/new', builder: stub),
      GoRoute(path: '/me/spot-schedules/:id', builder: stub),
      GoRoute(path: '/verify/start', builder: stub),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      brightness: brightness,
      textScale: textScale,
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: _uid)),
        ),
        clockProvider.overrideWithValue(() => _now),
        spotRepositoryProvider.overrideWithValue(spots ?? _repo()),
        myBookingsProvider(BookingRole.photographer)
            .overrideWith((ref) => Stream.value(bookings ?? _bookings)),
        myIntroProvider.overrideWith((ref) => Stream.value(intro)),
      ],
    ),
  );
  await _settle(tester);
  return router;
}

/// No looping loader on S29.03 once loaded: a bounded second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byKey(const Key('app-sheet')).last, matching: f);

void main() {
  testWidgets('lists schedules with days, window, per-day booking counts from '
      "the provider's bookings and offer count", (tester) async {
    await _pump(tester);

    expect(find.text('Lịch tại điểm'), findsOneWidget);
    expect(find.text('2 / 8 lịch đang mở'), findsOneWidget);

    expect(find.text('Đồi chè Cầu Đất'), findsOneWidget);
    expect(find.text('T7, CN · 10/10–25/10'), findsOneWidget);
    expect(find.text('6 ngày · 06:00–11:00 · 2 gói'), findsOneWidget);
    expect(find.text('T7 10/10 · 1 booking'), findsOneWidget);
    expect(find.text('CN 11/10 · 0 booking'), findsOneWidget);
    expect(find.text('T7 17/10 · 0 booking'), findsOneWidget);
    expect(find.text('CN 18/10 · 2 booking'), findsOneWidget);
    expect(find.text('+2 ngày'), findsOneWidget);
    expect(find.text('Chụp sương sớm 30 phút'), findsOneWidget);
    expect(find.text('490.000₫ · 7 suất/ngày'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Phố cổ Hội An'), 200);
    expect(find.text('T7 31/10, CN 01/11'), findsOneWidget);
    expect(find.text('2 ngày · 15:00–19:00 · mọi gói'), findsOneWidget);
    expect(
      find.text('Chưa có booking · chưa có gói chia suất'),
      findsOneWidget,
    );
  });

  testWidgets('"Huỷ lịch" opens the confirm sheet; confirming calls '
      'cancelSchedule; cancelling the sheet calls nothing', (tester) async {
    final spots = _repo();
    await _pump(tester, spots: spots);
    final cancel = find.byKey(const Key('spot-schedule-cancel-s2'));

    await tester.scrollUntilVisible(cancel, 200);
    await tester.tap(cancel);
    await _settle(tester);
    expect(find.text('Huỷ lịch tại Phố cổ Hội An?'), findsOneWidget);
    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Giữ lại')));
    await _settle(tester);
    expect(spots.cancelScheduleCalls, isEmpty);

    await tester.tap(cancel);
    await _settle(tester);
    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Huỷ lịch')));
    await _settle(tester);
    expect(spots.cancelScheduleCalls, ['s2']);
    expect(find.text('Đã huỷ lịch tại điểm'), findsOneWidget);
  });

  testWidgets('schedule_has_bookings shows "Còn 2 booking ngày CN 18/10…"', (
    tester,
  ) async {
    final spots = _repo()
      ..cancelScheduleError = const SpotError(
        SpotErrorCode.scheduleHasBookings,
        bookingCounts: {'2026-11-01': 0, '2026-10-18': 2},
      );
    await _pump(tester, spots: spots);
    final cancel = find.byKey(const Key('spot-schedule-cancel-s2'));
    await tester.scrollUntilVisible(cancel, 200);
    await tester.tap(cancel);
    await _settle(tester);
    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Huỷ lịch')));
    await _settle(tester);

    expect(
      find.text(
        'Còn 2 booking ngày CN 18/10. Liên hệ khách hoặc huỷ từng booking '
        '(khách được hoàn 100%).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('bookings the provider can see block the cancel without a call', (
    tester,
  ) async {
    final spots = _repo();
    await _pump(tester, spots: spots);
    await tester.tap(find.byKey(const Key('spot-schedule-cancel-s1')));
    await _settle(tester);

    expect(find.text('Huỷ lịch tại Đồi chè Cầu Đất?'), findsNothing);
    expect(
      find.text(
        'Còn 1 booking ngày T7 10/10. Liên hệ khách hoặc huỷ từng booking '
        '(khách được hoàn 100%).',
      ),
      findsOneWidget,
    );
    expect(spots.cancelScheduleCalls, isEmpty);
  });

  testWidgets('"Thêm lịch tại điểm" opens /me/spot-schedules/new', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('spot-schedules-add')));
    await _settle(tester);
    expect(find.text('stub /me/spot-schedules/new'), findsOneWidget);
  });

  testWidgets('"Sửa" opens S29.04 for the schedule', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('spot-schedule-edit-s1')));
    await _settle(tester);
    expect(find.text('stub /me/spot-schedules/s1'), findsOneWidget);
  });

  testWidgets('"Gói chia suất" opens S29.05; an offer row opens it to edit', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('spot-schedule-offer-s1')));
    await _settle(tester);
    expect(find.byKey(const Key('slot-offer-save')), findsOneWidget);
    expect(find.byKey(const Key('slot-offer-close')), findsNothing);
    await tester.tap(find.byKey(const Key('slot-offer-dismiss')));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('spot-offer-o1')));
    await _settle(tester);
    expect(find.byKey(const Key('slot-offer-close')), findsOneWidget);
  });

  testWidgets('empty state copy', (tester) async {
    await _pump(tester, spots: _repo(empty: true));
    expect(find.text('Chưa có lịch tại điểm'), findsOneWidget);
    expect(
      find.text(
        'Chọn một điểm chụp đang hot và mở lịch cuối tuần để khách đặt.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('spot-schedules-add')), findsOneWidget);
  });

  testWidgets('8 open schedules turn the primary off', (tester) async {
    final spots = _repo(empty: true);
    for (var i = 0; i < 8; i++) {
      spots.seedSchedule(
        SpotSchedule(
          id: 'x$i',
          providerId: _uid,
          spotId: 'spot_1',
          assigneeId: null,
          days: const ['2026-10-31'],
          window: const SpotWindow(start: '06:00', end: '11:00'),
          serviceIds: const [],
          priceFrom: null,
          open: true,
        ),
      );
    }
    await _pump(tester, spots: spots);
    expect(find.text('8 / 8 lịch đang mở'), findsOneWidget);
    final add = tester.widget<AppButton>(
      find.byKey(const Key('spot-schedules-add')),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('not accepting orders: the primary is "Xác minh để mở lịch"', (
    tester,
  ) async {
    await _pump(tester, intro: const PhotographerIntro(acceptingOrders: false));
    await tester.tap(find.byKey(const Key('spot-schedules-verify')));
    await _settle(tester);
    expect(find.text('stub /verify/start'), findsOneWidget);
  });

  testWidgets('exactly one AppButton.primary', (tester) async {
    await _pump(tester);
    expect(find.byType(CtaSurface), findsOneWidget);
  });

  for (final (name, brightness, scale, size) in [
    ('320 dp, 1.3×, dark', Brightness.dark, 1.3, const Size(320, 640)),
    ('320 dp, 1.3×, light', Brightness.light, 1.3, const Size(320, 640)),
  ]) {
    testWidgets('$name: no overflow', (tester) async {
      await _pump(tester, brightness: brightness, textScale: scale, size: size);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Phố cổ Hội An'), 200);
      expect(tester.takeException(), isNull);
    });
  }
}
