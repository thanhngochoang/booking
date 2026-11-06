// test/features/booking/booking_day_price_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/booking/booking_day_price.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/steps/review_step.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/booking_world.dart';
import '../../support/day_price_packages.dart';
import '../../support/day_pricing_world.dart' show WithExceptions, weekendRule;
import '../../support/fake_addon_repository.dart';
import '../../support/fake_booking_repository.dart';
import '../../support/fake_price_rule_repository.dart';

/// Today is Fri 2026-11-06. An's series of `s1` (Chân dung, 1,5M): Cuối tuần
/// 1,8M on Sat and Sun, Mùa cưới 2M on 14/11 – 22/11 with 15/11 at 1,5M,
/// Tết Nguyên đán 2,5M from 23 Chạp to 5 Giêng (lunar).
void main() {
  final now = DateTime.utc(2026, 11, 6, 10);
  const saturday = '2026-11-07';
  const weddingSaturday = '2026-11-14';
  const exceptionDay = '2026-11-15';
  const weekday = '2026-11-12';
  const removedSaturday = '2026-11-28';

  // The Tết of 2027 (Sat 6/2 is 1 Giêng): 8/2 is the 3rd, a Monday.
  const tetDay = '2027-02-08';

  /// A weekend series at [price], replacing An's `r-weekend`.
  PriceRule weekendAt(int price) => PriceRule(
    id: 'r-weekend',
    serviceId: 's1',
    price: price,
    repeat: PriceRepeat.weekly,
    name: 'Cuối tuần',
    weekdays: weekendRule().weekdays,
  );

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
      'shows the range from the series and the button "Tiếp tục · từ 1.500.000₫"',
      (tester) async {
        await pumpBookingRoute(
          tester,
          packages: [dayPricePortrait, dayPriceCouple, dayPriceClass],
          priceRules: dayPriceRules(),
          now: now,
        );
        await tester.pumpAndSettle();

        // 1,5M base, 1,8M weekend, 2M season, 2,5M Tết.
        expect(find.text('1,5M–2,5M'), findsOneWidget);
        expect(find.textContaining('cuối tuần 1,8M'), findsOneWidget);
        // Only a season: "giá theo ngày".
        expect(find.text('3,2M–5M'), findsOneWidget);
        expect(find.textContaining('giá theo ngày'), findsOneWidget);
        // No series: the price in full, no sub-line.
        expect(find.text('6.000.000₫'), findsOneWidget);

        await tester.tap(find.text('Chân dung 2 giờ'));
        await tester.pumpAndSettle();
        expect(find.text('Tiếp tục · từ 1.500.000₫'), findsOneWidget);

        await tester.tap(find.text('Kỷ yếu cả lớp'));
        await tester.pumpAndSettle();
        expect(find.text('Tiếp tục · 6.000.000₫'), findsOneWidget);
      },
    );

    testWidgets('a one-off series that has passed is not in the range', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        packages: [dayPricePortrait],
        priceRules: [
          const PriceRule(
            id: 'r-old',
            serviceId: 's1',
            price: 4000000,
            repeat: PriceRepeat.none,
            name: 'Đã qua',
            from: '2026-10-01',
            to: '2026-10-05',
          ),
        ],
        now: now,
      );
      await tester.pumpAndSettle();

      expect(find.text('1.500.000₫'), findsOneWidget);
      expect(find.textContaining('4M'), findsNothing);
    });

    testWidgets('entering with a chosen Saturday shows 1.800.000₫', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1&day=$saturday',
        packages: [dayPricePortrait, dayPriceCouple],
        priceRules: dayPriceRules(),
        addons: [addonMakeup],
        now: now,
      );
      await tester.pumpAndSettle();

      // Opens on S04.01 because an add-on applies (Decision 11).
      expect(find.text('Tiếp tục · 1.800.000₫'), findsOneWidget);
      expect(find.textContaining('từ 1.800.000'), findsNothing);
      // Each package shows the price of that day, not its range.
      expect(find.text('1.800.000₫'), findsOneWidget);
      expect(find.text('3.200.000₫'), findsOneWidget);
      expect(find.textContaining('–'), findsNothing);
    });
  });

  group('S04.02', () {
    testWidgets(
      'shows the short price under the days that differ and the name on the '
      'first day of a series',
      (tester) async {
        final h = tester.ensureSemantics();
        await pumpBookingRoute(
          tester,
          path: '/u/p1/book?serviceId=s1',
          packages: [dayPricePortrait],
          priceRules: dayPriceRules(),
          now: now,
        );
        await tester.pumpAndSettle();

        expect(find.text('Ngày thường 1,5M'), findsOneWidget);
        // The weekend series: its first day carries the name ("Cuối tuần 1,8M"
        // does not fit a cell, so the first word), the next day the price.
        expect(
          find.bySemanticsLabel('7 tháng 11, rảnh, Cuối 1,8M'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('8 tháng 11, rảnh, 1,8M'), findsOneWidget);
        // 14/11 starts the season (it beats the weekend series).
        expect(
          find.bySemanticsLabel('14 tháng 11, rảnh, Mùa cưới 2M'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('16 tháng 11, rảnh, 2M'), findsOneWidget);
        // 15/11 costs the base price (exception): no note. 21/11 is a Saturday
        // inside the season: the season wins.
        expect(find.bySemanticsLabel('15 tháng 11, rảnh'), findsOneWidget);
        expect(find.bySemanticsLabel('21 tháng 11, rảnh, 2M'), findsOneWidget);
        // A plain weekday.
        expect(find.bySemanticsLabel('12 tháng 11, rảnh'), findsOneWidget);

        // Tết 2027 starts on 23 Chạp = Sat 30/1: "Tết Nguyên đán" is too long
        // for a cell, so its first word.
        await tester.tap(find.byTooltip('Tháng sau'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Tháng sau'));
        await tester.pumpAndSettle();
        expect(find.text('Tháng 1'), findsOneWidget);
        expect(
          find.bySemanticsLabel('30 tháng 1, rảnh, Tết 2,5M'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('31 tháng 1, rảnh, 2,5M'), findsOneWidget);
        h.dispose();
      },
    );

    testWidgets('a package without series has no price line', (tester) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s3',
        packages: [dayPriceClass],
        priceRules: dayPriceRules(),
        now: now,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Ngày thường'), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 8.5),
        findsNothing,
      );
    });

    testWidgets('button and day line follow the chosen day', (tester) async {
      final h = tester.ensureSemantics();
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        packages: [dayPricePortrait],
        priceRules: dayPriceRules(),
        now: now,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · từ 1.500.000₫'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('7 tháng 11, rảnh, Cuối 1,8M'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 1.800.000₫'), findsOneWidget);
      expect(
        find.textContaining('T7 7/11 · Cuối tuần · 1.800.000₫'),
        findsOneWidget,
      );

      // A base-price day: the plain day line, no series name.
      await tester.tap(find.bySemanticsLabel('12 tháng 11, rảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 1.500.000₫'), findsOneWidget);
      expect(find.textContaining('Cuối tuần ·'), findsNothing);
      expect(find.textContaining('Mùa cưới ·'), findsNothing);

      await tester.tap(find.bySemanticsLabel('14 tháng 11, rảnh, Mùa cưới 2M'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 2.000.000₫'), findsOneWidget);
      expect(
        find.textContaining('T7 14/11 · Mùa cưới · 2.000.000₫'),
        findsOneWidget,
      );
      h.dispose();
    });

    testWidgets('a day with an exception is priced by it', (tester) async {
      final h = tester.ensureSemantics();
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        packages: [dayPricePortrait],
        priceRules: [
          weekendRule(serviceId: 's1').withExceptions({'2026-11-07': 1700000}),
        ],
        now: now,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('7 tháng 11, rảnh, Cuối 1,7M'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 1.700.000₫'), findsOneWidget);
      h.dispose();
    });

    testWidgets('a series changing under the customer updates the price', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      final world = await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        packages: [dayPricePortrait],
        priceRules: [weekendRule(serviceId: 's1')],
        now: now,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('7 tháng 11, rảnh, Cuối 1,8M'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 1.800.000₫'), findsOneWidget);

      world.priceRules.seed(weekendAt(2200000));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục · 2.200.000₫'), findsOneWidget);
      h.dispose();
    });

    testWidgets('a failed read blocks the day until a retry works', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      final failing = FakePriceRuleRepository(today: () => now)
        ..failWatch = true;
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        packages: [dayPricePortrait],
        priceRuleRepository: failing,
        now: now,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('7 tháng 11, rảnh'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book-rules-failed')), findsOneWidget);
      final blocked = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Tiếp tục · 1.500.000₫'),
      );
      expect(blocked.onPressed, isNull);

      failing
        ..failWatch = false
        ..seed(weekendRule(serviceId: 's1'));
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('book-rules-failed')), findsNothing);
      expect(find.text('Tiếp tục · 1.800.000₫'), findsOneWidget);
      h.dispose();
    });
  });

  group('S04.03', () {
    testWidgets('line reads "Gói Chân dung 2 giờ · T7 14/11 (Mùa cưới)"', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1&day=$weddingSaturday',
        packages: [dayPricePortrait],
        priceRules: dayPriceRules(),
        now: now,
      );
      await tester.pumpAndSettle();
      await pickStartAndGoToReview(tester, '15:30', 'Tiếp tục · 2.000.000₫');

      expect(find.byType(ReviewStep), findsOneWidget);
      expect(
        find.text('Gói Chân dung 2 giờ · T7 14/11 (Mùa cưới)'),
        findsOneWidget,
      );
      expect(find.text('2.000.000₫'), findsWidgets);
      expect(
        find.textContaining('Giá theo ngày chụp bạn chọn.'),
        findsOneWidget,
      );
    });

    testWidgets('a series without a name reads "(giá theo ngày)"', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1&day=2026-11-18',
        packages: [dayPricePortrait],
        priceRules: [unnamedRule()],
        now: now,
      );
      await tester.pumpAndSettle();
      await pickStartAndGoToReview(tester, '15:30', 'Tiếp tục · 2.000.000₫');

      expect(
        find.text('Gói Chân dung 2 giờ · T4 18/11 (giá theo ngày)'),
        findsOneWidget,
      );
    });

    testWidgets('a base-price day of a package with series has no reason', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1&day=$weekday',
        packages: [dayPricePortrait],
        priceRules: dayPriceRules(),
        now: now,
      );
      await tester.pumpAndSettle();
      await pickStartAndGoToReview(tester, '15:30', 'Tiếp tục · 1.500.000₫');

      expect(find.text('Gói Chân dung 2 giờ · T5 12/11'), findsOneWidget);
    });

    testWidgets('a package without series keeps "Gói {name}" and no day note', (
      tester,
    ) async {
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s3&day=$saturday',
        packages: [dayPriceClass],
        priceRules: dayPriceRules(),
        now: now,
      );
      await tester.pumpAndSettle();
      await pickStartAndGoToReview(tester, '06:00', 'Tiếp tục · 6.000.000₫');

      expect(find.text('Gói Kỷ yếu cả lớp'), findsOneWidget);
      expect(find.textContaining('Giá theo ngày chụp bạn chọn.'), findsNothing);
    });
  });

  group('calendar notes', () {
    final l = AppLocalizationsVi();
    final series = anSeries();

    Map<DateTime, String> notes(int year, int month) => {
      for (final e in dayPriceNotes(
        l,
        base: 1500000,
        serviceId: 's1',
        rules: series,
        month: DateTime.utc(year, month),
      ).entries)
        e.key: e.value.text,
    };

    test('every note is in accent', () {
      final all = dayPriceNotes(
        l,
        base: 1500000,
        serviceId: 's1',
        rules: series,
        month: DateTime.utc(2026, 11),
      );
      expect(all.values.every((n) => n.accent), isTrue);
    });

    test(
      'a series that goes on into the next month names its first day only',
      () {
        // Tết 2027 runs Sat 30/1 to Wed 10/2.
        final jan = notes(2027, 1);
        final feb = notes(2027, 2);
        expect(jan[DateTime.utc(2027, 1, 30)], 'Tết 2,5M');
        expect(jan[DateTime.utc(2027, 1, 31)], '2,5M');
        expect(feb[DateTime.utc(2027, 2, 1)], '2,5M');
        expect(feb[DateTime.utc(2027, 2, 10)], '2,5M');
        // The day after is a plain weekday again.
        expect(feb.containsKey(DateTime.utc(2027, 2, 11)), isFalse);
        // Sat 13/2 is a weekend day again (the weekly series restarts).
        expect(feb[DateTime.utc(2027, 2, 13)], 'Cuối 1,8M');
      },
    );

    test('a package without series has no notes', () {
      expect(
        dayPriceNotes(
          l,
          base: 6000000,
          serviceId: 's3',
          rules: series,
          month: DateTime.utc(2026, 11),
        ),
        isEmpty,
      );
    });

    test('the name stays whole when it fits the cell, else its first word', () {
      PriceRule named(String? name) => PriceRule(
        id: 'r',
        serviceId: 's1',
        price: 2000000,
        repeat: PriceRepeat.none,
        name: name,
        from: '2026-11-18',
        to: '2026-11-18',
      );
      expect(ruleCellName(l, named('Tết'), '2,5M'), 'Tết');
      expect(ruleCellName(l, named('Mùa cưới'), '2M'), 'Mùa cưới');
      expect(ruleCellName(l, named('Tết Nguyên đán'), '2,5M'), 'Tết');
      expect(ruleCellName(l, named('Cuối tuần'), '1,8M'), 'Cuối');
      // No name: "Giá riêng" like everywhere else, shortened the same way.
      expect(ruleCellName(l, named(null), '2M'), 'Giá riêng');
      expect(ruleCellName(l, named(null), '2,5M'), 'Giá');
    });
  });

  group('the price on a booking', () {
    final l = AppLocalizationsVi();

    BookingServiceSnapshot snapshot({
      PriceKind kind = PriceKind.base,
      String? name,
    }) => BookingServiceSnapshot(
      name: 'Chân dung 2 giờ',
      price: 2500000,
      durationMinutes: 120,
      priceKind: kind,
      ruleName: name,
    );

    test('names the series the server wrote: "(Tết)"', () {
      expect(
        snapshotPriceReason(l, snapshot(kind: PriceKind.rule, name: 'Tết')),
        '(Tết)',
      );
    });

    test('a series without a name: "(giá theo ngày)"', () {
      expect(
        snapshotPriceReason(l, snapshot(kind: PriceKind.rule)),
        '(giá theo ngày)',
      );
      expect(
        snapshotPriceReason(l, snapshot(kind: PriceKind.rule, name: '  ')),
        '(giá theo ngày)',
      );
    });

    test('the base price says nothing, even with an old name', () {
      expect(snapshotPriceReason(l, snapshot()), isNull);
      expect(snapshotPriceReason(l, snapshot(name: 'Tết')), isNull);
    });
  });

  group('the flow prices the day like the server', () {
    late FakeBookingRepository bookings;
    late FakePriceRuleRepository rulesRepo;

    ProviderContainer makeContainer({List<PriceRule>? rules}) {
      bookings = FakeBookingRepository();
      rulesRepo = FakePriceRuleRepository(today: () => now);
      for (final r in rules ?? anSeries()) {
        rulesRepo.seed(r);
      }
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
          priceRuleRepositoryProvider.overrideWithValue(rulesRepo),
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

    // Review Focus 1: the app sends what the server charges for the same day.
    final cases =
        <({String name, String day, int price, List<PriceRule>? rules})>[
          (name: 'a Tết day', day: tetDay, price: 2500000, rules: null),
          (
            name: 'a Saturday of the weekend series',
            day: saturday,
            price: 1800000,
            rules: null,
          ),
          (
            name: 'a Saturday inside the season',
            day: weddingSaturday,
            price: 2000000,
            rules: null,
          ),
          (
            name: '15/11, the exception inside the season',
            day: exceptionDay,
            price: 1500000,
            rules: null,
          ),
          (name: 'a weekday', day: weekday, price: 1500000, rules: null),
          (
            name: 'a Saturday removed from the weekend series by an exception',
            day: removedSaturday,
            price: 1500000,
            rules: [
              weekendRule(serviceId: 's1')
                  .withExceptions({removedSaturday: null}),
              ...anSeries().skip(1),
            ],
          ),
        ];
    for (final c in cases) {
      test(
        'createBooking receives expectedPrice ${c.price} for ${c.name}',
        () async {
          final container = makeContainer(rules: c.rules);
          final ctrl = await open(container);
          await toReview(ctrl, c.day);
          await ctrl.submit();

          final call = bookings.createCalls.single;
          expect(call.day, c.day);
          expect(call.expectedPrice, c.price);
          // The same function and data the server runs.
          expect(
            call.expectedPrice,
            priceForDay(
              1500000,
              's1',
              c.rules ?? anSeries(),
              parseDayKey(c.day)!,
            ).amount,
          );
          expect(call.expectedTotal, isNull);
        },
      );
    }

    test('a Tết day of a year nobody entered anything for is priced', () async {
      final c = makeContainer();
      final ctrl = await open(c);
      await toReview(ctrl, '2030-02-05');
      expect(read(c).dayPrice?.amount, 2500000);
      expect(read(c).dayPrice?.rule?.name, 'Tết Nguyên đán');
    });

    test(
      'expectedPrice and expectedTotal follow the day and the add-ons',
      () async {
        final c = makeContainer();
        final ctrl = await open(c);
        await toReview(ctrl, tetDay, addonQty: 1);
        expect(read(c).totalVnd, 2500000 + 800000);
        await ctrl.submit();

        final call = bookings.createCalls.single;
        expect(call.expectedPrice, 2500000);
        expect(call.expectedTotal, 3300000);
      },
    );

    test(
      'the day price is recomputed when the package or the day changes',
      () async {
        final c = makeContainer(rules: [...anSeries(), coupleSeason()]);
        final ctrl = await open(c);
        ctrl.selectService(dayPricePortrait);
        expect(read(c).dayPrice, isNull);
        expect(read(c).totalVnd, 1500000);
        expect(read(c).priceIsFrom, isTrue);

        ctrl.selectDay(saturday);
        await settle();
        expect(read(c).dayPrice?.amount, 1800000);
        expect(read(c).priceIsFrom, isFalse);
        ctrl.selectService(dayPriceCouple);
        // The couple package has no weekend series: its base price.
        expect(read(c).dayPrice?.amount, 3200000);
        ctrl.selectDay(weddingSaturday);
        expect(read(c).dayPrice?.amount, 5000000);
        expect(read(c).dayPrice?.rule?.id, 'r-couple');
      },
    );

    test('a day has no price until the series are read', () async {
      final c = makeContainer();
      final sub = c.listen(bookingFlowControllerProvider(args), (_, _) {});
      addTearDown(sub.close);
      final ctrl = c.read(bookingFlowControllerProvider(args).notifier);
      ctrl.selectService(dayPricePortrait);
      ctrl.next();
      ctrl.selectDay(saturday);
      ctrl.selectStart('15:30');
      // Not read yet: the day cannot be priced, so it cannot go on.
      expect(read(c).dayPrice, isNull);
      expect(read(c).dayPriceReady, isFalse);
      expect(read(c).canContinue, isFalse);
      await settle();
      expect(read(c).dayPrice?.amount, 1800000);
      expect(read(c).canContinue, isTrue);
    });

    test('a failed read blocks the day until a retry works', () async {
      final c = makeContainer();
      rulesRepo.failWatch = true;
      final ctrl = await open(c);
      ctrl.selectService(dayPricePortrait);
      ctrl.next();
      ctrl.selectDay(saturday);
      await settle();
      expect(read(c).rulesFailed, isTrue);
      expect(read(c).dayPrice, isNull);
      ctrl.selectStart('15:30');
      expect(read(c).canContinue, isFalse);

      rulesRepo.failWatch = false;
      ctrl.retryRules();
      await settle();
      expect(read(c).rulesFailed, isFalse);
      expect(read(c).dayPrice?.amount, 1800000);
      expect(read(c).canContinue, isTrue);
    });

    test('a series edited under the customer changes the price and raises the banner', () async {
      final c = makeContainer();
      final ctrl = await open(c);
      ctrl.selectService(dayPricePortrait);
      ctrl.selectDay(saturday);
      await settle();
      expect(read(c).packageVnd, 1800000);
      expect(read(c).priceChanged, isFalse);

      rulesRepo.seed(weekendAt(2200000));
      await settle();
      expect(read(c).packageVnd, 2200000);
      expect(read(c).priceChanged, isTrue);
    });

    test('a price_changed answer reads the series again', () async {
      final c = makeContainer();
      final ctrl = await open(c);
      await toReview(ctrl, saturday);
      expect(read(c).dayPrice?.amount, 1800000);

      // The photographer moved the weekend price while the customer paid.
      rulesRepo.seed(weekendAt(2200000));
      bookings.nextError = BookingErrorCode.priceChanged;
      await ctrl.submit();
      expect(read(c).error, BookingErrorCode.priceChanged);
      expect(read(c).step, BookingStep.service);
      await settle();

      expect(read(c).dayPrice?.amount, 2200000);
      // The retry sends the new price.
      ctrl.next();
      ctrl.next();
      ctrl.next();
      await ctrl.submit();
      expect(bookings.createCalls.last.expectedPrice, 2200000);
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
