// test/features/booking/review_step_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/steps/place_step.dart';
import 'package:photobooking/features/booking/steps/review_step.dart';

import '../../support/booking_world.dart';
import '../../support/spot_booking_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5);
  final freeDay = DateTime.utc(2026, 10, 15);
  final testDays = {
    freeDay: AvailabilityDay(day: freeDay, state: DayState.free),
  };

  const oddPackage = ServiceSummary(
    id: 's_odd',
    photographerId: 'p1',
    name: 'Gói Lẻ',
    priceVnd: 1234567,
    durationMinutes: 120,
    photoCount: 50,
    editedCount: 10,
    deliveryDays: 3,
    active: true,
  );

  Future<void> navigateToReviewStep(
    WidgetTester tester, {
    String path = '/u/p1/book?serviceId=s1',
    List<ServiceSummary>? packages,
    UserContact? contact = const UserContact(phone: '+84903123456'),
    List<Override> extraOverrides = const [],
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    Size viewSize = const Size(390, 844),
  }) async {
    await pumpBookingRoute(
      tester,
      path: path,
      packages: packages,
      days: testDays,
      now: now,
      contact: contact,
      extraOverrides: extraOverrides,
      brightness: brightness,
      textScale: textScale,
      viewSize: viewSize,
    );
    await tester.pumpAndSettle();

    // On DateTimeStep: select day 15 and first slot
    // Found by widget, not by the semantics tree: on a short screen the day
    // can sit below the scroll fold, where its semantics node is dropped.
    final day15 = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == '15 tháng 10, rảnh',
    );
    await tester.ensureVisible(day15);
    await tester.pumpAndSettle();
    await tester.tap(day15);
    await tester.pumpAndSettle();

    final slotChip = find.widgetWithText(AppChip, '06:00');
    await tester.ensureVisible(slotChip);
    await tester.tap(slotChip);
    await tester.pumpAndSettle();

    final continueBtn1 = find.widgetWithText(
      AppButton,
      'Tiếp tục · ${formatMoney(packages?.first.priceVnd ?? 1500000)}',
    );
    await tester.ensureVisible(continueBtn1);
    await tester.tap(continueBtn1);
    await tester.pumpAndSettle();

    expect(find.byType(PlaceStep), findsOneWidget);

    // On PlaceStep: enter place name
    final input = find.byType(TextField);
    await tester.enterText(input, 'Bến Bạch Đằng');
    await tester.pumpAndSettle();

    final continueBtn2 = find.widgetWithText(
      AppButton,
      'Tiếp tục · ${formatMoney(packages?.first.priceVnd ?? 1500000)}',
    );
    await tester.ensureVisible(continueBtn2);
    await tester.tap(continueBtn2);
    await tester.pumpAndSettle();

    expect(find.byType(ReviewStep), findsOneWidget);
  }

  testWidgets(
    'first load shows BookingCard.skeleton and MoneyBreakdown.skeleton when profile is loading',
    (tester) async {
      final profileCompleter = Completer<PhotographerProfile?>();
      await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        days: testDays,
        now: now,
        extraOverrides: [
          photographerProfileProvider('p1')
              .overrideWith((ref) => profileCompleter.future),
        ],
      );
      await tester.pumpAndSettle();

      // Navigate to Place then Review
      await tester.tap(find.bySemanticsLabel('15 tháng 10, rảnh'));
      await tester.pumpAndSettle();

      final slotChip = find.widgetWithText(AppChip, '06:00');
      await tester.ensureVisible(slotChip);
      await tester.tap(slotChip);
      await tester.pumpAndSettle();

      final continueBtn1 = find.widgetWithText(
        AppButton,
        'Tiếp tục · 1.500.000₫',
      );
      await tester.ensureVisible(continueBtn1);
      await tester.tap(continueBtn1);
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      await tester.enterText(input, 'Bến Bạch Đằng');
      await tester.pumpAndSettle();

      final continueBtn2 = find.widgetWithText(
        AppButton,
        'Tiếp tục · 1.500.000₫',
      );
      await tester.ensureVisible(continueBtn2);
      await tester.tap(continueBtn2);
      // Pump 1 frame to land on ReviewStep without resolving profileCompleter
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ReviewStep), findsOneWidget);
      // Find skeletons
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_BookingCardSkeleton',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_MoneyBreakdownSkeleton',
        ),
        findsOneWidget,
      );

      // Resolve profile
      profileCompleter.complete(bookingProfile);
      await tester.pumpAndSettle();

      expect(find.byType(BookingCard), findsOneWidget);
      expect(find.byType(MoneyBreakdown), findsOneWidget);
    },
  );

  testWidgets(
    'shows the summary card, note and phone side by side, price, the whole price up front and no remaining',
    (tester) async {
      await navigateToReviewStep(tester);

      expect(find.byType(BookingCard), findsOneWidget);
      expect(find.text('Minh Trí · Gói Chân Dung'), findsOneWidget);
      expect(find.text('Bến Bạch Đằng'), findsOneWidget);

      // Money breakdown: the whole price 1.500.000 is paid up front
      final upfront = depositFor(1500000);
      expect(upfront.deposit, 1500000);
      expect(upfront.remaining, 0);
      expect(find.text('1.500.000₫'), findsWidgets);

      // Phone field is prefilled with saved formatted phone: '903 123 456'
      final phoneFieldFinder = find.byType(PhoneField);
      expect(phoneFieldFinder, findsOneWidget);
      final phoneText = find.descendant(
        of: phoneFieldFinder,
        matching: find.byType(TextFormField),
      );
      expect(
        tester.widget<TextFormField>(phoneText).controller?.text,
        '903 123 456',
      );

      // The pay button carries the whole price
      expect(
        find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'money rows are "Gói Gói Chân Dung" and "Thanh toán 100%" with the full price',
    (tester) async {
      await navigateToReviewStep(tester);

      final rows = find.descendant(
        of: find.byType(MoneyBreakdown),
        matching: find.byType(Text),
      );
      expect(
        tester.widgetList<Text>(rows).map((t) => t.data).toList(),
        ['Gói Gói Chân Dung', '1.500.000₫', 'Thanh toán 100%', '1.500.000₫'],
      );
    },
  );

  testWidgets('no "cọc" or "Còn lại" text anywhere', (tester) async {
    await navigateToReviewStep(tester);

    expect(find.textContaining('cọc'), findsNothing);
    expect(find.textContaining('Cọc'), findsNothing);
    expect(find.textContaining('Còn lại'), findsNothing);
  });

  testWidgets('the whole price is paid up front for an odd price', (
    tester,
  ) async {
    final oddMath = depositFor(1234567);
    expect(oddMath.deposit, 1234567);
    expect(oddMath.remaining, 0);

    await navigateToReviewStep(
      tester,
      path: '/u/p1/book?serviceId=s_odd',
      packages: [oddPackage],
    );

    expect(find.text('1.234.567₫'), findsWidgets);
    expect(
      find.widgetWithText(AppButton, 'Thanh toán 1.234.567₫'),
      findsOneWidget,
    );
  });

  testWidgets('the helper is the mock sentence, with no separate escrow notice', (
    tester,
  ) async {
    await navigateToReviewStep(tester);

    expect(find.byType(EscrowNotice), findsNothing);
    expect(
      find.text(
        'Tiền được giữ tới khi bạn nhận ảnh, chuyển cho thợ theo 2 mốc. Huỷ trước 48 giờ hoàn 100% số đã trả.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the note counter counts graphemes and stops at 300', (
    tester,
  ) async {
    await navigateToReviewStep(tester);

    final noteFieldFinder = find.byKey(const Key('book-note-field'));
    expect(noteFieldFinder, findsOneWidget);

    expect(find.text('0/300'), findsOneWidget);

    await tester.enterText(noteFieldFinder, 'Xin chào');
    await tester.pumpAndSettle();
    expect(find.text('8/300'), findsOneWidget);

    final longNote = 'A' * 350;
    await tester.enterText(noteFieldFinder, longNote);
    await tester.pumpAndSettle();
    expect(find.text('300/300'), findsOneWidget);
  });

  testWidgets(
    'an invalid phone shows the error on focus loss and disables the pay button',
    (tester) async {
      await navigateToReviewStep(tester);

      final phoneFinder = find.descendant(
        of: find.byType(PhoneField),
        matching: find.byType(TextFormField),
      );

      // Clear phone or type invalid
      await tester.tap(phoneFinder);
      await tester.enterText(phoneFinder, '12345');
      await tester.pumpAndSettle();

      // Focus out by tapping on note field
      final noteField = find.byKey(const Key('book-note-field'));
      await tester.tap(noteField);
      await tester.pumpAndSettle();

      expect(
        find.text('Số điện thoại chưa đúng. Ví dụ: 903 123 456'),
        findsOneWidget,
      );

      final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
      expect(tester.widget<AppButton>(payBtn).onPressed, isNull);
    },
  );

  testWidgets(
    'Chuyển khoản QR is selected by default; tapping MoMo selects it',
    (tester) async {
      await navigateToReviewStep(tester);

      expect(find.byType(PayMethodSelector), findsOneWidget);
      PayMethodSelector selector() =>
          tester.widget<PayMethodSelector>(find.byType(PayMethodSelector));
      expect(selector().value, PayMethod.bankQr);

      final momo = find.text('MoMo');
      await tester.ensureVisible(momo);
      await tester.tap(momo);
      await tester.pumpAndSettle();

      expect(selector().value, PayMethod.momo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReviewStep)),
      );
      expect(
        container
            .read(
              bookingFlowControllerProvider(
                const BookingFlowArgs(photographerId: 'p1', serviceId: 's1'),
              ),
            )
            .method,
        PayMethod.momo,
      );
    },
  );

  testWidgets(
    'while submitting the button shows loading and the form ignores taps',
    (tester) async {
      await navigateToReviewStep(tester);

      // Simulate controller phase: creating
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReviewStep)),
      );
      final controller = container.read(
        bookingFlowControllerProvider(
          const BookingFlowArgs(photographerId: 'p1', serviceId: 's1'),
        ).notifier,
      );

      // Note: since submit() is Task 6, test controller state directly or set state
      controller.state = controller.state.copyWith(phase: SubmitPhase.creating);
      await tester.pump();

      final payBtn = tester.widget<AppButton>(find.byType(AppButton));
      expect(payBtn.loading, isTrue);

      // Form is inside AbsorbPointer which is absorbing
      final absorbFinder = find.descendant(
        of: find.byType(ReviewStep),
        matching: find.byWidgetPredicate(
          (w) => w is AbsorbPointer && w.absorbing,
        ),
      );
      expect(absorbFinder, findsOneWidget);
    },
  );

  testWidgets(
    '320 dp and 1.3× text, light and dark: the two fields keep equal height and nothing overflows',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        // A fresh tree per pass: pumping the router again would keep the
        // previous pass's ProviderScope and flow state.
        await tester.pumpWidget(const SizedBox());
        await navigateToReviewStep(
          tester,
          brightness: brightness,
          textScale: 1.3,
          viewSize: const Size(320, 640),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(PayMethodSelector), findsOneWidget);
        expect(tester.getSize(find.byKey(const Key('app-sheet'))).width, 320);

        final note = find.byKey(const Key('book-note-field'));
        final phone = find.byType(PhoneField);
        expect(note, findsOneWidget);
        expect(phone, findsOneWidget);
        expect(
          find.ancestor(of: phone, matching: find.byType(IntrinsicHeight)),
          findsOneWidget,
        );
        expect(tester.getSize(note).height, tester.getSize(phone).height);
      }
    },
  );

  group('S04.03 with add-ons', () {
    Future<void> toReview(
      WidgetTester tester, {
      int makeup = 2,
      bool car = true,
    }) async {
      await pumpBookingRoute(
        tester,
        packages: [bookingPortrait2h],
        addons: [addonMakeup, addonTransport],
        days: testDays,
        now: now,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < makeup; i++) {
        await tester.ensureVisible(find.byKey(const Key('addon-a_makeup-plus')));
        await tester.tap(find.byKey(const Key('addon-a_makeup-plus')));
        await tester.pump();
      }
      if (car) {
        await tester.ensureVisible(find.byKey(const Key('addon-a_car-check')));
        await tester.tap(find.byKey(const Key('addon-a_car-check')));
        await tester.pump();
      }
      final total = formatMoney(
        1500000 + makeup * 800000 + (car ? 300000 : 0),
      );
      Future<void> next() async {
        final b = find.widgetWithText(AppButton, 'Tiếp tục · $total');
        await tester.ensureVisible(b);
        await tester.tap(b);
        await tester.pumpAndSettle();
      }

      await next();
      final day15 = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '15 tháng 10, rảnh',
      );
      await tester.ensureVisible(day15);
      await tester.tap(day15);
      await tester.pumpAndSettle();
      final slotChip = find.widgetWithText(AppChip, '06:00');
      await tester.ensureVisible(slotChip);
      await tester.tap(slotChip);
      await tester.pumpAndSettle();
      await next();

      await tester.enterText(find.byType(TextField).first, 'Bến Bạch Đằng, Quận 1');
      if (car) {
        await tester.enterText(
          find.byKey(const Key('book-pickup-field')),
          'Ga Sài Gòn, Quận 3',
        );
      }
      await tester.pump();
      await next();
      expect(find.byType(ReviewStep), findsOneWidget);
    }

    List<String?> moneyTexts(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(MoneyBreakdown),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();

    testWidgets('money lines: Gói Chân dung 2 giờ 1.500.000₫, Trang điểm · 2 người 1.600.000₫, Xe đón trong nội thành 300.000₫, Thanh toán 100% 3.400.000₫', (
      tester,
    ) async {
      await toReview(tester);
      expect(moneyTexts(tester), [
        'Gói Chân dung 2 giờ',
        '1.500.000₫',
        'Trang điểm · 2 người',
        '1.600.000₫',
        'Xe đón trong nội thành',
        '300.000₫',
        'Thanh toán 100%',
        '3.400.000₫',
      ]);
    });

    testWidgets('summary card shows "Điểm đón: Ga Sài Gòn, Quận 3"', (
      tester,
    ) async {
      await toReview(tester);
      expect(
        find.descendant(
          of: find.byType(BookingCard),
          matching: find.text('Điểm đón: Ga Sài Gòn, Quận 3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pay button "Thanh toán 3.400.000₫"', (tester) async {
      await toReview(tester);
      expect(
        find.widgetWithText(AppButton, 'Thanh toán 3.400.000₫'),
        findsOneWidget,
      );
      expect(find.byType(CtaSurface), findsOneWidget);
    });

    testWidgets('without add-ons the lines are as before', (tester) async {
      await toReview(tester, makeup: 0, car: false);
      expect(moneyTexts(tester), [
        'Gói Chân dung 2 giờ',
        '1.500.000₫',
        'Thanh toán 100%',
        '1.500.000₫',
      ]);
      expect(find.textContaining('Điểm đón'), findsNothing);
    });
  });

  testWidgets('summary shows "Tại Hồ Tây"', (tester) async {
    await walkSpotPackage(tester, until: BookingStep.review, car: true);

    expect(find.byType(ReviewStep), findsOneWidget);
    expect(find.text('Tại Hồ Tây'), findsOneWidget);
    expect(find.text('Điểm đón: Ga Hà Nội, Đống Đa'), findsOneWidget);
    expect(find.text('Thanh toán 1.800.000₫'), findsOneWidget);
  });
}
