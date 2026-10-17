import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/payment/fake_transfer_sheet.dart';
import 'package:photobooking/features/booking/steps/datetime_step.dart';
import 'package:photobooking/features/booking/steps/place_step.dart';
import 'package:photobooking/features/booking/steps/review_step.dart';
import 'package:photobooking/features/booking/steps/service_step.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

import '../../support/booking_world.dart';
import '../../support/fake_booking_repository.dart';

/// The real S04.04 waits on a draft with a looping SignatureLoader, so a test that
/// lands there pumps a bounded second of frames instead of `pumpAndSettle`.
Future<void> pumpWhileWaiting(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 5);
  final day12 = DateTime.utc(2026, 10, 12);
  final testDays = {day12: AvailabilityDay(day: day12, state: DayState.free)};

  Future<BookingWorldHandles> navigateToReviewStep(
    WidgetTester tester, {
    String path = '/u/p1/book?serviceId=s1&day=2026-10-12',
    FakeBookingRepository? bookings,
    List<ServiceSummary>? packages,
    UserContact? contact = const UserContact(phone: '+84903123456'),
    bool realPayments = false,
    List<Override> extraOverrides = const [],
  }) async {
    final handles = await pumpBookingRoute(
      tester,
      path: path,
      bookings: bookings,
      packages: packages,
      days: testDays,
      now: now,
      contact: contact,
      realPayments: realPayments,
      extraOverrides: extraOverrides,
    );
    await tester.pumpAndSettle();

    // S04.02 datetime step: select day 12 (or preselected), then slot 15:30
    await tester.tap(find.bySemanticsLabel('12 tháng 10, rảnh'));
    await tester.pumpAndSettle();

    final slotChip = find.widgetWithText(AppChip, '15:30');
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

    expect(find.byType(PlaceStep), findsOneWidget);

    // PlaceStep: enter Bến Bạch Đằng
    final input = find.byType(TextField);
    await tester.enterText(input, 'Bến Bạch Đằng');
    await tester.pumpAndSettle();

    final continueBtn2 = find.widgetWithText(
      AppButton,
      'Tiếp tục · 1.500.000₫',
    );
    await tester.ensureVisible(continueBtn2);
    await tester.tap(continueBtn2);
    await tester.pumpAndSettle();

    expect(find.byType(ReviewStep), findsOneWidget);
    return handles;
  }

  testWidgets(
    'Thanh toán creates the booking with the chosen values, then a payment with the chosen method',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      await navigateToReviewStep(tester, bookings: fakeRepo);

      // Choose ZaloPay
      final zalo = find.text('ZaloPay');
      await tester.ensureVisible(zalo);
      await tester.tap(zalo);
      await tester.pumpAndSettle();

      final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
      await tester.tap(payBtn);
      await pumpWhileWaiting(tester); // lands on S04.04

      expect(fakeRepo.createCalls.length, 1);
      final call = fakeRepo.createCalls.single;
      expect(call.photographerId, 'p1');
      expect(call.serviceId, 's1');
      expect(call.day, '2026-10-12');
      expect(call.start, '15:30');
      expect(call.placeName, 'Bến Bạch Đằng');
      expect(call.note, isNull);
      expect(call.expectedPrice, 1500000);

      expect(fakeRepo.paymentCalls.length, 1);
      final payCall = fakeRepo.paymentCalls.single;
      expect(payCall.bookingId, 'booking_1');
      expect(payCall.method, PayMethod.zaloPay);
    },
  );

  testWidgets('the bank QR is the default method', (tester) async {
    final fakeRepo = FakeBookingRepository();
    await navigateToReviewStep(tester, bookings: fakeRepo);

    await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'));
    await pumpWhileWaiting(tester);

    expect(fakeRepo.paymentCalls.single.method, PayMethod.bankQr);
  });

  testWidgets('double tap creates one booking and one payment', (tester) async {
    final fakeRepo = FakeBookingRepository();
    await navigateToReviewStep(tester, bookings: fakeRepo);

    final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
    await tester.tap(payBtn);
    await tester.tap(payBtn);
    await pumpWhileWaiting(tester);

    expect(fakeRepo.createCalls.length, 1);
    expect(fakeRepo.paymentCalls.length, 1);
  });

  testWidgets(
    'fake mode goes straight to S04.04 without a sheet; a simulated transfer '
    'hands over to S05.02',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      final handles = await navigateToReviewStep(
        tester,
        bookings: fakeRepo,
        realPayments: false,
      );

      final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
      await tester.tap(payBtn);
      await pumpWhileWaiting(tester); // S04.04's draft loader loops

      expect(find.byType(FakeTransferSheet), findsNothing);
      expect(fakeRepo.fakeConfirms, isEmpty);
      expect(handles.router.state.uri.toString(), '/b/booking_1/pay');

      // The transfer arrives (the screen's own simulator button comes with
      // its rewrite); S04.04 sees the status leave draft and opens S05.02.
      await fakeRepo.confirmFakePayment(paymentId: 'pay_booking_1');
      await tester.pumpAndSettle();
      expect(handles.router.state.uri.toString(), '/b/booking_1?paid=1');
    },
  );

  testWidgets(
    'real mode opens S04.04 without a sheet or an external page for a bank QR',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      final handles = await navigateToReviewStep(
        tester,
        bookings: fakeRepo,
        realPayments: true,
      );

      final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
      await tester.tap(payBtn);
      await pumpWhileWaiting(tester); // S04.04's draft loader loops

      expect(find.byType(FakeTransferSheet), findsNothing);
      // A bank QR has no payUrl: S04.04 draws the QR itself.
      expect(handles.externalLauncher.opened, isEmpty);
      expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
    },
  );

  testWidgets(
    'a wallet with real payments opens payUrl then shows S04.04',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      final handles = await navigateToReviewStep(
        tester,
        bookings: fakeRepo,
        realPayments: true,
      );

      final momo = find.text('MoMo');
      await tester.ensureVisible(momo);
      await tester.tap(momo);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'));
      await pumpWhileWaiting(tester);

      expect(handles.externalLauncher.opened, [
        Uri.parse('https://fake-pay.local/momo?paymentId=pay_booking_1'),
      ]);
      expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
    },
  );

  testWidgets(
    'a wallet in fake mode opens no page and no sheet, only S04.04',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      final handles = await navigateToReviewStep(
        tester,
        bookings: fakeRepo,
        realPayments: false,
      );

      final momo = find.text('MoMo');
      await tester.ensureVisible(momo);
      await tester.tap(momo);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'));
      await pumpWhileWaiting(tester);

      expect(handles.externalLauncher.opened, isEmpty);
      expect(find.byType(FakeTransferSheet), findsNothing);
      expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
    },
  );

  testWidgets(
    'payment_attempts_exceeded shows "Đã tạo QR 3 lần. Hãy đặt lại từ đầu." without Thử lại',
    (tester) async {
      final fakeRepo = FakeBookingRepository()
        ..nextPaymentError = BookingErrorCode.paymentAttemptsExceeded;
      final handles = await navigateToReviewStep(tester, bookings: fakeRepo);

      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'));
      await tester.pumpAndSettle();

      expect(find.text('Đã tạo QR 3 lần. Hãy đặt lại từ đầu.'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      expect(handles.router.state.uri.toString(), isNot(contains('/pay')));
      expect(find.byType(ReviewStep), findsOneWidget);
    },
  );

  testWidgets('a changed phone is saved before the booking is created', (
    tester,
  ) async {
    final fakeRepo = FakeBookingRepository();
    final handles = await navigateToReviewStep(tester, bookings: fakeRepo);

    final phoneFinder = find.descendant(
      of: find.byType(PhoneField),
      matching: find.byType(TextFormField),
    );

    await tester.tap(phoneFinder);
    await tester.enterText(phoneFinder, '0987654321');
    await tester.pumpAndSettle();

    final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
    await tester.tap(payBtn);
    await pumpWhileWaiting(tester);

    // Verify contact was saved with new phone +84987654321
    final saved =
        handles.contactRepo.stored('fake-1') ??
        handles.contactRepo.stored('c1');
    expect(saved, isNotNull);
    expect(saved!.phone, '+84987654321');
    expect(fakeRepo.createCalls.length, 1);
  });

  testWidgets('day_taken returns to S04.02 and marks the day', (tester) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.nextError = BookingErrorCode.dayTaken;

    await navigateToReviewStep(tester, bookings: fakeRepo);

    final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    // Returns to DateTimeStep
    expect(find.byType(DateTimeStep), findsOneWidget);
    expect(find.text('Hôm đó vừa có người đặt'), findsOneWidget);
  });

  testWidgets(
    'phone_required sends to S04.05 with returnTo of the current flow',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.nextError = BookingErrorCode.phoneRequired;

      final handles = await navigateToReviewStep(tester, bookings: fakeRepo);

      final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      final location = handles.router.state.uri.toString();
      expect(location, startsWith('/profile/phone?returnTo='));
      final decoded = Uri.decodeComponent(
        handles.router.state.uri.queryParameters['returnTo']!,
      );
      expect(decoded, contains('/u/p1/book'));
      expect(decoded, contains('serviceId=s1'));
      expect(decoded, contains('2026-10-12'));
    },
  );

  testWidgets('price_changed refreshes the package and the total', (
    tester,
  ) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.nextError = BookingErrorCode.priceChanged;

    const updatedPackage = ServiceSummary(
      id: 's1',
      photographerId: 'p1',
      name: 'Gói Chân Dung',
      priceVnd: 2000000,
      durationMinutes: 120,
      photoCount: 50,
      editedCount: 10,
      deliveryDays: 3,
      active: true,
    );
    var packageList = [bookingPackage1, bookingPackage2];

    await navigateToReviewStep(
      tester,
      bookings: fakeRepo,
      extraOverrides: [
        profilePackagesProvider('p1')
            .overrideWith((ref) => Future.value(packageList)),
      ],
    );

    // Update package list for when provider is invalidated
    packageList = [updatedPackage, bookingPackage2];

    final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    // Step should be service
    expect(find.byType(ServiceStep), findsOneWidget);
    expect(find.text('Giá gói đã đổi'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Tiếp tục · 2.000.000₫'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a network error keeps everything and Thử lại reuses the same draft',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.nextPaymentError = BookingErrorCode.network;

      await navigateToReviewStep(tester, bookings: fakeRepo);

      final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Không gửi được. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);

      // Draft was created on first call
      expect(fakeRepo.createCalls.length, 1);
      expect(fakeRepo.paymentCalls, isEmpty);

      // Tap Thử lại
      await tester.tap(find.text('Thử lại'));
      await pumpWhileWaiting(tester);

      // Second attempt reuses draft booking_1: no second createBooking, but one payment call
      expect(fakeRepo.createCalls.length, 1);
      expect(fakeRepo.paymentCalls.length, 1);
    },
  );

  testWidgets(
    'a closed provider refused by the server shows "Nhiếp ảnh gia này chưa nhận đặt lịch."',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.nextError = BookingErrorCode.notAcceptingOrders;

      await navigateToReviewStep(tester, bookings: fakeRepo);

      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'));
      await tester.pumpAndSettle();

      expect(
        find.text('Nhiếp ảnh gia này chưa nhận đặt lịch.'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsNothing);
      expect(find.text('Thanh toán chưa mở trên máy chủ này.'), findsNothing);
      expect(fakeRepo.paymentCalls, isEmpty);
    },
  );

  testWidgets(
    'a blocked pair refused by the server shows "Không đặt lịch được với người này."',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.nextError = BookingErrorCode.blocked;

      await navigateToReviewStep(tester, bookings: fakeRepo);

      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'));
      await tester.pumpAndSettle();

      expect(find.text('Không đặt lịch được với người này.'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      expect(fakeRepo.paymentCalls, isEmpty);
    },
  );

  testWidgets(
    'blocked from createPayment shows the same text and does not open /pay',
    (tester) async {
      final fakeRepo = FakeBookingRepository()
        ..nextPaymentError = BookingErrorCode.blocked;
      final handles = await navigateToReviewStep(tester, bookings: fakeRepo);

      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'));
      await tester.pumpAndSettle();

      expect(find.text('Không đặt lịch được với người này.'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      expect(handles.router.state.uri.toString(), isNot(contains('/pay')));
      expect(find.byType(ReviewStep), findsOneWidget);
    },
  );

  testWidgets(
    'after a not_accepting_orders refusal the photographer profile is re-read',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.nextError = BookingErrorCode.notAcceptingOrders;
      var reads = 0;

      await navigateToReviewStep(
        tester,
        bookings: fakeRepo,
        extraOverrides: [
          photographerProfileProvider('p1').overrideWith((ref) async {
            reads++;
            return bookingProfile;
          }),
        ],
      );
      final before = reads;
      expect(before, greaterThan(0));

      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫'));
      await tester.pumpAndSettle();

      expect(reads, greaterThan(before));
    },
  );

  testWidgets('not_eligible shows Thanh toán chưa mở trên máy chủ này', (
    tester,
  ) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.nextError = BookingErrorCode.notEligible;

    await navigateToReviewStep(tester, bookings: fakeRepo);

    final payBtn = find.widgetWithText(AppButton, 'Thanh toán 1.500.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    expect(find.text('Thanh toán chưa mở trên máy chủ này.'), findsOneWidget);
  });

  group('add-on errors', () {
    /// S04.01 (portrait preselected) with makeup ×1 and the car → S04.03.
    Future<BookingWorldHandles> toReviewWithCar(
      WidgetTester tester,
      FakeBookingRepository repo,
    ) async {
      final handles = await pumpBookingRoute(
        tester,
        bookings: repo,
        packages: [bookingPortrait2h],
        addons: [addonMakeup, addonTransport],
        days: testDays,
        now: now,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      for (final key in ['addon-a_makeup-plus', 'addon-a_car-check']) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }
      Future<void> next() async {
        final b = find.widgetWithText(AppButton, 'Tiếp tục · 2.600.000₫');
        await tester.ensureVisible(b);
        await tester.tap(b);
        await tester.pumpAndSettle();
      }

      await next();
      await tester.tap(find.bySemanticsLabel('12 tháng 10, rảnh'));
      await tester.pumpAndSettle();
      final slot = find.widgetWithText(AppChip, '15:30');
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      await next();
      await tester.enterText(find.byType(TextField).first, 'Bến Bạch Đằng');
      await tester.enterText(
        find.byKey(const Key('book-pickup-field')),
        'Ga Sài Gòn',
      );
      await tester.pump();
      await next();
      expect(find.byType(ReviewStep), findsOneWidget);
      return handles;
    }

    testWidgets('addon_changed returns to S04.01 with a fresh list and the bar', (
      tester,
    ) async {
      final repo = FakeBookingRepository()
        ..nextError = BookingErrorCode.addonChanged;
      final handles = await toReviewWithCar(tester, repo);
      // The photographer turned the car off meanwhile.
      handles.addonRepo.addons.remove('a_car');

      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 2.600.000₫'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ServiceStep), findsOneWidget);
      expect(
        find.text(
          'Dịch vụ đi kèm vừa thay đổi, kiểm tra lại trước khi thanh toán',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('addon-a_car-check')), findsNothing);
      expect(
        find.widgetWithText(AppButton, 'Tiếp tục · 2.300.000₫'),
        findsOneWidget,
      );
    });

    testWidgets('pickup_required returns to S04.06 with the field error', (
      tester,
    ) async {
      final repo = FakeBookingRepository()
        ..nextError = BookingErrorCode.pickupRequired;
      await toReviewWithCar(tester, repo);

      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán 2.600.000₫'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PlaceStep), findsOneWidget);
      expect(find.text('Nhập điểm đón cho xe đưa đón'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('book-pickup-field')),
        'Ga Sài Gòn, Quận 3',
      );
      await tester.pump();
      expect(find.text('Nhập điểm đón cho xe đưa đón'), findsNothing);
    });
  });
}
