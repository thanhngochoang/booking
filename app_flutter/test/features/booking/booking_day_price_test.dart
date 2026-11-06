// test/features/booking/booking_day_price_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/data/pricing/special_days.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/steps/review_step.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

import '../../support/booking_world.dart';
import '../../support/day_price_packages.dart';
import '../../support/fake_addon_repository.dart';
import '../../support/fake_booking_repository.dart';

/// 2026-11-14 is a Saturday, 2026-11-17 a Tuesday that is a special day.
void main() {
  final now = DateTime.utc(2026, 11, 6, 10);
  const saturday = '2026-11-14';
  const specialTuesday = '2026-11-17';

  /// S04.02: a start time, then S04.04's place, then S04.03.
  Future<void> pickStartAndGoToReview(
    WidgetTester tester,
    String start,
    String button,
  ) async {
    Future<void> tapVisible(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await tapVisible(find.widgetWithText(AppChip, start));
    await tapVisible(find.widgetWithText(AppButton, button));
    await tester.enterText(find.byType(TextField), 'Bến Bạch Đằng');
    await tester.pumpAndSettle();
    await tapVisible(find.widgetWithText(AppButton, button));
  }

  group('S04.01', () {
    testWidgets(
      'shows 1,5M–1,8M and "T7–CN 1,8M" and the button "Tiếp tục · từ 1.500.000₫"',
      (tester) async {
        await pumpBookingRoute(
          tester,
          packages: [dayPricePortrait, dayPriceCouple, dayPriceClass],
          now: now,
        );
        await tester.pumpAndSettle();

        expect(find.text('1,5M–1,8M'), findsOneWidget);
        expect(find.textContaining('T7–CN 1,8M'), findsOneWidget);
        expect(find.text('3,2M–4M'), findsOneWidget);
        expect(find.textContaining('giá theo ngày'), findsOneWidget);
        // One price: in full, no sub-line.
        expect(find.text('6.000.000₫'), findsOneWidget);

        await tester.tap(find.text('Chân dung 2 giờ'));
        await tester.pumpAndSettle();
        expect(find.text('Tiếp tục · từ 1.500.000₫'), findsOneWidget);

        // The special price never lowers or raises "từ".
        await tester.tap(find.text('Kỷ yếu cả lớp'));
        await tester.pumpAndSettle();
        expect(find.text('Tiếp tục · 6.000.000₫'), findsOneWidget);
      },
    );

    testWidgets('entering with a chosen Saturday shows 1.800.000₫', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1&day=$saturday',
        packages: [dayPricePortrait, dayPriceCouple],
        addons: [addonMakeup],
        now: now,
      );
      await tester.pumpAndSettle();

      // Opens on S04.01 because an add-on applies (Decision 11).
      expect(find.text('Tiếp tục · 1.800.000₫'), findsOneWidget);
      expect(find.textContaining('từ 1.800.000'), findsNothing);
    });
  });

  group('S04.02', () {
    testWidgets(
      'shows 1,8M under weekend days and "Lễ 2,2M" under 17/11, nothing for a single-price package',
      (tester) async {
        await pumpBookingRoute(
          tester,
          path: '/u/p1/book?serviceId=s1',
          packages: [dayPricePortrait],
          specialRanges: [dayPriceSpecialRange],
          now: now,
        );
        await tester.pumpAndSettle();

        expect(find.text('Ngày thường 1,5M'), findsOneWidget);
        // Weekends of November 2026 from the 7th (today is the 6th): 7, 8,
        // 14, 15, 21, 22, 28, 29. Past days carry no price.
        expect(find.text('1,8M'), findsNWidgets(8));
        expect(find.text('Lễ 2,2M'), findsOneWidget);

        await pumpBookingRoute(
          tester,
          path: '/u/p1/book?serviceId=s3',
          packages: [dayPriceClass],
          now: now,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Ngày thường'), findsNothing);
        // No small price line under any day.
        expect(
          find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 8.5),
          findsNothing,
        );
        expect(find.textContaining('Lễ'), findsNothing);
      },
    );

    testWidgets('button follows the selected day', (tester) async {
      final h = tester.ensureSemantics();
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        packages: [dayPricePortrait],
        specialRanges: [dayPriceSpecialRange],
        now: now,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · từ 1.500.000₫'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('14 tháng 11, rảnh, 1,8M'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 1.800.000₫'), findsOneWidget);
      expect(find.textContaining('cuối tuần'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('12 tháng 11, rảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 1.500.000₫'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('17 tháng 11, rảnh, Lễ 2,2M'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 2.200.000₫'), findsOneWidget);
      expect(find.textContaining('ngày lễ: Mùa cưới'), findsOneWidget);
      h.dispose();
    });

    testWidgets('a holiday of the public list is priced as a special day', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        packages: [dayPricePortrait],
        holidays: {
          2026: [const Holiday(day: '2026-11-18', name: 'Ngày Nhà giáo')],
        },
        now: now,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('18 tháng 11, rảnh, Lễ 2,2M'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 2.200.000₫'), findsOneWidget);
      expect(find.textContaining('ngày lễ: Ngày Nhà giáo'), findsOneWidget);
      h.dispose();
    });
  });

  group('S04.03', () {
    testWidgets('line reads "Gói Chân dung 2 giờ · T7 14/11 (cuối tuần)"', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1&day=$saturday',
        packages: [dayPricePortrait],
        now: now,
      );
      await tester.pumpAndSettle();
      await pickStartAndGoToReview(tester, '15:30', 'Tiếp tục · 1.800.000₫');

      expect(find.byType(ReviewStep), findsOneWidget);
      expect(
        find.text('Gói Chân dung 2 giờ · T7 14/11 (cuối tuần)'),
        findsOneWidget,
      );
      expect(find.text('1.800.000₫'), findsWidgets);
      expect(
        find.textContaining('Giá theo ngày chụp bạn chọn.'),
        findsOneWidget,
      );
    });

    testWidgets('a single-price package keeps "Gói {name}" and no day note', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s3&day=$saturday',
        packages: [dayPriceClass],
        now: now,
      );
      await tester.pumpAndSettle();
      await pickStartAndGoToReview(tester, '06:00', 'Tiếp tục · 6.000.000₫');

      expect(find.text('Gói Kỷ yếu cả lớp'), findsOneWidget);
      expect(find.textContaining('Giá theo ngày chụp bạn chọn.'), findsNothing);
    });
  });

  group('the flow prices the day like the server', () {
    late FakeBookingRepository bookings;
    late FakeHolidayRepository holidays;
    late FakeSpecialDayRepository ranges;
    HolidayRepository? holidayOverride;

    ProviderContainer makeContainer() {
      bookings = FakeBookingRepository();
      holidays = FakeHolidayRepository();
      ranges = FakeSpecialDayRepository()..seed('p1', dayPriceSpecialRange);
      final addonRepo = FakeAddonRepository()..seed(addonMakeup);
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          calendarTodayProvider.overrideWithValue(now),
          profilePackagesProvider('p1').overrideWithValue(
            const AsyncData([dayPricePortrait, dayPriceCouple]),
          ),
          currentContactProvider.overrideWithValue(
            const AsyncData(UserContact(phone: '+84912345678')),
          ),
          bookingRepositoryProvider.overrideWithValue(bookings),
          photographerPoolCacheProvider.overrideWithValue(
            FakePhotographerRepository(),
          ),
          addonRepositoryProvider.overrideWithValue(addonRepo),
          holidayRepositoryProvider.overrideWithValue(
            holidayOverride ?? holidays,
          ),
          specialDayRepositoryProvider.overrideWithValue(ranges),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    const args = BookingFlowArgs(photographerId: 'p1');

    Future<BookingFlowController> open(ProviderContainer c) async {
      final sub = c.listen(bookingFlowControllerProvider(args), (_, _) {});
      addTearDown(sub.close);
      await settle();
      return c.read(bookingFlowControllerProvider(args).notifier);
    }

    BookingFlowState read(ProviderContainer c) =>
        c.read(bookingFlowControllerProvider(args));

    Future<void> toReview(
      BookingFlowController ctrl,
      String day, {
      int addonQty = 0,
    }) async {
      ctrl.selectService(dayPricePortrait);
      if (addonQty > 0) ctrl.setAddonQty('a_makeup', addonQty);
      ctrl.next();
      ctrl.selectDay(day);
      await settle();
      ctrl.selectStart('15:30');
      ctrl.next();
      ctrl.setPlace('Bến Bạch Đằng');
      ctrl.next();
    }

    test('createBooking receives expectedPrice 1_800_000 for 14/11', () async {
      final c = makeContainer();
      final ctrl = await open(c);
      await toReview(ctrl, saturday);
      expect(read(c).dayPrice?.kind, DayPriceKind.weekend);
      await ctrl.submit();

      final call = bookings.createCalls.single;
      expect(call.day, saturday);
      expect(call.expectedPrice, 1800000);
      // The same rule and data the server runs.
      expect(
        call.expectedPrice,
        priceForDayKey(dayPricePortrait, saturday, noSpecialDays).amount,
      );
      expect(call.expectedTotal, isNull);
    });

    test(
      'expectedPrice and expectedTotal follow the day and the add-ons',
      () async {
        final c = makeContainer();
        final ctrl = await open(c);
        await toReview(ctrl, specialTuesday, addonQty: 1);
        expect(read(c).dayPrice, (
          amount: 2200000,
          kind: DayPriceKind.special,
          specialName: 'Mùa cưới',
        ));
        expect(read(c).totalVnd, 2200000 + 800000);
        await ctrl.submit();

        final call = bookings.createCalls.single;
        expect(call.expectedPrice, 2200000);
        expect(call.expectedTotal, 3000000);
      },
    );

    test('a weekday costs the weekday price', () async {
      final c = makeContainer();
      final ctrl = await open(c);
      await toReview(ctrl, '2026-11-12');
      await ctrl.submit();
      expect(bookings.createCalls.single.expectedPrice, 1500000);
    });

    test(
      'the day price is recomputed when the package or the day changes',
      () async {
        final c = makeContainer();
        final ctrl = await open(c);
        ctrl.selectService(dayPricePortrait);
        expect(read(c).dayPrice, isNull);
        expect(read(c).totalVnd, 1500000);
        expect(read(c).priceIsFrom, isTrue);

        ctrl.selectDay(saturday);
        await settle();
        expect(read(c).dayPrice?.amount, 1800000);
        ctrl.selectService(dayPriceCouple);
        expect(read(c).dayPrice?.amount, 4000000);
        ctrl.selectDay(specialTuesday);
        // No special price on this package: Tuesday is an ordinary weekday.
        expect(read(c).dayPrice, (
          amount: 3200000,
          kind: DayPriceKind.weekday,
          specialName: null,
        ));
      },
    );

    test(
      'a package with a special price has no price until the holidays load',
      () async {
        final c = makeContainer();
        final ctrl = await open(c);
        ctrl.selectService(dayPricePortrait);
        ctrl.next();
        ctrl.selectDay(saturday);
        // Before the read answers the day is not priced and cannot go on.
        expect(read(c).dayPrice, isNull);
        expect(read(c).dayPriceReady, isFalse);
        ctrl.selectStart('15:30');
        expect(read(c).canContinue, isFalse);
        await settle();
        expect(read(c).dayPrice?.amount, 1800000);
        expect(read(c).canContinue, isTrue);
      },
    );

    test('a failed holiday read blocks the day until a retry works', () async {
      holidayOverride = _FlakyHolidays();
      addTearDown(() => holidayOverride = null);
      final c = makeContainer();
      final flaky = holidayOverride! as _FlakyHolidays;
      final ctrl = await open(c);
      ctrl.selectService(dayPricePortrait);
      ctrl.next();
      ctrl.selectDay(saturday);
      await settle();
      expect(read(c).specialsFailed, isTrue);
      expect(read(c).dayPrice, isNull);
      ctrl.selectStart('15:30');
      expect(read(c).canContinue, isFalse);

      flaky.failing = false;
      ctrl.retrySpecials();
      await settle();
      expect(read(c).specialsFailed, isFalse);
      expect(read(c).dayPrice?.amount, 1800000);
    });

    test('a price_changed answer reads the special days again', () async {
      final c = makeContainer();
      final ctrl = await open(c);
      await toReview(ctrl, saturday);
      holidays.seed(2026, [const Holiday(day: saturday, name: 'Lễ mới')]);
      bookings.nextError = BookingErrorCode.priceChanged;
      await ctrl.submit();
      await settle();

      expect(read(c).error, BookingErrorCode.priceChanged);
      expect(read(c).step, BookingStep.service);
      // The day is now a special day for this package.
      expect(read(c).dayPrice?.amount, 2200000);
      expect(read(c).dayPrice?.specialName, 'Lễ mới');
    });

    test('a slot offer keeps its own price (P7)', () {
      const state = BookingFlowState(
        step: BookingStep.review,
        serviceId: 'offer1',
        priceVnd: 490000,
        day: saturday,
      );
      expect(state.dayPrice, isNull);
      expect(state.packageVnd, 490000);
      expect(state.dayPriceReady, isTrue);
    });
  });
}

class _FlakyHolidays implements HolidayRepository {
  bool failing = true;

  @override
  Future<List<Holiday>> forYear(int year) async {
    if (failing) throw StateError('offline');
    return const [];
  }
}
