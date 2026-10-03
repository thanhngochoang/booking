import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/booking/fake_payment_sheet.dart';
import 'package:photobooking/features/booking/steps/datetime_step.dart';
import 'package:photobooking/features/booking/steps/place_step.dart';
import 'package:photobooking/features/booking/steps/review_step.dart';
import 'package:photobooking/features/booking/steps/service_step.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

import '../../support/booking_world.dart';
import '../../support/fake_booking_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5);
  final day12 = DateTime.utc(2026, 10, 12);
  final testDays = {
    day12: AvailabilityDay(day: day12, state: DayState.free),
  };

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

    final continueBtn1 = find.widgetWithText(AppButton, 'Tiếp tục · 1.500.000₫');
    await tester.ensureVisible(continueBtn1);
    await tester.tap(continueBtn1);
    await tester.pumpAndSettle();

    expect(find.byType(PlaceStep), findsOneWidget);

    // PlaceStep: enter Bến Bạch Đằng
    final input = find.byType(TextField);
    await tester.enterText(input, 'Bến Bạch Đằng');
    await tester.pumpAndSettle();

    final continueBtn2 = find.widgetWithText(AppButton, 'Tiếp tục · 1.500.000₫');
    await tester.ensureVisible(continueBtn2);
    await tester.tap(continueBtn2);
    await tester.pumpAndSettle();

    expect(find.byType(ReviewStep), findsOneWidget);
    return handles;
  }

  testWidgets('Đặt cọc creates the booking with the chosen values, then the deposit with the chosen provider', (tester) async {
    final fakeRepo = FakeBookingRepository();
    await navigateToReviewStep(tester, bookings: fakeRepo);

    // Choose VNPay
    await tester.tap(find.text('VNPay'));
    await tester.pumpAndSettle();

    // Tap Đặt cọc
    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    expect(fakeRepo.createCalls.length, 1);
    final call = fakeRepo.createCalls.single;
    expect(call.photographerId, 'p1');
    expect(call.serviceId, 's1');
    expect(call.day, '2026-10-12');
    expect(call.start, '15:30');
    expect(call.placeName, 'Bến Bạch Đằng');
    expect(call.note, isNull);
    expect(call.expectedPrice, 1500000);

    expect(fakeRepo.depositCalls.length, 1);
    final depCall = fakeRepo.depositCalls.single;
    expect(depCall.bookingId, 'booking_1');
    expect(depCall.provider, 'vnpay');
  });

  testWidgets('double tap creates one booking and one deposit', (tester) async {
    final fakeRepo = FakeBookingRepository();
    await navigateToReviewStep(tester, bookings: fakeRepo);

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    expect(fakeRepo.createCalls.length, 1);
    expect(fakeRepo.depositCalls.length, 1);
  });

  testWidgets('fake mode: the fake gateway sheet confirms and S04.04 opens', (tester) async {
    final fakeRepo = FakeBookingRepository();
    final handles = await navigateToReviewStep(tester, bookings: fakeRepo, realPayments: false);

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    // Fake payment sheet is open
    expect(find.byType(FakePaymentSheet), findsOneWidget);
    expect(find.text('Cổng thanh toán giả (chỉ để thử)'), findsOneWidget);

    // Tap Thanh toán thành công
    await tester.tap(find.widgetWithText(AppButton, 'Thanh toán thành công'));
    await tester.pumpAndSettle();

    expect(fakeRepo.fakeConfirms, contains('pay_booking_1'));
    // Redirects to /b/booking_1/pay
    expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
  });

  testWidgets('fake mode: Huỷ on the fake sheet still opens S04.04 without confirming', (tester) async {
    final fakeRepo = FakeBookingRepository();
    final handles = await navigateToReviewStep(tester, bookings: fakeRepo, realPayments: false);

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    expect(find.byType(FakePaymentSheet), findsOneWidget);

    // Tap Huỷ
    await tester.tap(find.widgetWithText(AppButton, 'Huỷ'));
    await tester.pumpAndSettle();

    expect(fakeRepo.fakeConfirms, isEmpty);
    expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
  });

  testWidgets('real mode opens payUrl with the external launcher and opens S04.04', (tester) async {
    final fakeRepo = FakeBookingRepository();
    final handles = await navigateToReviewStep(tester, bookings: fakeRepo, realPayments: true);

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    expect(find.byType(FakePaymentSheet), findsNothing);
    expect(handles.externalLauncher.opened, [Uri.parse('https://fake-pay.test/booking_1')]);
    expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
  });

  testWidgets('a changed phone is saved before the booking is created', (tester) async {
    final fakeRepo = FakeBookingRepository();
    final handles = await navigateToReviewStep(tester, bookings: fakeRepo);

    final phoneFinder = find.descendant(
      of: find.byType(PhoneField),
      matching: find.byType(TextFormField),
    );

    await tester.tap(phoneFinder);
    await tester.enterText(phoneFinder, '0987654321');
    await tester.pumpAndSettle();

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    // Verify contact was saved with new phone +84987654321
    final saved = handles.contactRepo.stored('fake-1') ?? handles.contactRepo.stored('c1');
    expect(saved, isNotNull);
    expect(saved!.phone, '+84987654321');
    expect(fakeRepo.createCalls.length, 1);
  });

  testWidgets('day_taken returns to S04.02 and marks the day', (tester) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.nextError = BookingErrorCode.dayTaken;

    await navigateToReviewStep(tester, bookings: fakeRepo);

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    // Returns to DateTimeStep
    expect(find.byType(DateTimeStep), findsOneWidget);
    expect(find.text('Hôm đó vừa có người đặt'), findsOneWidget);
  });

  testWidgets('phone_required sends to S04.05 with returnTo of the current flow', (tester) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.nextError = BookingErrorCode.phoneRequired;

    final handles = await navigateToReviewStep(tester, bookings: fakeRepo);

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    final location = handles.router.state.uri.toString();
    expect(location, startsWith('/profile/phone?returnTo='));
    final decoded = Uri.decodeComponent(handles.router.state.uri.queryParameters['returnTo']!);
    expect(decoded, contains('/u/p1/book'));
    expect(decoded, contains('serviceId=s1'));
    expect(decoded, contains('2026-10-12'));
  });

  testWidgets('price_changed refreshes the package and the total', (tester) async {
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
        profilePackagesProvider('p1').overrideWith((ref) => Future.value(packageList)),
      ],
    );

    // Update package list for when provider is invalidated
    packageList = [updatedPackage, bookingPackage2];

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    // Step should be service
    expect(find.byType(ServiceStep), findsOneWidget);
    expect(find.text('Giá gói đã đổi'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Tiếp tục · 2.000.000₫'), findsOneWidget);
  });

  testWidgets('a network error keeps everything and Thử lại reuses the same draft', (tester) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.nextDepositError = BookingErrorCode.network;

    await navigateToReviewStep(tester, bookings: fakeRepo);

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    expect(find.text('Không gửi được. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    // Draft was created on first call
    expect(fakeRepo.createCalls.length, 1);
    expect(fakeRepo.depositCalls, isEmpty);

    // Tap Thử lại
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    // Second attempt reuses draft booking_1: no second createBooking, but one deposit call
    expect(fakeRepo.createCalls.length, 1);
    expect(fakeRepo.depositCalls.length, 1);
  });

  testWidgets('not_eligible shows Thanh toán chưa mở trên máy chủ này', (tester) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.nextError = BookingErrorCode.notEligible;

    await navigateToReviewStep(tester, bookings: fakeRepo);

    final payBtn = find.widgetWithText(AppButton, 'Đặt cọc 450.000₫');
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    expect(find.text('Thanh toán chưa mở trên máy chủ này.'), findsOneWidget);
  });
}
