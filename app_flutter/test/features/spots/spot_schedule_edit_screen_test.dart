// test/features/spots/spot_schedule_edit_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/spots/spot_schedule_edit_screen.dart';

import '../../support/fake_spot_repository.dart';
import '../../support/screen_host.dart';
import '../../support/spot_entry_fixture.dart';

/// Thursday 08/10/2026, 09:00 in Vietnam.
final _october = DateTime.utc(2026, 10, 8, 2);
const _uid = 'provider_1';

/// Hội An is hot but far; Cầu Đất is near the Đà Lạt service area; Hồ Tây
/// is far and not hot.
List<SpotEntry> _directory() => [
  spotEntryFixture(
    id: 'spot_ht',
    name: 'Hồ Tây',
    city: 'Hà Nội',
    lat: 21.05,
    lng: 105.82,
  ),
  spotEntryFixture(
    id: 'spot_cd',
    name: 'Đồi chè Cầu Đất',
    city: 'Đà Lạt',
    lat: 11.88,
    lng: 108.55,
    seasonMonths: const [10, 11],
    inSeason: true,
  ),
  spotEntryFixture(
    id: 'spot_ha',
    name: 'Phố cổ Hội An',
    city: 'Hội An',
    lat: 15.88,
    lng: 108.33,
    hotScore: 15,
  ),
];

const _packages = [
  ServicePackage(
    id: 'pkg1',
    name: 'Chân dung 2 giờ',
    priceVnd: 900000,
    durationMinutes: 120,
  ),
  ServicePackage(
    id: 'pkg2',
    name: 'Cưới cả ngày',
    priceVnd: 9000000,
    durationMinutes: 480,
  ),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<({GoRouter router, FakeSpotRepository spots})> _pump(
  WidgetTester tester, {
  String path = '/me/spot-schedules/new',
  DateTime? now,
  bool studio = false,
  FakeAvailabilityRepository? availability,
  FakeSpotRepository? spots,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo =
      spots ??
      (FakeSpotRepository()
        ..ownerId = _uid
        ..seedDirectory(_directory()));
  final router = GoRouter(
    initialLocation: '/me/spot-schedules',
    routes: [
      GoRoute(
        path: '/me/spot-schedules',
        builder: (_, s) => Scaffold(body: Text('stub ${s.uri}')),
      ),
      GoRoute(
        path: '/me/spot-schedules/new',
        builder: (_, s) =>
            SpotScheduleEditScreen(spotId: s.uri.queryParameters['spotId']),
      ),
      GoRoute(
        path: '/me/spot-schedules/:id',
        builder: (_, s) =>
            SpotScheduleEditScreen(scheduleId: s.pathParameters['id']),
      ),
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
        clockProvider.overrideWithValue(() => now ?? _october),
        spotRepositoryProvider.overrideWithValue(repo),
        availabilityRepositoryProvider.overrideWithValue(
          availability ?? FakeAvailabilityRepository(),
        ),
        myIntroProvider.overrideWith(
          (ref) => Stream.value(
            PhotographerIntro(
              acceptingOrders: true,
              providerType: studio
                  ? ProviderType.studio
                  : ProviderType.individual,
            ),
          ),
        ),
        myPackagesProvider.overrideWith((ref) => Stream.value(_packages)),
        myStudioRelationsProvider.overrideWith(
          (ref) => Stream.value([
            StudioRelation(
              id: 'r1',
              studioId: _uid,
              memberId: 'm1',
              status: RelationStatus.active,
              createdAt: DateTime.utc(2026, 9, 1),
              expiresAt: DateTime.utc(2026, 9, 8),
              memberName: 'Minh Trí',
            ),
          ]),
        ),
        photographerRepositoryProvider.overrideWithValue(
          FakePhotographerRepository([
            const PhotographerSummary(
              id: _uid,
              displayName: 'Ánh Dương',
              lat: 11.94,
              lng: 108.44,
            ),
          ]),
        ),
      ],
    ),
  );
  await tester.pump();
  router.push(path);
  await _settle(tester);
  return (router: router, spots: repo);
}

/// Picks [day] of the month the date picker opens on, then OK.
Future<void> _pickDate(WidgetTester tester, Key field, String day) async {
  await tester.tap(find.byKey(field));
  await _settle(tester);
  await tester.tap(find.text(day).last);
  await tester.pump();
  await tester.tap(find.text('OK'));
  await _settle(tester);
}

void main() {
  testWidgets('the picker lists hot spots first, then by distance from the '
      'service area, and filters by typed name (accent-insensitive)', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('spot-schedule-spot')));
    await _settle(tester);

    double y(String id) =>
        tester.getTopLeft(find.byKey(Key('spot-option-$id'))).dy;
    expect(y('spot_ha'), lessThan(y('spot_cd')));
    expect(y('spot_cd'), lessThan(y('spot_ht')));

    await tester.enterText(
      find.byKey(const Key('spot-picker-search')),
      'cau dat',
    );
    await tester.pump();
    expect(find.byKey(const Key('spot-option-spot_cd')), findsOneWidget);
    expect(find.byKey(const Key('spot-option-spot_ha')), findsNothing);
    expect(find.byKey(const Key('spot-option-spot_ht')), findsNothing);

    await tester.tap(find.byKey(const Key('spot-option-spot_cd')));
    await _settle(tester);
    expect(find.text('Đồi chè Cầu Đất · Đà Lạt'), findsOneWidget);
  });

  testWidgets('opened with spotId the spot is preselected and locked', (
    tester,
  ) async {
    await _pump(tester, path: '/me/spot-schedules/new?spotId=spot_cd');
    expect(find.text('Đồi chè Cầu Đất · Đà Lạt'), findsOneWidget);
    await tester.tap(find.byKey(const Key('spot-schedule-spot')));
    await _settle(tester);
    expect(find.byKey(const Key('spot-picker-search')), findsNothing);
  });

  testWidgets('preview reads "12 ngày · 06:00–11:00"', (tester) async {
    await _pump(tester, path: '/me/spot-schedules/new?spotId=spot_cd');
    expect(find.text('Thêm lịch tại điểm'), findsOneWidget);
    expect(find.text('0 / 8'), findsOneWidget);
    await _pickDate(tester, const Key('spot-schedule-from'), '10');
    await _pickDate(tester, const Key('spot-schedule-to'), '15');
    expect(find.text('T7 10/10'), findsOneWidget);
    expect(find.text('CN 15/11'), findsOneWidget);
    expect(find.text('12 ngày · 06:00–11:00'), findsOneWidget);
  });

  testWidgets('a booked day is red with its reason; tapping it away unlocks '
      '"Mở lịch"', (tester) async {
    final availability = FakeAvailabilityRepository()
      ..seed(
        _uid,
        AvailabilityDay(
          day: DateTime.utc(2026, 10, 24),
          state: DayState.booked,
          bookingId: 'b1',
        ),
      );
    await _pump(
      tester,
      path: '/me/spot-schedules/new?spotId=spot_cd',
      availability: availability,
    );
    final chip = find.byKey(const Key('spot-preview-day-2026-10-24'));
    await tester.ensureVisible(chip);
    expect(find.text('24/10 ×'), findsOneWidget);
    expect(find.text('T7 24/10 đã có booking ở nơi khác.'), findsOneWidget);
    AppButton submit() =>
        tester.widget(find.byKey(const Key('spot-schedule-submit')));
    expect(submit().onPressed, isNull);

    await tester.tap(chip);
    await tester.pump();
    expect(find.text('24/10 ×'), findsNothing);
    expect(submit().onPressed, isNotNull);
  });

  testWidgets('off-season note for Đồi chè Cầu Đất in March', (tester) async {
    await _pump(
      tester,
      path: '/me/spot-schedules/new?spotId=spot_cd',
      now: DateTime.utc(2026, 3, 5, 2),
    );
    expect(find.text('Điểm này đẹp nhất tháng 10–11'), findsOneWidget);

    await _pump(tester, path: '/me/spot-schedules/new?spotId=spot_cd');
    expect(find.text('Điểm này đẹp nhất tháng 10–11'), findsNothing);
  });

  testWidgets('studio shows "Thợ chụp", individual does not', (tester) async {
    await _pump(
      tester,
      studio: true,
      path: '/me/spot-schedules/new?spotId=spot_cd',
    );
    expect(find.text('THỢ CHỤP'), findsOneWidget);
    expect(find.text('Minh Trí'), findsOneWidget);

    await _pump(tester, path: '/me/spot-schedules/new?spotId=spot_cd');
    expect(find.text('THỢ CHỤP'), findsNothing);
  });

  testWidgets('packages longer than the window cannot be picked', (
    tester,
  ) async {
    final (:router, :spots) = await _pump(
      tester,
      path: '/me/spot-schedules/new?spotId=spot_cd',
    );
    final long = find.byKey(const Key('spot-schedule-package-pkg2'));
    await tester.ensureVisible(long);
    await tester.tap(long, warnIfMissed: false);
    await tester.tap(find.byKey(const Key('spot-schedule-package-pkg1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('spot-schedule-submit')));
    await _settle(tester);
    expect(spots.saveScheduleCalls.single.serviceIds, ['pkg1']);
  });

  testWidgets('success pops with "Đã mở lịch tại điểm"', (tester) async {
    final (:router, :spots) = await _pump(
      tester,
      path: '/me/spot-schedules/new?spotId=spot_cd',
    );
    await tester.tap(find.byKey(const Key('spot-schedule-submit')));
    await _settle(tester);

    expect(spots.saveScheduleCalls.single.spotId, 'spot_cd');
    expect(spots.saveScheduleCalls.single.serviceIds, isEmpty);
    expect(find.text('stub /me/spot-schedules'), findsOneWidget);
    expect(find.text('Đã mở lịch tại điểm'), findsOneWidget);
  });

  testWidgets('editing opens on "Chọn ngày" with "Lưu thay đổi"', (
    tester,
  ) async {
    final spots = FakeSpotRepository()
      ..ownerId = _uid
      ..seedDirectory(_directory())
      ..seedSchedule(
        const SpotSchedule(
          id: 'sch1',
          providerId: _uid,
          spotId: 'spot_cd',
          assigneeId: null,
          days: ['2026-10-10', '2026-10-11'],
          window: SpotWindow(start: '15:00', end: '19:00'),
          serviceIds: [],
          priceFrom: 900000,
          open: true,
        ),
      );
    await _pump(tester, path: '/me/spot-schedules/sch1', spots: spots);
    expect(find.text('Sửa lịch tại điểm'), findsOneWidget);
    expect(find.byKey(const Key('spot-schedule-calendar')), findsOneWidget);
    expect(find.text('2 ngày · 15:00–19:00'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('spot-schedule-submit')));
    await _settle(tester);
    expect(spots.saveScheduleCalls.single.scheduleId, 'sch1');
    expect(find.text('Đã lưu lịch tại điểm'), findsOneWidget);
  });

  testWidgets('exactly one AppButton.primary', (tester) async {
    await _pump(tester, path: '/me/spot-schedules/new?spotId=spot_cd');
    expect(find.byType(CtaSurface), findsOneWidget);
  });

  for (final (name, brightness) in [
    ('320 dp, 1.3×, dark', Brightness.dark),
    ('320 dp, 1.3×, light', Brightness.light),
  ]) {
    testWidgets('$name: no overflow (studio, both modes)', (tester) async {
      await _pump(
        tester,
        studio: true,
        path: '/me/spot-schedules/new?spotId=spot_cd',
        brightness: brightness,
        textScale: 1.3,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Chọn ngày'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
