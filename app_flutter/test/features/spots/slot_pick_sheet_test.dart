// test/features/spots/slot_pick_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/spots/slot_pick_sheet.dart';

import '../../support/fake_spot_repository.dart';
import '../../support/screen_host.dart';
import '../../support/spot_booking_fixtures.dart';

void main() {
  // 2026-10-03 17:00 in Vietnam.
  final now = DateTime.utc(2026, 10, 3, 10);

  /// Mock `#S29.06`: on day 1 the 06:40, 08:00 and 10:00 slots are taken.
  FakeSpotRepository repo() => spotBookingRepo(
    taken: {
      spotBookingDay1: const [
        SpotInterval(start: '06:40', end: '07:10', offerId: spotBookingOfferId),
        SpotInterval(start: '08:00', end: '08:30', offerId: spotBookingOfferId),
        SpotInterval(start: '10:00', end: '10:30', offerId: spotBookingOfferId),
      ],
    },
  );

  Future<GoRouter> pumpSheet(
    WidgetTester tester, {
    FakeSpotRepository? spots,
  }) async {
    final router = GoRouter(
      initialLocation: '/spots/spot1',
      routes: [
        GoRoute(
          path: '/spots/:spotId',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: TextButton(
                  onPressed: () => showSlotPickSheet(
                    context,
                    ref,
                    offer: spotBookingOffer,
                    schedule: spotBookingSchedule(),
                    spotName: 'Hồ Tây',
                    day: spotBookingDay1,
                    providerName: 'Minh Trí',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/u/:uid/book',
          builder: (_, s) => Text('book ${s.uri}'),
        ),
      ],
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          clockProvider.overrideWithValue(() => now),
          spotRepositoryProvider.overrideWithValue(spots ?? repo()),
          currentContactProvider.overrideWithValue(
            const AsyncData(UserContact(phone: '+84912345678')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return router;
  }

  AppButton continueButton(WidgetTester tester) => tester.widget<AppButton>(
    find.widgetWithText(AppButton, 'Tiếp tục · 490.000₫'),
  );

  testWidgets('shows the free and taken slots of the chosen day from spot_days', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Chọn suất'), findsOneWidget);
    expect(find.text('Bình minh Hồ Tây 30 phút · Minh Trí'), findsOneWidget);
    expect(find.text('Thứ 7, 10/10 · còn 4 / 7 suất'), findsOneWidget);
    expect(find.text('Đã kín'), findsNWidgets(3));
    expect(find.text('–06:30'), findsOneWidget);
    expect(
      find.text(
        'Tại Hồ Tây · 15 ảnh chỉnh · giao trong 3 ngày. Gói chia suất không kèm dịch vụ đi kèm.',
      ),
      findsOneWidget,
    );
    // Only the schedule's days from today on.
    expect(find.widgetWithText(AppChip, 'T7 10/10'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'CN 11/10'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'T4 30/09'), findsNothing);
  });

  testWidgets('a day without a free slot has no chip; chips scroll in one row', (
    tester,
  ) async {
    final spots = repo()
      ..seedSpotDay(
        SpotDay(
          scheduleId: spotBookingScheduleId,
          day: spotBookingDay2,
          taken: [
            for (final s in const [
              '06:00', '06:40', '07:20', '08:00', '08:40', '09:20', '10:00',
            ])
              SpotInterval(
                start: s,
                end: '${s.substring(0, 3)}${(int.parse(s.substring(3)) + 30).toString().padLeft(2, '0')}',
                offerId: spotBookingOfferId,
              ),
          ],
        ),
      );
    await pumpSheet(tester, spots: spots);

    expect(find.widgetWithText(AppChip, 'T7 10/10'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'CN 11/10'), findsNothing);
    final row = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('slot-pick-days')),
    );
    expect(row.scrollDirection, Axis.horizontal);
  });

  testWidgets('changing the date chip reads that day', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.widgetWithText(AppChip, 'CN 11/10'));
    await tester.pumpAndSettle();

    expect(find.text('Chủ nhật, 11/10 · còn 7 / 7 suất'), findsOneWidget);
    expect(find.text('Đã kín'), findsNothing);
  });

  testWidgets('"Tiếp tục · 490.000₫" is disabled until a slot is picked', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(continueButton(tester).onPressed, isNull);

    await tester.tap(find.text('06:40')); // taken
    await tester.pump();
    expect(continueButton(tester).onPressed, isNull);

    await tester.tap(find.text('08:40'));
    await tester.pump();
    expect(continueButton(tester).onPressed, isNotNull);

    // A new day drops the picked time.
    await tester.tap(find.widgetWithText(AppChip, 'CN 11/10'));
    await tester.pumpAndSettle();
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets(
    'continue calls startBooking with scheduleId, slotOfferId, date and start',
    (tester) async {
      final router = await pumpSheet(tester);
      await tester.tap(find.text('08:40'));
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Tiếp tục · 490.000₫'));
      await tester.pumpAndSettle();

      final uri = router.state.uri;
      expect(uri.path, '/u/p1/book');
      expect(uri.queryParameters, {
        'date': spotBookingDay1,
        'scheduleId': spotBookingScheduleId,
        'offerId': spotBookingOfferId,
        'start': '08:40',
      });
      expect(find.text('Chọn suất'), findsNothing);
    },
  );

  testWidgets('exactly one AppButton.primary', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('08:40'));
    await tester.pump();
    expect(find.byType(CtaSurface), findsOneWidget);
  });

  testWidgets('320 dp and 1.3× text: no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screenApp(
        textScale: 1.3,
        overrides: [
          clockProvider.overrideWithValue(() => now),
          spotRepositoryProvider.overrideWithValue(repo()),
        ],
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AppSheetFrame(
              child: SlotPickSheet(
                offer: spotBookingOffer,
                schedule: spotBookingSchedule(),
                spotName: 'Hồ Tây',
                day: spotBookingDay1,
                providerName: 'Minh Trí',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Đã kín'), findsNWidgets(3));
  });
}
