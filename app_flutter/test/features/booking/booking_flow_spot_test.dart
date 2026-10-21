// test/features/booking/booking_flow_spot_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/booking_sheet_page.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

import '../../support/booking_world.dart';
import '../../support/fake_addon_repository.dart';
import '../../support/fake_booking_repository.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/spot_booking_fixtures.dart';

void main() {
  final today = worldBookingToday; // 2026-10-03

  late FakeBookingRepository bookings;
  late FakeSpotRepository spots;

  ProviderContainer makeContainer({
    List<String> serviceIds = const ['s1'],
    bool archived = false,
    Map<String, List<SpotInterval>> taken = const {},
  }) {
    final addonRepo = FakeAddonRepository();
    for (final a in [addonMakeup, addonRetouch, addonTransport]) {
      addonRepo.seed(a);
    }
    bookings = FakeBookingRepository();
    spots = spotBookingRepo(
      archived: archived,
      serviceIds: serviceIds,
      taken: taken,
    );
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => today),
        calendarTodayProvider.overrideWithValue(today),
        profilePackagesProvider(
          'p1',
        ).overrideWithValue(const AsyncData([bookingPackage1, bookingPackage2])),
        currentContactProvider.overrideWithValue(
          const AsyncData(UserContact(phone: '+84912345678')),
        ),
        bookingRepositoryProvider.overrideWithValue(bookings),
        photographerPoolCacheProvider.overrideWithValue(
          FakePhotographerRepository(),
        ),
        addonRepositoryProvider.overrideWithValue(addonRepo),
        spotRepositoryProvider.overrideWithValue(spots),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<BookingFlowController> open(
    ProviderContainer container,
    BookingFlowArgs args,
  ) async {
    final sub = container.listen(bookingFlowControllerProvider(args), (_, _) {});
    addTearDown(sub.close);
    await settle();
    return container.read(bookingFlowControllerProvider(args).notifier);
  }

  const pkgArgs = BookingFlowArgs(
    photographerId: 'p1',
    scheduleId: spotBookingScheduleId,
    day: spotBookingDay2,
  );
  const slotArgs = BookingFlowArgs(
    photographerId: 'p1',
    scheduleId: spotBookingScheduleId,
    slotOfferId: spotBookingOfferId,
    day: spotBookingDay1,
    start: '06:40',
  );
  BookingFlowState read(ProviderContainer c, BookingFlowArgs a) =>
      c.read(bookingFlowControllerProvider(a));

  /// Package `s1` on [day] at [start], walked to S04.03.
  Future<BookingFlowController> toReview(
    ProviderContainer c, {
    String day = spotBookingDay1,
    String start = '08:30',
  }) async {
    final ctrl = await open(c, pkgArgs);
    ctrl.selectService(bookingPackage1);
    ctrl.next();
    ctrl.selectDay(day);
    await settle();
    ctrl.selectStart(start);
    ctrl.next();
    ctrl.next();
    expect(read(c, pkgArgs).step, BookingStep.review);
    return ctrl;
  }

  test('with scheduleId the packages are limited to serviceIds', () async {
    final c = makeContainer();
    await open(c, pkgArgs);
    final s = read(c, pkgArgs);
    expect(
      s.spot!.packagesOf([bookingPackage1, bookingPackage2]).map((p) => p.id),
      ['s1'],
    );
    // The only package the schedule takes is chosen for the customer.
    expect(s.serviceId, 's1');
  });

  test('serviceIds [] keeps every active package', () async {
    final c = makeContainer(serviceIds: const []);
    await open(c, pkgArgs);
    final s = read(c, pkgArgs);
    expect(
      s.spot!.packagesOf([bookingPackage1, bookingPackage2]).map((p) => p.id),
      ['s1', 's2'],
    );
    expect(s.serviceId, isNull);
  });

  test(
    "the date step offers only the schedule's future days and preselects args.day",
    () async {
      final c = makeContainer();
      await open(c, pkgArgs);
      final s = read(c, pkgArgs);
      expect(s.spot!.daysFrom('2026-10-03'), [spotBookingDay1, spotBookingDay2]);
      expect(s.day, spotBookingDay2);

      const elsewhere = BookingFlowArgs(
        photographerId: 'p1',
        scheduleId: spotBookingScheduleId,
        day: '2026-10-20',
      );
      await open(c, elsewhere);
      expect(read(c, elsewhere).day, spotBookingDay1);
    },
  );

  test(
    'start times come from freeStartTimes of the chosen day (window 06:00–11:00, taken 07:00–08:00, 120-min package → exactly 08:30 and 09:00)',
    () async {
      final c = makeContainer(
        taken: {
          spotBookingDay1: [const SpotInterval(start: '07:00', end: '08:00')],
        },
      );
      final ctrl = await open(c, pkgArgs);
      ctrl.selectService(bookingPackage1);
      ctrl.selectDay(spotBookingDay1);
      expect(read(c, pkgArgs).availableStarts(today), isNull); // reading
      await settle();
      expect(read(c, pkgArgs).availableStarts(today), ['08:30', '09:00']);
    },
  );

  test('placeName is the spot name and setPlace is ignored in spot context', () async {
    final c = makeContainer();
    final ctrl = await open(c, pkgArgs);
    expect(read(c, pkgArgs).placeName, 'Hồ Tây');
    ctrl.setPlace('Quận 1');
    expect(read(c, pkgArgs).placeName, 'Hồ Tây');
  });

  test('submit sends spotScheduleId and no slotOfferId for a package', () async {
    final c = makeContainer();
    final ctrl = await toReview(c);
    await ctrl.submit();

    final call = bookings.createCalls.single;
    expect(call.spotScheduleId, spotBookingScheduleId);
    expect(call.slotOfferId, isNull);
    expect(call.serviceId, 's1');
    expect(call.day, spotBookingDay1);
    expect(call.start, '08:30');
    expect(call.placeName, 'Hồ Tây');
  });

  test(
    'slot path: opens on review with the offer as service (name, price, 30 min), day and start from args, no add-on block, back closes',
    () async {
      final c = makeContainer();
      final ctrl = await open(c, slotArgs);
      final s = read(c, slotArgs);
      expect(s.step, BookingStep.review);
      expect(s.isSlot, isTrue);
      expect(s.serviceId, spotBookingOfferId);
      expect(s.serviceName, 'Bình minh Hồ Tây 30 phút');
      expect(s.priceVnd, 490000);
      expect(s.durationMinutes, 30);
      expect(s.day, spotBookingDay1);
      expect(s.start, '06:40');
      expect(s.end, '07:10');
      expect(s.addons, isNotEmpty);
      expect(s.applicableAddons, isEmpty);

      ctrl.toggleAddon('a_makeup');
      expect(read(c, slotArgs).picks, isEmpty);

      expect(ctrl.back(), isFalse);
      expect(read(c, slotArgs).step, BookingStep.review);
    },
  );

  test('slot path submit sends slotOfferId and no addons or pickup', () async {
    final c = makeContainer();
    final ctrl = await open(c, slotArgs);
    await ctrl.submit();

    final call = bookings.createCalls.single;
    expect(call.spotScheduleId, spotBookingScheduleId);
    expect(call.slotOfferId, spotBookingOfferId);
    expect(call.serviceId, spotBookingOfferId);
    expect(call.expectedPrice, 490000);
    expect(call.start, '06:40');
    expect(call.addons, isEmpty);
    expect(call.pickup, isNull);
    expect(call.expectedTotal, isNull);
  });

  test(
    'slot_taken in the package path refreshes the spot day and returns to the date step with bookSlotTaken',
    () async {
      final c = makeContainer();
      final ctrl = await toReview(c);
      // Another customer took 08:30 meanwhile.
      spots.seedSpotDay(
        const SpotDay(
          scheduleId: spotBookingScheduleId,
          day: spotBookingDay1,
          taken: [SpotInterval(start: '08:30', end: '10:30')],
        ),
      );
      bookings.nextError = BookingErrorCode.slotTaken;
      await ctrl.submit();
      await settle();

      final s = read(c, pkgArgs);
      expect(s.error, BookingErrorCode.slotTaken);
      expect(s.step, BookingStep.datetime);
      expect(s.day, spotBookingDay1);
      expect(s.start, isNull);
      expect(s.phase, SubmitPhase.idle);
      expect(s.availableStarts(today), ['06:00']);
    },
  );

  test('slot_taken in the slot path closes the sheet with slotTakenError', () async {
    final c = makeContainer();
    final ctrl = await open(c, slotArgs);
    bookings.nextError = BookingErrorCode.slotTaken;
    await ctrl.submit();
    await settle();

    final s = read(c, slotArgs);
    expect(s.error, BookingErrorCode.slotTaken);
    expect(s.step, BookingStep.review);
    expect(s.phase, SubmitPhase.idle);
  });

  test('outside_schedule reloads the context and returns to the date step', () async {
    final c = makeContainer();
    final ctrl = await toReview(c);
    // The provider dropped day 1 from the schedule.
    spots.seedSchedule(spotBookingSchedule(days: const [spotBookingDay2]));
    bookings.nextError = BookingErrorCode.outsideSchedule;
    await ctrl.submit();
    await settle();

    final s = read(c, pkgArgs);
    expect(s.error, BookingErrorCode.outsideSchedule);
    expect(s.step, BookingStep.datetime);
    expect(s.spot!.schedule.days, [spotBookingDay2]);
    expect(s.day, isNull);
    expect(s.start, isNull);
  });

  test('spot_archived closes with bookSpotArchived', () async {
    final c = makeContainer();
    final ctrl = await toReview(c);
    bookings.nextError = BookingErrorCode.spotArchived;
    await ctrl.submit();
    expect(read(c, pkgArgs).error, BookingErrorCode.spotArchived);

    final archived = makeContainer(archived: true);
    await open(archived, pkgArgs);
    expect(read(archived, pkgArgs).error, BookingErrorCode.spotArchived);
  });

  group('the sheet', () {
    testWidgets('slot_taken in the slot path closes it with slotTakenError', (
      tester,
    ) async {
      final repo = FakeBookingRepository()
        ..nextError = BookingErrorCode.slotTaken;
      await pumpBookingRoute(
        tester,
        path: spotBookingPath(start: '06:40'),
        bookings: repo,
        extraOverrides: [
          spotRepositoryProvider.overrideWithValue(spotBookingRepo()),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookingSheet), findsOneWidget);

      await tester.tap(find.text('Thanh toán 490.000₫'));
      await tester.pumpAndSettle();

      expect(find.byType(BookingSheet), findsNothing);
      expect(
        find.text('Suất này vừa có người đặt. Chọn suất khác.'),
        findsOneWidget,
      );
    });

    testWidgets('an archived spot closes it with bookSpotArchived', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: spotBookingPath(),
        extraOverrides: [
          spotRepositoryProvider.overrideWithValue(
            spotBookingRepo(archived: true),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(BookingSheet), findsNothing);
      expect(find.text('Điểm này không còn nhận lịch mới.'), findsOneWidget);
    });

    testWidgets('back from S04.03 in the slot path closes it', (tester) async {
      await pumpBookingRoute(
        tester,
        path: spotBookingPath(start: '06:40'),
        extraOverrides: [
          spotRepositoryProvider.overrideWithValue(spotBookingRepo()),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookingSheet), findsOneWidget);

      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      await nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(BookingSheet), findsNothing);
    });
  });
}
