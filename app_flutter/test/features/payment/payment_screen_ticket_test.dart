import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/features/payment/fake_transfer_sheet.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/event_world.dart';

EventRegistration _reg({
  String id = 'r1',
  String eventId = 'ev1',
  RegistrationStatus status = RegistrationStatus.held,
  int amount = 500000,
  int quantity = 2,
  DateTime? holdExpiresAt,
  String paymentId = 'pay-r1',
}) =>
    EventRegistration(
      id: id,
      eventId: eventId,
      userId: 'u1',
      userName: 'Khách hàng',
      ticketCode: status == RegistrationStatus.paid ? 'VE-PAID-0001' : '',
      quantity: quantity,
      amount: amount,
      status: status,
      event: EventTicketSnapshot(
        title: 'Photo walk phố cổ',
        type: EventType.photoWalk,
        startsAt: eventNow.add(const Duration(days: 3)),
        endsAt: eventNow.add(const Duration(days: 3, hours: 2)),
        locationName: 'Công viên Bạch Đằng',
        lat: 10.78,
        lng: 106.70,
        coverUrl: 'https://img.test/cover.jpg',
      ),
      createdAt: eventNow,
      paymentId: paymentId,
      holdExpiresAt: holdExpiresAt,
      contactEligible: status == RegistrationStatus.paid,
    );

PaymentInstructions _freshQr({
  String paymentId = 'pay-r1',
  int amount = 500000,
  required DateTime expiresAt,
}) =>
    PaymentInstructions(
      paymentId: paymentId,
      method: PayMethod.bankQr,
      amount: amount,
      expiresAt: expiresAt,
      transferCode: 'PB 7F3K2Q',
      bankName: 'BIDV',
      accountMasked: '9624 •••• 3812',
      qrPayload: '000201010212...',
    );

PaymentInstructions _freshWallet({
  String paymentId = 'pay-r1',
  PayMethod method = PayMethod.momo,
  int amount = 500000,
  required DateTime expiresAt,
  String? payUrl = 'https://fake-pay.local/momo?paymentId=pay-r1',
}) =>
    PaymentInstructions(
      paymentId: paymentId,
      method: method,
      amount: amount,
      expiresAt: expiresAt,
      transferCode: 'PB 7F3K2Q',
      payUrl: payUrl,
    );

Future<EventsWorld> _openTicketPay(
  WidgetTester tester, {
  required EventRegistration registration,
  PaymentInstructions? initial,
  bool realPayments = false,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  DateTime Function()? clock,
}) async {
  final w = EventsWorld(
    events: [detailOf(registration.eventId, priceVnd: 250000)],
    registrations: [registration],
    clock: clock ?? () => eventNow,
  );
  if (initial != null) {
    w.payments.seedInstructions(initial.paymentId, initial);
  }
  await w.pump(
    tester,
    path: payPathOf(TicketPay(registration.eventId, registration.id)),
    size: size,
    textScale: textScale,
    extra: [
      if (realPayments) realPaymentsProvider.overrideWithValue(true),
    ],
  );
  await settle(tester);
  return w;
}

int _primaryButtons(WidgetTester tester) =>
    find.byType(CtaSurface).evaluate().length;

void main() {
  testWidgets(
    'TicketPay shows the QR, 500.000₫, "Photo walk phố cổ · 2 vé", "Chờ thanh toán" and "Còn 10:00"',
    (tester) async {
      final expires = eventNow.add(const Duration(minutes: 10));
      final reg = _reg(holdExpiresAt: expires);
      final instr = _freshQr(expiresAt: expires);

      await _openTicketPay(
        tester,
        registration: reg,
        initial: instr,
        clock: () => eventNow,
      );

      expect(find.text('Chuyển khoản QR'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('500.000₫'), findsOneWidget);
      expect(find.text('Photo walk phố cổ · 2 vé'), findsOneWidget);
      expect(find.text('Chờ thanh toán'), findsOneWidget);
      expect(find.text('Còn 10:00'), findsOneWidget);
    },
  );

  testWidgets(
    'at 00:00 the only button is a primary "Về sự kiện" and it opens /e/{eventId}',
    (tester) async {
      var now = eventNow;
      final expires = eventNow.add(const Duration(seconds: 1));
      final reg = _reg(holdExpiresAt: expires);
      final instr = _freshQr(expiresAt: expires);

      final w = await _openTicketPay(
        tester,
        registration: reg,
        initial: instr,
        clock: () => now,
      );

      expect(find.text('Còn 00:01'), findsOneWidget);

      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('Hết hạn'), findsOneWidget);
      expect(find.text('Về sự kiện'), findsOneWidget);
      expect(_primaryButtons(tester), 1);

      await tester.tap(find.text('Về sự kiện'));
      await settle(tester);
      expect(w.location, '/e/ev1');
    },
  );

  testWidgets(
    'a paid registration goes to /bookings?tab=events&highlight={regId} with "Đã đăng ký" and "Vào nhóm chat"',
    (tester) async {
      final reg = _reg(holdExpiresAt: eventNow.add(const Duration(minutes: 10)));
      final instr = _freshQr(expiresAt: reg.holdExpiresAt!);

      final w = await _openTicketPay(
        tester,
        registration: reg,
        initial: instr,
        clock: () => eventNow,
      );

      // The registration flips to paid
      w.repo.putRegistration(
        EventRegistration(
          id: reg.id,
          eventId: reg.eventId,
          userId: reg.userId,
          userName: reg.userName,
          ticketCode: 'VE-PAID-0001',
          quantity: reg.quantity,
          amount: reg.amount,
          status: RegistrationStatus.paid,
          event: reg.event,
          createdAt: reg.createdAt,
          paymentId: reg.paymentId,
          holdExpiresAt: reg.holdExpiresAt,
          contactEligible: true,
        ),
      );
      await settle(tester);

      expect(w.location, '/bookings?tab=events&highlight=r1');
      expect(find.text('Đã đăng ký'), findsOneWidget);
      expect(find.text('Vào nhóm chat'), findsOneWidget);

      // Tapping action opens chat
      await tester.tap(find.text('Vào nhóm chat'));
      await settle(tester);
      expect(w.location, '/e/ev1/chat');
    },
  );

  testWidgets(
    'a cancelled hold shows "Chỗ giữ đã hết hạn" with "Về sự kiện"',
    (tester) async {
      final reg = _reg(holdExpiresAt: eventNow.add(const Duration(minutes: 10)));
      final instr = _freshQr(expiresAt: reg.holdExpiresAt!);

      final w = await _openTicketPay(
        tester,
        registration: reg,
        initial: instr,
        clock: () => eventNow,
      );

      // The hold is cancelled on server
      w.repo.putRegistration(
        EventRegistration(
          id: reg.id,
          eventId: reg.eventId,
          userId: reg.userId,
          userName: reg.userName,
          ticketCode: '',
          quantity: reg.quantity,
          amount: reg.amount,
          status: RegistrationStatus.cancelled,
          event: reg.event,
          createdAt: reg.createdAt,
          paymentId: reg.paymentId,
          holdExpiresAt: reg.holdExpiresAt,
          contactEligible: false,
        ),
      );
      await settle(tester);

      expect(find.text('Chỗ giữ đã hết hạn'), findsOneWidget);
      expect(
        find.text(
          'Chưa nhận được thanh toán nên chỗ giữ đã nhả. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.',
        ),
        findsOneWidget,
      );
      expect(find.text('Về sự kiện'), findsOneWidget);

      await tester.tap(find.text('Về sự kiện'));
      await settle(tester);
      expect(w.location, '/e/ev1');
    },
  );

  testWidgets(
    'without extra the instructions come from PaymentsRepository.instructions',
    (tester) async {
      final expires = eventNow.add(const Duration(minutes: 10));
      final reg = _reg(holdExpiresAt: expires);
      final instr = _freshQr(expiresAt: expires);

      final w = EventsWorld(
        events: [detailOf(reg.eventId, priceVnd: 250000)],
        registrations: [reg],
        clock: () => eventNow,
      );
      w.payments.seedInstructions('pay-r1', instr);
      await w.pump(
        tester,
        path: payPathOf(TicketPay(reg.eventId, reg.id)),
      );
      await settle(tester);

      expect(w.payments.instructionCalls, contains('pay-r1'));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('500.000₫'), findsOneWidget);
    },
  );

  testWidgets('a closed payment (instructions null) shows the expired state', (
    tester,
  ) async {
    final reg = _reg(holdExpiresAt: eventNow.add(const Duration(minutes: 10)));

    final w = await _openTicketPay(
      tester,
      registration: reg,
      initial: null,
      clock: () => eventNow,
    );
    // instructionCalls has 'pay-r1', seeded is null by default.
    await settle(tester);

    expect(w.payments.instructionCalls, contains('pay-r1'));
    expect(find.text('Chỗ giữ đã hết hạn'), findsOneWidget);
    expect(find.text('Về sự kiện'), findsOneWidget);
  });

  testWidgets('wallet "Kiểm tra lại" calls checkTicketPayment', (tester) async {
    final expires = eventNow.add(const Duration(minutes: 10));
    final reg = _reg(holdExpiresAt: expires);
    final instr = _freshWallet(expiresAt: expires);

    final w = await _openTicketPay(
      tester,
      registration: reg,
      initial: instr,
      clock: () => eventNow,
    );

    expect(find.text('Kiểm tra lại'), findsOneWidget);
    await tester.tap(find.text('Kiểm tra lại'));
    await settle(tester);

    expect(w.repo.paymentChecks, ['ev1/r1']);
  });

  testWidgets(
    'fake mode simulator confirms through PaymentsRepository.confirmFake',
    (tester) async {
      final expires = eventNow.add(const Duration(minutes: 10));
      final reg = _reg(holdExpiresAt: expires);
      final instr = _freshQr(expiresAt: expires);

      final w = await _openTicketPay(
        tester,
        registration: reg,
        initial: instr,
        clock: () => eventNow,
      );

      expect(find.text('Giả lập chuyển khoản'), findsOneWidget);
      await tester.tap(find.text('Giả lập chuyển khoản'));
      await settle(tester);

      expect(find.byType(FakeTransferSheet), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Chuyển đúng'));
      await settle(tester);

      expect(
        w.payments.confirms,
        [('pay-r1', FakeTransferKind.exact)],
      );
    },
  );

  testWidgets('fits 320 dp at 1.3x text, light and dark', (
    tester,
  ) async {
    final expires = eventNow.add(const Duration(minutes: 10));
    final reg = _reg(holdExpiresAt: expires);
    final instr = _freshQr(expiresAt: expires);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await _openTicketPay(
        tester,
        registration: reg,
        initial: instr,
        brightness: brightness,
        textScale: 1.3,
        size: const Size(320, 640),
        clock: () => eventNow,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    }
  });
}
