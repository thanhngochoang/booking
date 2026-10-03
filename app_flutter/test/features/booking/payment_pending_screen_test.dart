// test/features/booking/payment_pending_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/features/booking/fake_payment_sheet.dart';
import 'package:photobooking/features/booking/payment_pending_screen.dart';

import '../../support/booking_world.dart';
import '../../support/fake_booking_repository.dart';

Booking _makeBooking({
  String id = 'booking_1',
  String customerId = 'c1',
  String photographerId = 'p1',
  String serviceId = 's1',
  BookingStatus status = BookingStatus.draft,
  String depositProvider = 'momo',
  int deposit = 450000,
}) {
  return Booking(
    id: id,
    customerId: customerId,
    photographerId: photographerId,
    serviceId: serviceId,
    serviceSnapshot: const BookingServiceSnapshot(
      name: 'Gói Chân Dung',
      price: 1500000,
      durationMinutes: 120,
    ),
    day: '2026-10-15',
    start: '06:00',
    end: '08:00',
    place: const BookingPlace(name: 'Bến Bạch Đằng'),
    status: status,
    depositProvider: depositProvider,
    deposit: deposit,
    remaining: 1050000,
    createdAt: DateTime.utc(2026, 10, 3, 10, 0),
    updatedAt: DateTime.utc(2026, 10, 3, 10, 0),
  );
}

/// S04.04's draft state shows a looping [SignatureLoader] (vibration waves), so
/// `pumpAndSettle` would never settle; pump a bounded second of frames instead
/// (enough for streams, sheets and route transitions).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('first load shows the screen SignatureLoader with ripple waves', (
    tester,
  ) async {
    final completer = Completer<Booking?>();
    await pumpBookingRoute(
      tester,
      path: '/b/booking_1/pay',
      extraOverrides: [
        bookingProvider('booking_1')
            .overrideWith((ref) => completer.future.asStream()),
      ],
    );

    // Pump a small duration for delay timer in AsyncView
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final loaderFinder = find.byType(SignatureLoader);
    expect(loaderFinder, findsOneWidget);
    final loader = tester.widget<SignatureLoader>(loaderFinder);
    expect(loader.wave, LoaderWave.ripple);
  });

  testWidgets('a draft shows SignatureLoader with vibration waves', (
    tester,
  ) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.seedBooking(_makeBooking());

    await pumpBookingRoute(
      tester,
      path: '/b/booking_1/pay',
      bookings: fakeRepo,
    );
    await _settle(tester);

    final loaderFinder = find.byType(SignatureLoader);
    expect(loaderFinder, findsOneWidget);
    final loader = tester.widget<SignatureLoader>(loaderFinder);
    expect(loader.wave, LoaderWave.vibration);
  });

  testWidgets(
    'a draft shows the waiting title, the body naming the gateway and the compact card with Chờ cọc',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.seedBooking(_makeBooking(depositProvider: 'momo'));

      await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: fakeRepo,
        realPayments: true,
      );
      await _settle(tester);

      expect(find.text('Thanh toán'), findsOneWidget);
      expect(find.text('Đang chờ xác nhận thanh toán'), findsOneWidget);
      expect(
        find.text(
          'Cổng MoMo chưa báo về. Thường mất dưới một phút. '
          'Bạn có thể rời màn này, yêu cầu vẫn được giữ.',
        ),
        findsOneWidget,
      );

      final cardFinder = find.byType(BookingCard);
      expect(cardFinder, findsOneWidget);
      final card = tester.widget<BookingCard>(cardFinder);
      expect(card.size, BookingCardSize.compact);
      expect(card.data.photographerName, 'Minh Trí');
      expect(find.text('Chờ cọc'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Kiểm tra lại'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Đổi cổng thanh toán'),
        findsOneWidget,
      );
    },
  );

  testWidgets('fake payments: the body names the test gateway', (tester) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.seedBooking(_makeBooking(depositProvider: 'momo'));

    await pumpBookingRoute(
      tester,
      path: '/b/booking_1/pay',
      bookings: fakeRepo,
    );
    await _settle(tester);

    expect(find.textContaining('Cổng thử nghiệm chưa báo về.'), findsOneWidget);
  });

  testWidgets('check again calls checkDeposit only', (tester) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.seedBooking(_makeBooking());

    await pumpBookingRoute(
      tester,
      path: '/b/booking_1/pay',
      bookings: fakeRepo,
    );
    await _settle(tester);

    final btn = find.widgetWithText(AppButton, 'Kiểm tra lại');
    expect(btn, findsOneWidget);
    await tester.tap(btn);
    await _settle(tester);

    expect(fakeRepo.checkCalls, ['booking_1']);
    expect(fakeRepo.createCalls, isEmpty);
    expect(fakeRepo.depositCalls, isEmpty);
  });

  testWidgets('check again with no payment yet shows the not-yet message', (
    tester,
  ) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.seedBooking(_makeBooking(status: BookingStatus.draft));

    await pumpBookingRoute(
      tester,
      path: '/b/booking_1/pay',
      bookings: fakeRepo,
    );
    await _settle(tester);

    final btn = find.widgetWithText(AppButton, 'Kiểm tra lại');
    await tester.tap(btn);
    await _settle(tester);

    expect(
      find.text('Chưa nhận được xác nhận, thử lại sau ít phút'),
      findsOneWidget,
    );
  });

  testWidgets(
    'check again failing on the network shows the network message and stays',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.seedBooking(_makeBooking());

      await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: fakeRepo,
      );
      await _settle(tester);

      fakeRepo.nextError = BookingErrorCode.network;
      await tester.tap(find.widgetWithText(AppButton, 'Kiểm tra lại'));
      await _settle(tester);

      expect(
        find.text('Không gửi được. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget,
      );
      expect(find.text('Đang chờ xác nhận thanh toán'), findsOneWidget);
      expect(fakeRepo.depositCalls, isEmpty);
    },
  );

  testWidgets(
    'the server confirming the payment opens S05.02 with the paid toast',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.seedBooking(_makeBooking());

      final handles = await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: fakeRepo,
        signedInUid: 'c1',
      );
      await _settle(tester);

      expect(find.byType(BookingDetailScreen), findsNothing);

      // Confirm fake payment
      await fakeRepo.confirmFakePayment(paymentId: 'pay_booking_1');
      await _settle(tester);

      expect(handles.router.state.uri.toString(), '/b/booking_1?paid=1');
      expect(find.byType(PaymentPendingScreen), findsNothing);
      expect(find.byType(BookingDetailScreen), findsOneWidget);
      expect(
        find.text(
          'Cọc 450.000₫ đang được giữ an toàn. '
          'Minh Trí sẽ trả lời trong 24 giờ.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a booking that already left draft opens S05.02 at once', (
    tester,
  ) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.seedBooking(_makeBooking(status: BookingStatus.requested));

    final handles = await pumpBookingRoute(
      tester,
      path: '/b/booking_1/pay',
      bookings: fakeRepo,
      signedInUid: 'c1',
    );
    await _settle(tester);

    expect(handles.router.state.uri.toString(), '/b/booking_1?paid=1');
    expect(find.byType(BookingDetailScreen), findsOneWidget);
  });

  testWidgets(
    'change provider creates a deposit with the other gateway and stays on S04.04',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.seedBooking(_makeBooking(depositProvider: 'momo'));

      final handles = await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: fakeRepo,
      );
      await _settle(tester);

      final changeBtn = find.widgetWithText(AppButton, 'Đổi cổng thanh toán');
      await tester.tap(changeBtn);
      await _settle(tester);

      expect(find.byType(ProviderPicker), findsOneWidget);
      // The current gateway is preselected.
      expect(
        tester.widget<ProviderPicker>(find.byType(ProviderPicker)).value,
        PaymentProviderCode.momo,
      );

      // Select VNPay
      await tester.tap(find.text('VNPay'));
      await _settle(tester);

      // Since in fake mode, fake payment sheet opens
      expect(find.byType(FakePaymentSheet), findsOneWidget);
      // Dismiss / cancel fake sheet
      await tester.tap(find.widgetWithText(AppButton, 'Huỷ'));
      await _settle(tester);

      // Stays on S04.04
      expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
      expect(fakeRepo.depositCalls, [
        (bookingId: 'booking_1', provider: 'vnpay'),
      ]);
      expect(fakeRepo.fakeConfirms, isEmpty);
      expect(fakeRepo.createCalls, isEmpty);
      expect(find.text('Đang chờ xác nhận thanh toán'), findsOneWidget);
    },
  );

  testWidgets(
    'change provider: confirming on the fake sheet confirms once and the stream opens S05.02',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.seedBooking(_makeBooking(depositProvider: 'momo'));

      final handles = await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: fakeRepo,
      );
      await _settle(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Đổi cổng thanh toán'));
      await _settle(tester);
      await tester.tap(find.text('VNPay'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán thành công'));
      await _settle(tester);

      expect(fakeRepo.fakeConfirms, ['pay_booking_1']);
      expect(handles.router.state.uri.toString(), '/b/booking_1?paid=1');
      expect(find.byType(BookingDetailScreen), findsOneWidget);
    },
  );

  testWidgets(
    'change provider in real mode opens the new payUrl and stays on S04.04',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.seedBooking(_makeBooking(depositProvider: 'momo'));

      final handles = await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: fakeRepo,
        realPayments: true,
      );
      await _settle(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Đổi cổng thanh toán'));
      await _settle(tester);
      await tester.tap(find.text('VNPay'));
      await _settle(tester);

      expect(fakeRepo.depositCalls, [
        (bookingId: 'booking_1', provider: 'vnpay'),
      ]);
      expect(handles.externalLauncher.opened, hasLength(1));
      expect(find.byType(FakePaymentSheet), findsNothing);
      expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
    },
  );

  testWidgets('change provider: picking the current gateway creates nothing', (
    tester,
  ) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.seedBooking(_makeBooking(depositProvider: 'momo'));

    await pumpBookingRoute(
      tester,
      path: '/b/booking_1/pay',
      bookings: fakeRepo,
    );
    await _settle(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Đổi cổng thanh toán'));
    await _settle(tester);
    await tester.tap(find.text('MoMo'));
    await _settle(tester);

    expect(fakeRepo.depositCalls, isEmpty);
    expect(find.byType(FakePaymentSheet), findsNothing);
  });

  testWidgets('a removed draft shows expired with Đặt lại', (tester) async {
    final fakeRepo = FakeBookingRepository();
    fakeRepo.seedBooking(_makeBooking());

    final handles = await pumpBookingRoute(
      tester,
      path: '/b/booking_1/pay',
      bookings: fakeRepo,
    );
    await _settle(tester);

    // Now remove draft (expired on server)
    fakeRepo.remove('booking_1');
    await _settle(tester);

    expect(find.text('Yêu cầu đã hết hạn'), findsOneWidget);
    expect(
      find.textContaining('Chưa nhận được tiền cọc trong 30 phút'),
      findsOneWidget,
    );

    final bookAgainBtn = find.widgetWithText(AppButton, 'Đặt lại');
    expect(bookAgainBtn, findsOneWidget);
    await tester.tap(bookAgainBtn);
    await _settle(tester);

    expect(handles.router.state.uri.toString(), '/u/p1/book?serviceId=s1');
  });

  testWidgets(
    'opening /b/unknown/pay with no booking shows expired with Về trang chủ',
    (tester) async {
      final fakeRepo = FakeBookingRepository();

      final handles = await pumpBookingRoute(
        tester,
        path: '/b/unknown/pay',
        bookings: fakeRepo,
      );
      await _settle(tester);

      expect(find.text('Yêu cầu đã hết hạn'), findsOneWidget);
      final homeBtn = find.widgetWithText(AppButton, 'Về trang chủ');
      expect(homeBtn, findsOneWidget);
      await tester.tap(homeBtn);
      await _settle(tester);

      expect(handles.router.state.uri.toString(), '/home');
    },
  );

  testWidgets(
    'reduced motion: the SignatureLoader is in its still state (no ticker)',
    (tester) async {
      final fakeRepo = FakeBookingRepository();
      fakeRepo.seedBooking(_makeBooking());

      await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: fakeRepo,
        disableAnimations: true,
      );
      await _settle(tester);

      final loaderFinder = find.byType(SignatureLoader);
      expect(loaderFinder, findsOneWidget);
      expect(
        tester.widget<SignatureLoader>(loaderFinder).wave,
        LoaderWave.vibration,
      );
      // Still state: no ticker runs, so the tree settles.
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320 dp and 1.3× text, light and dark: no overflow', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      // A fresh ProviderScope: the previous round left S05.02 watching the
      // old repository's booking.
      await tester.pumpWidget(const SizedBox.shrink());
      final fakeRepo = FakeBookingRepository();
      fakeRepo.seedBooking(_makeBooking());

      await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: fakeRepo,
        brightness: brightness,
        textScale: 1.3,
        viewSize: const Size(320, 600),
        signedInUid: 'c1',
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Scaffold)).width, 320);
      expect(find.byType(SignatureLoader), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Kiểm tra lại'), findsOneWidget);

      // S05.02 at the same size once paid.
      await fakeRepo.confirmFakePayment(paymentId: 'pay_booking_1');
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(BookingDetailScreen), findsOneWidget);
    }
  });
}
