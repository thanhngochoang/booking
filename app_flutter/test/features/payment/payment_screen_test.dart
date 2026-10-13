// test/features/booking/payment_pending_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/features/payment/fake_transfer_sheet.dart';
import 'package:photobooking/features/payment/payment_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/booking_world.dart';
import '../../support/fake_booking_repository.dart';

const _bankAppsUrl = 'https://fake-pay.local/bank-apps';
const _momoUrl = 'https://fake-pay.local/momo?paymentId=pay_booking_1';

Booking _makeBooking({
  BookingStatus status = BookingStatus.draft,
  BookingCheckout? checkout,
}) {
  return Booking(
    id: 'booking_1',
    customerId: 'c1',
    photographerId: 'p1',
    serviceId: 's1',
    serviceSnapshot: const BookingServiceSnapshot(
      name: 'Chân dung 2 giờ',
      price: 1500000,
      durationMinutes: 120,
    ),
    day: '2026-10-15',
    start: '06:00',
    end: '08:00',
    place: const BookingPlace(name: 'Bến Bạch Đằng'),
    status: status,
    deposit: 1500000,
    remaining: 0,
    checkout: checkout,
    createdAt: DateTime.utc(2026, 10, 3, 10, 0),
    updatedAt: DateTime.utc(2026, 10, 3, 10, 0),
  );
}

BookingCheckout _qr({
  required DateTime expiresAt,
  String code = 'PB 7F3K2Q',
  int attempt = 1,
  String? bankAppsUrl = _bankAppsUrl,
}) => BookingCheckout(
  paymentId: 'pay_booking_1',
  method: PayMethod.bankQr,
  amount: 1500000,
  expiresAt: expiresAt,
  transferCode: code,
  attempt: attempt,
  qrPayload: FakeBookingRepository.fakeQrPayload,
  bankName: 'BIDV',
  accountMasked: '9624 •••• 3812',
  bankAppsUrl: bankAppsUrl,
);

BookingCheckout _wallet({
  required DateTime expiresAt,
  PayMethod method = PayMethod.momo,
  String? payUrl = _momoUrl,
}) => BookingCheckout(
  paymentId: 'pay_booking_1',
  method: method,
  amount: 1500000,
  expiresAt: expiresAt,
  transferCode: 'PB 7F3K2Q',
  attempt: 1,
  payUrl: payUrl,
);

/// S04.04 shows a looping [SignatureLoader] while waiting for a wallet, so
/// `pumpAndSettle` would never settle; pump a bounded second of frames
/// instead (enough for streams, sheets and route transitions).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Screen {
  _Screen(this.repo, this.clock, this.handles);

  final FakeBookingRepository repo;
  final TestClock clock;
  final BookingWorldHandles handles;

  /// Moves the injected clock and lets the one-second ticker fire.
  Future<void> advance(WidgetTester tester, Duration d) async {
    clock.advance(d);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }
}

/// Seeds one draft (with [checkout] built from the clock, or none) and opens
/// S04.04 on it. The repository and the app read the same hand-moved clock.
Future<_Screen> _pump(
  WidgetTester tester, {
  BookingCheckout Function(DateTime now)? checkout,
  bool realPayments = false,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
  bool disableAnimations = false,
  FakeBookingRepository? repo,
  String? signedInUid,
}) async {
  final clock = TestClock(worldBookingToday);
  final bookings = repo ?? FakeBookingRepository(clock: () => clock.now);
  bookings.seedBooking(_makeBooking(checkout: checkout?.call(clock.now)));
  final handles = await pumpBookingRoute(
    tester,
    path: '/b/booking_1/pay',
    bookings: bookings,
    realPayments: realPayments,
    brightness: brightness,
    textScale: textScale,
    viewSize: viewSize,
    disableAnimations: disableAnimations,
    signedInUid: signedInUid,
    clock: clock,
  );
  await _settle(tester);
  return _Screen(bookings, clock, handles);
}

BookingCheckout _freshQr(DateTime now) =>
    _qr(expiresAt: now.add(const Duration(minutes: 15)));

BookingCheckout _freshMomo(DateTime now) =>
    _wallet(expiresAt: now.add(const Duration(minutes: 15)));

int _primaryButtons(WidgetTester tester) =>
    find.byType(CtaSurface).evaluate().length;

void main() {
  testWidgets('first load shows the screen dot ring of AsyncView', (
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
    final loaderFinder = find.byType(DotRingLoader);
    expect(loaderFinder, findsOneWidget);
    expect(tester.widget<DotRingLoader>(loaderFinder).size, LoaderSize.screen);
    expect(find.byType(SignatureLoader), findsNothing);
  });

  group('QR checkout', () {
    testWidgets(
      'shows the QR, amount, "Minh Trí · Chân dung 2 giờ", badge "Chờ thanh toán" and "Còn 15:00"',
      (tester) async {
        await _pump(tester, checkout: _freshQr);

        expect(find.text('Chuyển khoản QR'), findsOneWidget); // app bar
        expect(
          find.byKey(const ValueKey(FakeBookingRepository.fakeQrPayload)),
          findsOneWidget,
        );
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('1.500.000₫'), findsOneWidget);
        expect(find.text('Minh Trí · Chân dung 2 giờ'), findsOneWidget);
        expect(find.text('Chờ thanh toán'), findsOneWidget);
        expect(find.text('Còn 15:00'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Mã VietQR 1.500.000₫, nội dung PB 7F3K2Q'),
          findsOneWidget,
        );
        expect(find.byType(SignatureLoader), findsNothing);
        expect(
          find.text(
            'Chuyển đúng số tiền và nội dung. Chuyển thiếu, thừa hoặc sau '
            'khi QR hết hạn sẽ được hoàn tự động.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'rows Ngân hàng BIDV, Số tài khoản 9624 •••• 3812, Nội dung PB 7F3K2Q',
      (tester) async {
        await _pump(tester, checkout: _freshQr);

        expect(find.text('Ngân hàng'), findsOneWidget);
        expect(find.text('BIDV'), findsOneWidget);
        expect(
          find.text('Tài khoản thu hộ của trung gian thanh toán'),
          findsOneWidget,
        );
        expect(find.text('Số tài khoản'), findsOneWidget);
        expect(find.text('9624 •••• 3812'), findsOneWidget);
        expect(find.text('Nội dung'), findsOneWidget);
        expect(find.text('PB 7F3K2Q'), findsOneWidget);
      },
    );

    testWidgets('only Nội dung has "Sao chép" and it copies "PB 7F3K2Q"', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester, checkout: _freshQr);

      expect(find.text('Sao chép'), findsOneWidget);
      await tester.tap(find.text('Sao chép'));
      await _settle(tester);

      expect(copied, 'PB 7F3K2Q');
      expect(find.text('Đã sao chép nội dung chuyển khoản'), findsOneWidget);
    });

    testWidgets('the countdown ticks down with the clock', (tester) async {
      final s = await _pump(tester, checkout: _freshQr);
      expect(find.text('Còn 15:00'), findsOneWidget);

      await s.advance(tester, const Duration(seconds: 28));
      expect(find.text('Còn 14:32'), findsOneWidget);
      expect(
        find.bySemanticsLabel('QR còn hiệu lực 14 phút 32 giây'),
        findsOneWidget,
      );

      await s.advance(tester, const Duration(minutes: 1));
      expect(find.text('Còn 13:32'), findsOneWidget);
    });

    testWidgets(
      'at 00:00 the QR shows "QR đã hết hạn" and the only button is a primary "Tạo QR mới"',
      (tester) async {
        final s = await _pump(tester, checkout: _freshQr, realPayments: true);
        expect(find.text('QR đã hết hạn'), findsNothing);
        expect(find.text('Mở app ngân hàng'), findsOneWidget);

        await s.advance(tester, const Duration(minutes: 15));

        expect(find.text('Hết hạn'), findsOneWidget);
        expect(find.text('QR đã hết hạn'), findsOneWidget);
        expect(find.text('Mở app ngân hàng'), findsNothing);
        expect(find.byType(AppButton), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Tạo QR mới'), findsOneWidget);
        expect(_primaryButtons(tester), 1);
      },
    );

    testWidgets('an already expired checkout opens in the expired state', (
      tester,
    ) async {
      await _pump(
        tester,
        checkout: (now) =>
            _qr(expiresAt: now.subtract(const Duration(minutes: 1))),
      );

      expect(find.text('QR đã hết hạn'), findsOneWidget);
      expect(find.text('Hết hạn'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Tạo QR mới'), findsOneWidget);
      expect(_primaryButtons(tester), 1);
    });

    testWidgets(
      '"Tạo QR mới" calls createPayment with the same method and the new code appears',
      (tester) async {
        final s = await _pump(
          tester,
          checkout: (now) => _qr(
            expiresAt: now.add(const Duration(minutes: 15)),
            code: 'PB 9ZZ9ZZ',
          ),
        );
        expect(find.text('PB 9ZZ9ZZ'), findsOneWidget);

        await s.advance(tester, const Duration(minutes: 15));
        expect(find.text('QR đã hết hạn'), findsOneWidget);

        await tester.tap(find.widgetWithText(AppButton, 'Tạo QR mới'));
        await _settle(tester);

        expect(s.repo.paymentCalls, [
          (bookingId: 'booking_1', method: PayMethod.bankQr),
        ]);
        expect(find.text('PB 9ZZ9ZZ'), findsNothing);
        expect(find.text('PB 7F3K2Q'), findsOneWidget);
        expect(find.text('QR đã hết hạn'), findsNothing);
        expect(find.text('Còn 15:00'), findsOneWidget);
      },
    );

    testWidgets(
      'a second tap on the expired "Tạo QR mới" before the new QR arrives creates nothing',
      (tester) async {
        final s = await _pump(
          tester,
          realPayments: true,
          checkout: (now) => _qr(
            expiresAt: now.add(const Duration(minutes: 15)),
            code: 'PB 9ZZ9ZZ',
          ),
        );
        s.repo.deferCheckoutUpdates = true;
        await s.advance(tester, const Duration(minutes: 15));
        expect(find.text('QR đã hết hạn'), findsOneWidget);
        expect(find.byType(AppButton), findsOneWidget);

        await tester.tap(find.byType(AppButton));
        await _settle(tester);
        // The callable has answered but the booking snapshot has not: the
        // old, expired QR is still shown and the button stays busy.
        expect(s.repo.paymentCalls, hasLength(1));
        expect(find.text('PB 9ZZ9ZZ'), findsOneWidget);
        await tester.tap(find.byType(AppButton), warnIfMissed: false);
        await _settle(tester);
        expect(s.repo.paymentCalls, hasLength(1));

        s.repo.releaseCheckoutUpdates();
        await _settle(tester);
        expect(find.text('PB 7F3K2Q'), findsOneWidget);
        expect(find.text('Còn 15:00'), findsOneWidget);
        // The new QR is live: "Tạo QR mới" works again.
        await tester.tap(find.widgetWithText(AppButton, 'Tạo QR mới'));
        await _settle(tester);
        expect(s.repo.paymentCalls, hasLength(2));
      },
    );

    testWidgets(
      '"Tạo QR mới" is also there before expiry, as the outline button',
      (tester) async {
        final s = await _pump(tester, checkout: _freshQr);

        await tester.tap(find.widgetWithText(AppButton, 'Tạo QR mới'));
        await _settle(tester);

        expect(s.repo.paymentCalls, hasLength(1));
        expect(_primaryButtons(tester), 1); // still only "Mở app ngân hàng"
      },
    );

    testWidgets(
      '"Tạo QR mới" on the fourth attempt shows "Đã tạo QR 3 lần. Hãy đặt lại từ đầu."',
      (tester) async {
        final s = await _pump(
          tester,
          checkout: (now) =>
              _qr(expiresAt: now.add(const Duration(minutes: 15)), attempt: 3),
        );
        s.repo.nextPaymentError = BookingErrorCode.paymentAttemptsExceeded;

        await tester.tap(find.widgetWithText(AppButton, 'Tạo QR mới'));
        await _settle(tester);

        expect(
          find.text('Đã tạo QR 3 lần. Hãy đặt lại từ đầu.'),
          findsOneWidget,
        );
        expect(find.text('PB 7F3K2Q'), findsOneWidget); // still the old screen
      },
    );

    testWidgets(
      '"Tạo QR mới" refused with blocked shows "Không đặt lịch được với người này."',
      (tester) async {
        final s = await _pump(
          tester,
          checkout: (now) =>
              _qr(expiresAt: now.add(const Duration(minutes: 15)), attempt: 3),
        );
        s.repo.nextPaymentError = BookingErrorCode.blocked;

        await tester.tap(find.widgetWithText(AppButton, 'Tạo QR mới'));
        await _settle(tester);

        expect(find.text('Không đặt lịch được với người này.'), findsOneWidget);
        expect(find.text('Yêu cầu đã hết hạn, thử lại nhé.'), findsNothing);
        expect(find.text('PB 7F3K2Q'), findsOneWidget);
      },
    );

    testWidgets('"Tạo QR mới" failing otherwise shows bookTryAgain', (
      tester,
    ) async {
      final s = await _pump(tester, checkout: _freshQr);
      s.repo.nextPaymentError = BookingErrorCode.network;

      await tester.tap(find.widgetWithText(AppButton, 'Tạo QR mới'));
      await _settle(tester);

      expect(find.text('Yêu cầu đã hết hạn, thử lại nhé.'), findsOneWidget);
    });

    testWidgets('"Mở app ngân hàng" opens bankAppsUrl', (tester) async {
      final s = await _pump(tester, checkout: _freshQr);

      await tester.tap(find.widgetWithText(AppButton, 'Mở app ngân hàng'));
      await _settle(tester);

      expect(s.handles.externalLauncher.opened, [Uri.parse(_bankAppsUrl)]);
    });

    testWidgets('"Mở app ngân hàng" is hidden when bankAppsUrl is null', (
      tester,
    ) async {
      await _pump(
        tester,
        checkout: (now) => _qr(
          expiresAt: now.add(const Duration(minutes: 15)),
          bankAppsUrl: null,
        ),
      );

      expect(find.text('Mở app ngân hàng'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Tạo QR mới'), findsOneWidget);
      expect(_primaryButtons(tester), 0);
    });

    testWidgets('one primary button at a time', (tester) async {
      final s = await _pump(tester, checkout: _freshQr);

      // Valid QR: primary "Mở app ngân hàng" + outline "Tạo QR mới".
      expect(_primaryButtons(tester), 1);
      expect(
        find.widgetWithText(AppButton, 'Mở app ngân hàng'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Tạo QR mới'), findsOneWidget);

      // Expired: only the primary "Tạo QR mới".
      await s.advance(tester, const Duration(minutes: 15));
      expect(_primaryButtons(tester), 1);
      expect(find.widgetWithText(AppButton, 'Tạo QR mới'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Mở app ngân hàng'), findsNothing);
    });

    testWidgets('an old draft without checkout creates a QR once', (
      tester,
    ) async {
      final s = await _pump(tester);

      expect(s.repo.paymentCalls, [
        (bookingId: 'booking_1', method: PayMethod.bankQr),
      ]);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('PB 7F3K2Q'), findsOneWidget);

      await _settle(tester);
      await s.advance(tester, const Duration(seconds: 30));
      expect(s.repo.paymentCalls, hasLength(1));
    });

    testWidgets('an old draft whose QR cannot be created offers a retry', (
      tester,
    ) async {
      final clock = TestClock(worldBookingToday);
      final repo = FakeBookingRepository(clock: () => clock.now)
        ..nextError = BookingErrorCode.network;
      final s = await _pump(tester, repo: repo);

      expect(
        find.text('Không gửi được. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);

      await tester.tap(find.byKey(const Key('error-retry')));
      await _settle(tester);

      expect(s.repo.paymentCalls, hasLength(1));
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });

  group('wallet waiting', () {
    testWidgets('shows the vibration loader and "Đang chờ xác nhận"', (
      tester,
    ) async {
      await _pump(tester, checkout: _freshMomo);

      final loader = tester.widget<SignatureLoader>(
        find.byType(SignatureLoader),
      );
      expect(loader.wave, LoaderWave.vibration);
      expect(find.text('Đang chờ xác nhận'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Còn 15:00'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Mở lại MoMo'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Kiểm tra lại'), findsOneWidget);
      expect(_primaryButtons(tester), 1);
    });

    testWidgets('names ZaloPay for a ZaloPay payment', (tester) async {
      await _pump(
        tester,
        checkout: (now) => _wallet(
          expiresAt: now.add(const Duration(minutes: 15)),
          method: PayMethod.zaloPay,
          payUrl: 'https://fake-pay.local/zalopay?paymentId=pay_booking_1',
        ),
      );

      expect(find.widgetWithText(AppButton, 'Mở lại ZaloPay'), findsOneWidget);
    });

    testWidgets('"Mở lại MoMo" opens payUrl', (tester) async {
      final s = await _pump(tester, checkout: _freshMomo);

      await tester.tap(find.widgetWithText(AppButton, 'Mở lại MoMo'));
      await _settle(tester);

      expect(s.handles.externalLauncher.opened, [Uri.parse(_momoUrl)]);
    });

    testWidgets(
      '"Kiểm tra lại" calls checkPayment and shows the not-yet snackbar',
      (tester) async {
        final s = await _pump(tester, checkout: _freshMomo);

        await tester.tap(find.widgetWithText(AppButton, 'Kiểm tra lại'));
        await _settle(tester);

        expect(s.repo.checkCalls, ['booking_1']);
        expect(s.repo.createCalls, isEmpty);
        expect(s.repo.paymentCalls, isEmpty);
        expect(
          find.text('Chưa nhận được xác nhận, thử lại sau ít phút'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '"Kiểm tra lại" failing on the network shows the network message',
      (tester) async {
        final s = await _pump(tester, checkout: _freshMomo);

        s.repo.nextError = BookingErrorCode.network;
        await tester.tap(find.widgetWithText(AppButton, 'Kiểm tra lại'));
        await _settle(tester);

        expect(
          find.text('Không gửi được. Kiểm tra mạng rồi thử lại.'),
          findsOneWidget,
        );
        expect(find.text('Đang chờ xác nhận'), findsOneWidget);
        expect(s.repo.paymentCalls, isEmpty);
      },
    );

    testWidgets('reduced motion: the loader is in its still state', (
      tester,
    ) async {
      await _pump(tester, checkout: _freshMomo, disableAnimations: true);

      expect(find.byType(SignatureLoader), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation and fake mode', () {
    testWidgets(
      'the server confirming the payment opens S05.02 with the paid toast',
      (tester) async {
        final s = await _pump(tester, checkout: _freshQr, signedInUid: 'c1');
        expect(find.byType(BookingDetailScreen), findsNothing);

        await s.repo.confirmFakePayment(paymentId: 'pay_booking_1');
        await _settle(tester);

        expect(s.handles.router.state.uri.toString(), '/b/booking_1?paid=1');
        expect(find.byType(PaymentScreen), findsNothing);
        expect(find.byType(BookingDetailScreen), findsOneWidget);
      },
    );

    testWidgets('a booking that already left draft opens S05.02 at once', (
      tester,
    ) async {
      final clock = TestClock(worldBookingToday);
      final repo = FakeBookingRepository(clock: () => clock.now);
      repo.seedBooking(_makeBooking(status: BookingStatus.requested));
      final handles = await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: repo,
        signedInUid: 'c1',
      );
      await _settle(tester);

      expect(handles.router.state.uri.toString(), '/b/booking_1?paid=1');
      expect(find.byType(BookingDetailScreen), findsOneWidget);
    });

    testWidgets('fake mode shows "Giả lập chuyển khoản" and opens the sheet', (
      tester,
    ) async {
      await _pump(tester, checkout: _freshQr);

      expect(find.text('Giả lập chuyển khoản'), findsOneWidget);
      await tester.tap(find.text('Giả lập chuyển khoản'));
      await _settle(tester);

      expect(find.byType(FakeTransferSheet), findsOneWidget);
      expect(find.text('Giả lập chuyển khoản (thử nghiệm)'), findsOneWidget);
      for (final label in [
        'Chuyển đúng',
        'Chuyển thiếu',
        'Chuyển thừa',
        'Sai nội dung',
      ]) {
        expect(find.widgetWithText(AppButton, label), findsOneWidget);
      }
    });

    for (final (label, kind) in [
      ('Chuyển đúng', FakeTransferKind.exact),
      ('Chuyển thiếu', FakeTransferKind.under),
      ('Chuyển thừa', FakeTransferKind.over),
      ('Sai nội dung', FakeTransferKind.wrongContent),
    ]) {
      testWidgets('fake sheet "$label" calls confirmFakePayment with $kind', (
        tester,
      ) async {
        final s = await _pump(tester, checkout: _freshQr, signedInUid: 'c1');

        await tester.tap(find.text('Giả lập chuyển khoản'));
        await _settle(tester);
        await tester.tap(find.widgetWithText(AppButton, label));
        await _settle(tester);

        expect(s.repo.fakeConfirms, ['pay_booking_1']);
        expect(s.repo.fakeConfirmKinds, [kind]);
        expect(find.byType(FakeTransferSheet), findsNothing);
      });
    }

    testWidgets('the wallet waiting view has the simulator too', (
      tester,
    ) async {
      await _pump(tester, checkout: _freshMomo);

      expect(find.text('Giả lập chuyển khoản'), findsOneWidget);
    });

    testWidgets('real mode hides it', (tester) async {
      await _pump(tester, checkout: _freshQr, realPayments: true);

      expect(find.text('Giả lập chuyển khoản'), findsNothing);
      expect(find.byType(FakeTransferSheet), findsNothing);
    });

    testWidgets('a removed draft shows expired with Đặt lại', (tester) async {
      final s = await _pump(tester, checkout: _freshQr);

      // Now remove draft (expired on server)
      s.repo.remove('booking_1');
      await _settle(tester);

      expect(find.text('Yêu cầu đã hết hạn'), findsOneWidget);
      expect(
        find.textContaining('Chưa nhận được thanh toán nên yêu cầu đã huỷ'),
        findsOneWidget,
      );

      final bookAgainBtn = find.widgetWithText(AppButton, 'Đặt lại');
      expect(bookAgainBtn, findsOneWidget);
      await tester.tap(bookAgainBtn);
      await _settle(tester);

      expect(s.handles.router.state.uri.toString(), '/u/p1/book?serviceId=s1');
    });

    testWidgets(
      'opening /b/unknown/pay with no booking shows expired with Về trang chủ',
      (tester) async {
        final handles = await pumpBookingRoute(
          tester,
          path: '/b/unknown/pay',
          bookings: FakeBookingRepository(),
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
  });

  group('layout', () {
    testWidgets('QR checkout fits 320 dp at 1.3x text, light and dark', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        // A fresh ProviderScope per round.
        await tester.pumpWidget(const SizedBox.shrink());
        final s = await _pump(
          tester,
          checkout: _freshQr,
          brightness: brightness,
          textScale: 1.3,
          viewSize: const Size(320, 600),
          signedInUid: 'c1',
        );

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(Scaffold)).width, 320);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(
          find.widgetWithText(AppButton, 'Mở app ngân hàng'),
          findsOneWidget,
        );

        // The expired footer too.
        await s.advance(tester, const Duration(minutes: 15));
        expect(tester.takeException(), isNull);
        expect(find.widgetWithText(AppButton, 'Tạo QR mới'), findsOneWidget);
      }
    });

    testWidgets('the QR tile stays light in dark mode', (tester) async {
      await _pump(tester, checkout: _freshQr, brightness: Brightness.dark);

      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.backgroundColor, AppColors.surface);
      expect(qr.backgroundColor.computeLuminance(), greaterThan(0.9));
    });

    testWidgets(
      'wallet waiting fits 320 dp at 1.3x text, then paid opens S05.02',
      (tester) async {
        final s = await _pump(
          tester,
          checkout: _freshMomo,
          textScale: 1.3,
          viewSize: const Size(320, 600),
          signedInUid: 'c1',
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(SignatureLoader), findsOneWidget);

        await s.repo.confirmFakePayment(paymentId: 'pay_booking_1');
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(BookingDetailScreen), findsOneWidget);
      },
    );

    testWidgets('the route extra renders the QR before the booking stream answers', (
      tester,
    ) async {
      final clock = TestClock(worldBookingToday);
      final repo = FakeBookingRepository(clock: () => clock.now);
      await pumpBookingRoute(
        tester,
        path: '/b/booking_1/pay',
        bookings: repo,
        clock: clock,
      );
      await _settle(tester);
      expect(find.byType(PaymentScreen), findsOneWidget);
    });
  });
}
