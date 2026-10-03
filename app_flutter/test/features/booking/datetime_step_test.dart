// test/features/booking/datetime_step_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/steps/datetime_step.dart';

import '../../support/booking_world.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5);
  final bookedDay = DateTime.utc(2026, 10, 10);
  final pendingDay = DateTime.utc(2026, 10, 11);
  final offDay = DateTime.utc(2026, 10, 12);
  final freeDay = DateTime.utc(2026, 10, 15);

  final testDays = {
    bookedDay: AvailabilityDay(day: bookedDay, state: DayState.booked),
    pendingDay: AvailabilityDay(day: pendingDay, state: DayState.pending),
    offDay: AvailabilityDay(day: offDay, state: DayState.off),
  };

  testWidgets('free days are selectable; booked, off and past days are not', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s1',
      days: testDays,
      now: now,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScreenCode), findsWidgets);
    expect(find.text('Tháng 10'), findsOneWidget);

    // Past day (Oct 3) cannot be selected
    await tester.tap(find.bySemanticsLabel('3 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('khung 2 giờ'), findsNothing);

    // Booked day (Oct 10) cannot be selected
    await tester.tap(find.bySemanticsLabel('10 tháng 10, đã đặt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('khung 2 giờ'), findsNothing);

    // Off day (Oct 12) cannot be selected
    await tester.tap(find.bySemanticsLabel('12 tháng 10, nghỉ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('khung 2 giờ'), findsNothing);

    // Free day (Oct 15) is selectable
    await tester.tap(find.bySemanticsLabel('15 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('khung 2 giờ'), findsOneWidget);

    h.dispose();
  });

  testWidgets('a pending day is not selectable and shows 1 người đang chờ', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s1',
      days: testDays,
      now: now,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('11 tháng 10, chờ nhận'));
    await tester.pumpAndSettle();

    // Not selected
    expect(find.textContaining('khung 2 giờ'), findsNothing);
    // Shows waiting message
    expect(find.text('1 người đang chờ'), findsOneWidget);

    h.dispose();
  });

  testWidgets('selecting a day shows the slot chips for the package duration', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s1',
      days: testDays,
      now: now,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('15 tháng 10, rảnh'));
    await tester.pumpAndSettle();

    // 120 minutes -> slots from 06:00 to 18:00 (25 slots)
    expect(find.byType(AppChip), findsNWidgets(25));
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('18:30'), findsNothing);

    // Now test a 480 minute (8h) package -> latest start 12:00
    const longPackage = ServiceSummary(
      id: 's_long',
      photographerId: 'p1',
      name: 'Gói Cả Ngày',
      priceVnd: 6000000,
      durationMinutes: 480,
      active: true,
    );

    await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s_long',
      packages: [longPackage],
      days: testDays,
      now: now,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('15 tháng 10, rảnh'));
    await tester.pumpAndSettle();

    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('12:30'), findsNothing);

    h.dispose();
  });

  testWidgets('choosing a chip shows 15:30–17:30 and enables Tiếp tục', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s1',
      days: testDays,
      now: now,
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byType(AppButton);
    expect(tester.widget<AppButton>(buttonFinder).onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('15 tháng 10, rảnh'));
    await tester.pumpAndSettle();

    expect(tester.widget<AppButton>(buttonFinder).onPressed, isNull);

    // Choose 15:30 slot
    await tester.ensureVisible(find.text('15:30'));
    await tester.tap(find.text('15:30'));
    await tester.pumpAndSettle();

    expect(find.text('15:30–17:30'), findsOneWidget);
    expect(tester.widget<AppButton>(buttonFinder).onPressed, isNotNull);

    h.dispose();
  });

  testWidgets('the day from S02.06 is preselected and its month shown', (
    tester,
  ) async {
    await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s1&date=2026-11-20',
      now: now,
    );
    await tester.pumpAndSettle();

    expect(find.text('Tháng 11'), findsOneWidget);
    expect(find.textContaining('khung 2 giờ'), findsOneWidget);
  });

  testWidgets('moving to next month loads that month', (tester) async {
    final handles = await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s1',
      now: now,
    );
    await tester.pumpAndSettle();

    expect(find.text('Tháng 10'), findsOneWidget);

    final nextMonthFinder = find.byTooltip('Tháng sau');
    expect(nextMonthFinder, findsOneWidget);

    await tester.tap(nextMonthFinder);
    await tester.pumpAndSettle();

    expect(find.text('Tháng 11'), findsOneWidget);
    // Fake repo was watched for the new month
    expect(handles.availRepo.watchers, greaterThanOrEqualTo(1));
  });

  testWidgets(
    'a chosen day that becomes pending is cleared with Hôm đó vừa có người đặt',
    (tester) async {
      final h = tester.ensureSemantics();
      final handles = await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        days: testDays,
        now: now,
      );
      await tester.pumpAndSettle();

      // Select Oct 15
      await tester.tap(find.bySemanticsLabel('15 tháng 10, rảnh'));
      await tester.pumpAndSettle();

      // Select 15:30
      await tester.ensureVisible(find.text('15:30'));
      await tester.tap(find.text('15:30'));
      await tester.pumpAndSettle();

      expect(find.text('15:30–17:30'), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );

      // Now seed that Oct 15 became pending
      handles.availRepo.seed(
        'p1',
        AvailabilityDay(day: freeDay, state: DayState.pending),
      );
      await tester.pumpAndSettle();

      // Start cleared, button disabled, SnackBar shown
      expect(find.text('15:30–17:30'), findsNothing);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
      expect(
        find.text('Hôm đó vừa có người đặt, chọn ngày khác'),
        findsOneWidget,
      );

      h.dispose();
    },
  );

  testWidgets('days refused with day_taken are crossed', (tester) async {
    final h = tester.ensureSemantics();
    await pumpBookingRoute(tester, path: '/u/p1/book?serviceId=s1', now: now);
    await tester.pumpAndSettle();

    // Mark Oct 15 as taken in controller
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DateTimeStep)),
    );
    const args = BookingFlowArgs(photographerId: 'p1', serviceId: 's1');
    container
        .read(bookingFlowControllerProvider(args).notifier)
        .clearDay('2026-10-15', taken: true);
    await tester.pumpAndSettle();

    // Oct 15 is now DayState.booked in calendar states -> semantics label has "đã đặt"
    expect(find.bySemanticsLabel('15 tháng 10, đã đặt'), findsOneWidget);

    h.dispose();
  });

  testWidgets('first load shows AvailabilityCalendar.skeleton', (tester) async {
    final completer = Completer<Map<DateTime, AvailabilityDay>>();
    await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s1',
      extraOverrides: [
        availabilityMonthProvider((uid: 'p1', month: DateTime.utc(2026, 10)))
            .overrideWith((ref) => completer.future.asStream()),
      ],
      now: now,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byType(AsyncView<Map<DateTime, AvailabilityDay>>),
      findsOneWidget,
    );
  });

  testWidgets('calendar error shows retry; retry resubscribes', (tester) async {
    var shouldFail = true;
    await pumpBookingRoute(
      tester,
      path: '/u/p1/book?serviceId=s1',
      extraOverrides: [
        availabilityMonthProvider((uid: 'p1', month: DateTime.utc(2026, 10)))
            .overrideWith((ref) {
              if (shouldFail) {
                return Stream.error(Exception('Calendar load failure'));
              }
              return Stream.value(testDays);
            }),
      ],
      now: now,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.byType(AvailabilityCalendar), findsOneWidget);
  });

  testWidgets(
    '320 dp, 1.3× text, light and dark: chips wrap, nothing overflows',
    (tester) async {
      const size = Size(320, 640);
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          const SizedBox(),
        ); // fresh ProviderScope per pass
        await pumpBookingRoute(
          tester,
          path: '/u/p1/book?serviceId=s1&day=2026-10-15',
          days: {
            DateTime.utc(2026, 10, 15): AvailabilityDay(
              day: DateTime.utc(2026, 10, 15),
              state: DayState.free,
            ),
          },
          brightness: brightness,
          textScale: 1.3,
          now: now,
          viewSize: size,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(const Key('app-sheet'))).width, 320);
        expect(find.byType(DateTimeStep), findsOneWidget);
        // The day is preselected, so the slot chips are laid out and must wrap.
        expect(find.widgetWithText(AppChip, '06:00'), findsOneWidget);
        expect(find.byType(AppButton), findsOneWidget);
      }
    },
  );
}
