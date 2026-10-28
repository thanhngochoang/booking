import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/widgets/late_delivery_card.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/dispute_world.dart';
import '../../support/fake_payments_repository.dart';

/// Shoot on Monday 12/10 15:30–17:30 Vietnam = 08:30–10:30 UTC.
final _startsAt = DateTime.utc(2026, 10, 12, 8, 30);
final _endsAt = DateTime.utc(2026, 10, 12, 10, 30);

Booking _booking({
  BookingStatus status = BookingStatus.requested,
  DateTime? acceptDeadline,
  String? chatId,
  EscrowStatus? escrow = EscrowStatus.held,
}) {
  return makeTestBooking(
    id: 'b1',
    status: status,
    day: '2026-10-12',
    start: '15:30',
    end: '17:30',
    deposit: 450000,
    remaining: 1050000,
    serviceSnapshot: const BookingServiceSnapshot(
      name: 'Chân dung 2 giờ',
      price: 1500000,
      durationMinutes: 120,
    ),
    place: const BookingPlace(name: 'Bến Bạch Đằng'),
    escrowStatus: escrow,
  ).copyWith(acceptDeadline: acceptDeadline, chatId: chatId);
}

Booking _withAddons({required int deposit}) => _booking().copyWith(
  addons: const [testMakeupLine, testTransportLine],
  pickup: testPickup,
  deposit: deposit,
  remaining: 0,
);

RecordingBookingRepository _repo(Booking b, {BookingContactSnapshot? copy}) {
  final repo = RecordingBookingRepository()..seedBooking(b);
  if (copy != null) repo.seedContact(b.id, copy);
  return repo;
}

/// S05.02 has no looping loader, but tickers and sheets animate: pump a
/// bounded second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _badge(BookingStatus status) =>
    find.byWidgetPredicate((w) => w is StatusBadge && w.status == status);

Finder _codeFinder(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

/// Labels of the primary (gradient) buttons on screen.
List<String> primaryButtonLabels(WidgetTester tester) => [
  for (final b in tester.widgetList<AppButton>(
    find.ancestor(
      of: find.byType(CtaSurface),
      matching: find.byType(AppButton),
    ),
  ))
    b.label,
];

void main() {
  testWidgets('S05.02 shows the refund card while refundAccountNeeded and '
      'hides it after', (tester) async {
    // Declined after payment: the server's refund waits for the account.
    final declined = _booking(
      status: BookingStatus.declined,
      escrow: EscrowStatus.refunded,
    ).copyWith(depositRefunded: 1500000, refundAccountNeeded: true);
    final payments = FakePaymentsRepository()
      ..pendingBySubject[const BookingRefund('b1')] = PendingRefund(
        refundId: 'r1',
        amount: 1500000,
        payer: (
          bankName: 'Vietcombank',
          accountLast4: '6789',
          holderName: 'NGUYEN THANH HA',
        ),
        confirmBy: _startsAt,
      );
    final handles = await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(declined),
      payments: payments,
    );
    await _settle(tester);

    final card = find.byKey(const Key('detail-refund-account'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text('Bạn được hoàn 1.500.000₫'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Chọn tài khoản để nhận tiền hoàn.'),
      ),
      findsOneWidget,
    );
    final choose = find.descendant(
      of: card,
      matching: find.widgetWithText(AppButton, 'Chọn tài khoản nhận hoàn'),
    );
    expect(choose, findsOneWidget);
    // An outline button: the screen keeps at most one primary.
    expect(
      primaryButtonLabels(tester),
      isNot(contains('Chọn tài khoản nhận hoàn')),
    );

    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await _settle(tester);
    expect(payments.pendingCalls, [const BookingRefund('b1')]);
    expect(find.text('Tài khoản nhận hoàn'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Hoàn về tài khoản này'));
    await _settle(tester);
    expect(payments.chooseCalls, ['r1:payer']);

    // The server clears the flag once the refund leaves.
    handles.bookings.seedBooking(
      declined.copyWith(refundAccountNeeded: false),
    );
    await _settle(tester);
    expect(card, findsNothing);
  });

  testWidgets('the photographer never sees the refund card', (tester) async {
    await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      bookings: _repo(
        _booking(
          status: BookingStatus.declined,
          escrow: EscrowStatus.refunded,
        ).copyWith(depositRefunded: 1500000, refundAccountNeeded: true),
        copy: testContactSnapshot,
      ),
    );
    await _settle(tester);

    expect(find.byKey(const Key('detail-refund-account')), findsNothing);
  });

  testWidgets('the paid toast shows "Đã thanh toán 3.400.000₫…" and the block '
      'lists the add-ons and the pickup', (tester) async {
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      path: '/b/b1?paid=1',
      bookings: _repo(_withAddons(deposit: 3400000)),
    );
    await _settle(tester);

    expect(
      find.text('Đã thanh toán 3.400.000₫, tiền được giữ an toàn.'),
      findsOneWidget,
    );
    expect(find.text('Dịch vụ đi kèm'), findsOneWidget);
    expect(find.text('2 người × 800.000₫'), findsOneWidget);
    expect(find.text('Điểm đón: Ga Sài Gòn, Quận 3'), findsOneWidget);
  });

  testWidgets('the photographer sees the same block and the pickup', (
    tester,
  ) async {
    await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      bookings: _repo(
        _withAddons(deposit: 3400000),
        copy: testContactSnapshot,
      ),
    );
    await _settle(tester);

    expect(find.text('Dịch vụ đi kèm'), findsOneWidget);
    expect(find.text('Trang điểm'), findsOneWidget);
    expect(find.text('1.600.000₫'), findsOneWidget);
    expect(find.text('Điểm đón'), findsNothing);
    expect(find.text('Điểm đón: Ga Sài Gòn, Quận 3'), findsOneWidget);
  });

  testWidgets('a booking without add-ons shows no add-on block', (
    tester,
  ) async {
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(_booking()),
    );
    await _settle(tester);

    expect(find.text('Dịch vụ đi kèm'), findsNothing);
  });

  testWidgets(
    'first load shows BookingCard.skeleton and StatusTimeline.skeleton',
    (tester) async {
      final pending = Completer<Booking?>();
      await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        bookings: RecordingBookingRepository(),
        extraOverrides: [
          bookingProvider('b1').overrideWith((_) => pending.future.asStream()),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('booking_card_skeleton')), findsOne);
      expect(find.byKey(const ValueKey('status_timeline_skeleton')), findsOne);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Buổi chụp #B1'), findsOneWidget);
    },
  );

  testWidgets('customer, requested: title #code, toast after payment, card '
      'with Đã gửi, timeline step 2 current, Liên hệ dial and the cancel '
      'text with 100%', (tester) async {
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      path: '/b/b1?paid=1',
      bookings: _repo(_booking()),
    );
    await _settle(tester);

    expect(_codeFinder(ScreenCodes.bookingDetail), findsOneWidget);
    expect(find.text('Buổi chụp #B1'), findsOneWidget);
    expect(
      find.text(
        'Đã thanh toán 450.000₫, tiền được giữ an toàn.',
      ),
      findsOneWidget,
    );
    // The toast already says the deposit is held (mock): no second line.
    expect(find.byType(EscrowNotice), findsNothing);

    final card = tester.widget<BookingCard>(find.byType(BookingCard));
    expect(card.data.photographerName, 'Minh Trí');
    expect(card.data.day, 'T2 12/10');
    expect(_badge(BookingStatus.requested), findsOneWidget);

    final timeline = tester.widget<StatusTimeline>(find.byType(StatusTimeline));
    expect(timeline.steps, hasLength(8));
    expect(timeline.steps[1].state, TimelineStepState.current);
    expect(timeline.steps[1].title, 'Chờ Minh Trí nhận');

    expect(find.byType(ContactDial), findsOneWidget);
    expect(find.text('Liên hệ'), findsOneWidget);
    expect(find.text('Huỷ yêu cầu · hoàn 100%'), findsOneWidget);
  });

  testWidgets('without ?paid=1 the held deposit shows as an EscrowNotice', (
    tester,
  ) async {
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(_booking(status: BookingStatus.accepted)),
    );
    await _settle(tester);

    expect(find.textContaining('tiền được giữ an toàn.'), findsNothing);
    expect(
      tester.widget<EscrowNotice>(find.byType(EscrowNotice)).text,
      'Đã thanh toán 450.000₫, tiền được giữ an toàn',
    );
  });

  testWidgets('cancel button percent updates when the clock passes 48 h', (
    tester,
  ) async {
    final clock = TestClock(
      _startsAt.subtract(const Duration(hours: 48, seconds: 30)),
    );
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      clock: clock,
      bookings: _repo(_booking(status: BookingStatus.accepted)),
    );
    await _settle(tester);
    expect(find.text('Huỷ yêu cầu · hoàn 100%'), findsOneWidget);

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await _settle(tester);

    expect(find.text('Huỷ yêu cầu · hoàn 50%'), findsOneWidget);
    expect(find.text('Huỷ yêu cầu · hoàn 100%'), findsNothing);
  });

  testWidgets('customer Liên hệ asks the server for the link '
      '(contactLauncher) and never shows a number', (tester) async {
    final handles = await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(_booking(status: BookingStatus.accepted)),
    );
    handles.links.add(
      const ContactSubject.booking('b1'),
      numbers: const ContactNumbers(phone: '+84909876543'),
      channels: const ContactChannels(call: true, zalo: true),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('contact-dial-button')));
    await _settle(tester);
    await tester.tap(find.text('Gọi'));
    await _settle(tester);

    expect(handles.links.requests, [
      (
        subject: const ContactSubject.booking('b1'),
        channel: ContactChannel.call,
      ),
    ]);
    expect(handles.launcher.opened, [Uri.parse('tel:+84909876543')]);
    expect(find.textContaining('+84'), findsNothing);
    expect(find.textContaining('0909'), findsNothing);
  });

  testWidgets('photographer, requested: Nhận with countdown is the only '
      'primary button; Từ chối opens S06.03', (tester) async {
    final handles = await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      bookings: _repo(
        _booking(
          acceptDeadline: worldBookingToday.add(
            const Duration(hours: 22, minutes: 10),
          ),
        ),
        copy: testContactSnapshot,
      ),
    );
    await _settle(tester);

    expect(primaryButtonLabels(tester), ['Nhận · còn 22 giờ']);
    expect(find.text('Huỷ buổi chụp'), findsNothing);
    final timeline = tester.widget<StatusTimeline>(find.byType(StatusTimeline));
    expect(timeline.steps[1].title, 'Chờ bạn nhận');
    // The card names the customer for the photographer.
    expect(
      tester
          .widget<BookingCard>(find.byType(BookingCard))
          .data
          .photographerName,
      'Nguyễn Văn A',
    );

    await tester.tap(find.widgetWithText(AppButton, 'Từ chối'));
    await _settle(tester);
    expect(find.text('Từ chối yêu cầu của Nguyễn Văn A?'), findsOneWidget);
    expect(handles.bookings.transitions, isEmpty);
  });

  testWidgets('photographer accept calls transitionBooking(accept) and the '
      'screen follows the stream to accepted', (tester) async {
    final handles = await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      bookings: _repo(
        _booking(
          acceptDeadline: worldBookingToday.add(const Duration(hours: 22)),
        ),
        copy: testContactSnapshot,
      ),
    );
    await _settle(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Nhận · còn 22 giờ'));
    await _settle(tester);

    expect(handles.bookings.transitions, [
      (bookingId: 'b1', action: 'accept', reason: null),
    ]);
    expect(_badge(BookingStatus.accepted), findsOneWidget);
    expect(find.textContaining('Nhận ·'), findsNothing);
    expect(handles.location, '/b/b1');
  });

  testWidgets('photographer contact uses the contact copy channels and builds '
      'tel:/zalo.me locally', (tester) async {
    final handles = await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      bookings: _repo(
        _booking(status: BookingStatus.accepted),
        copy: testContactSnapshot, // phone, allowZalo
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('contact-dial-button')));
    await _settle(tester);
    expect(find.text('Gọi'), findsOneWidget);
    expect(find.text('Zalo'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);

    await tester.tap(find.text('Gọi'));
    await _settle(tester);
    expect(handles.launcher.opened, [Uri.parse('tel:+84903123456')]);
    expect(handles.links.requests, isEmpty);

    await tester.tap(find.byKey(const Key('contact-dial-button')));
    await _settle(tester);
    await tester.tap(find.text('Zalo'));
    await _settle(tester);
    expect(
      handles.launcher.opened.last,
      Uri.parse('https://zalo.me/84903123456'),
    );
  });

  testWidgets('photographer contact hides when the copy becomes null', (
    tester,
  ) async {
    final copies = StreamController<BookingContactSnapshot?>();
    addTearDown(copies.close);
    await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      bookings: _repo(_booking(status: BookingStatus.accepted)),
      extraOverrides: [
        bookingContactProvider('b1').overrideWith((_) => copies.stream),
      ],
    );
    copies.add(testContactSnapshot);
    await _settle(tester);
    expect(find.byKey(const Key('contact-dial-button')), findsOneWidget);

    // Unreadable now (cancelled, or 30 days after completion).
    copies.add(null);
    await _settle(tester);
    expect(find.byKey(const Key('contact-dial-button')), findsNothing);

    // A redacted copy keeps the name but has no number: still hidden.
    copies.add(const BookingContactSnapshot(name: 'Nguyễn Văn A'));
    await _settle(tester);
    expect(find.byKey(const Key('contact-dial-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Đã chụp xong appears for the photographer only after the end '
      'time and calls transitionBooking(mark_shot)', (tester) async {
    final clock = TestClock(_endsAt.subtract(const Duration(seconds: 30)));
    final handles = await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      clock: clock,
      bookings: _repo(
        _booking(status: BookingStatus.upcoming),
        copy: testContactSnapshot,
      ),
    );
    await _settle(tester);
    expect(find.widgetWithText(AppButton, 'Đã chụp xong'), findsNothing);

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await _settle(tester);

    final done = find.widgetWithText(AppButton, 'Đã chụp xong');
    expect(done, findsOneWidget);
    await tester.ensureVisible(done);
    await tester.tap(done);
    await _settle(tester);
    expect(handles.bookings.transitions, [
      (bookingId: 'b1', action: 'mark_shot', reason: null),
    ]);
  });

  testWidgets('Chỉ đường appears on the booking day and opens Google Maps '
      'search for the place', (tester) async {
    final handles = await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      now: DateTime.utc(2026, 10, 12, 2, 0), // 09:00 VN on the day
      bookings: _repo(_booking(status: BookingStatus.upcoming)),
    );
    await _settle(tester);

    final directions = find.widgetWithText(AppButton, 'Chỉ đường');
    expect(directions, findsOneWidget);
    await tester.ensureVisible(directions);
    await tester.tap(directions);
    await _settle(tester);
    expect(handles.launcher.opened, [
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': 'Bến Bạch Đằng',
      }),
    ]);
  });

  testWidgets('no Chỉ đường a week before the shoot', (tester) async {
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(_booking(status: BookingStatus.upcoming)),
    );
    await _settle(tester);
    expect(find.widgetWithText(AppButton, 'Chỉ đường'), findsNothing);
  });

  testWidgets('declined shows Đặt lại which opens the booking sheet for the '
      'same package', (tester) async {
    final handles = await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(
        _booking(status: BookingStatus.declined, escrow: EscrowStatus.refunded),
      ),
    );
    await _settle(tester);

    expect(find.byType(EscrowNotice), findsNothing);
    expect(find.byType(ContactDial), findsNothing);
    expect(primaryButtonLabels(tester), ['Đặt lại']);
    final timeline = tester.widget<StatusTimeline>(find.byType(StatusTimeline));
    expect(timeline.steps.last.title, 'Đã từ chối');
    expect(timeline.steps.last.state, TimelineStepState.stopped);

    await tester.tap(find.widgetWithText(AppButton, 'Đặt lại'));
    await _settle(tester);
    expect(handles.location, '/u/p1/book?serviceId=s1');
  });

  testWidgets('Nhắn tin and Đổi lịch stay hidden while their flags are off; '
      'appear when on (chatId present)', (tester) async {
    final booking = _booking(status: BookingStatus.accepted, chatId: 'chat1');
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(booking),
    );
    await _settle(tester);
    expect(find.widgetWithText(AppButton, 'Nhắn tin'), findsNothing);
    expect(find.byKey(const Key('detail-more')), findsNothing);

    final handles = await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(booking),
      features: const BookingFeatures(
        chat: true,
        reschedule: true,
        review: false,
      ),
    );
    await _settle(tester);
    expect(find.widgetWithText(AppButton, 'Nhắn tin'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-more')));
    await _settle(tester);
    expect(find.text('Đổi lịch'), findsOneWidget);

    await tester.tapAt(const Offset(5, 400)); // close the menu
    await _settle(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Nhắn tin'));
    await _settle(tester);
    expect(handles.location, '/chat/chat1');
  });

  testWidgets(
    'S05.02 Nhắn tin opens the booking chat; Đổi lịch opens it with the date sheet',
    (tester) async {
      final booking = _booking(status: BookingStatus.accepted, chatId: 'chat1');
      final handles = await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        bookings: _repo(booking),
        features: const BookingFeatures(
          chat: true,
          reschedule: true,
          review: false,
        ),
      );
      await _settle(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Nhắn tin'));
      await _settle(tester);
      expect(handles.location, '/chat/chat1');

      handles.router.pop();
      await _settle(tester);

      await tester.tap(find.byKey(const Key('detail-more')));
      await _settle(tester);
      await tester.tap(find.text('Đổi lịch'));
      await _settle(tester);
      expect(handles.location, '/chat/chat1?reschedule=1');
    },
  );

  testWidgets('deadline_passed from accept shows Yêu cầu đã hết hạn', (
    tester,
  ) async {
    final repo = _repo(
      _booking(
        acceptDeadline: worldBookingToday.add(const Duration(minutes: 30)),
      ),
      copy: testContactSnapshot,
    );
    repo.nextError = BookingErrorCode.deadlinePassed;
    await pumpBookingDetail(tester, uid: detailPhotographerUid, bookings: repo);
    await _settle(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Nhận · còn 30 phút'));
    await _settle(tester);

    expect(find.text('Yêu cầu đã hết hạn'), findsOneWidget);
    // Not stuck in flight.
    expect(
      tester
          .widget<AppButton>(
            find.widgetWithText(AppButton, 'Nhận · còn 30 phút').first,
          )
          .loading,
      isFalse,
    );
  });

  testWidgets('a booking of someone else shows Không tìm thấy buổi chụp', (
    tester,
  ) async {
    final handles = await pumpBookingDetail(
      tester,
      uid: 'stranger',
      bookings: _repo(_booking()),
    );
    await _settle(tester);

    expect(find.text('Không tìm thấy buổi chụp'), findsOneWidget);
    expect(find.byType(BookingCard), findsNothing);
    await tester.tap(find.widgetWithText(AppButton, 'Về trang chủ'));
    await _settle(tester);
    expect(handles.location, '/home');
  });

  testWidgets('a missing booking shows Không tìm thấy buổi chụp', (
    tester,
  ) async {
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: RecordingBookingRepository(),
    );
    await _settle(tester);
    expect(find.text('Không tìm thấy buổi chụp'), findsOneWidget);
  });

  testWidgets('/b/b1/cancel opens S05.02 with the cancel sheet', (
    tester,
  ) async {
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      path: '/b/b1/cancel',
      bookings: _repo(_booking(status: BookingStatus.accepted)),
    );
    await _settle(tester);

    expect(_codeFinder(ScreenCodes.bookingDetail), findsOneWidget);
    expect(find.byType(BookingDetailScreen), findsOneWidget);
    expect(find.text('Huỷ buổi chụp?'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Giữ lịch'), findsOneWidget);
  });

  testWidgets('the cancel text opens the cancel sheet; Huỷ buổi chụp cancels', (
    tester,
  ) async {
    final handles = await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: _repo(_booking(status: BookingStatus.accepted)),
    );
    await _settle(tester);

    final cancel = find.text('Huỷ yêu cầu · hoàn 100%');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await _settle(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Huỷ buổi chụp'));
    await _settle(tester);

    expect(handles.bookings.transitions.single.action, 'cancel');
    expect(_badge(BookingStatus.cancelled), findsOneWidget);
  });

  testWidgets('320 dp, 1.3× text, light and dark: no overflow; the dial does '
      'not cover the primary button', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final uid in [detailCustomerUid, detailPhotographerUid]) {
        await pumpBookingDetail(
          tester,
          uid: uid,
          clock: TestClock(_endsAt.add(const Duration(minutes: 5))),
          path: '/b/b1?paid=1',
          brightness: brightness,
          textScale: 1.3,
          viewSize: const Size(320, 640),
          features: const BookingFeatures(
            chat: true,
            reschedule: true,
            review: true,
          ),
          bookings: _repo(
            _booking(status: BookingStatus.upcoming, chatId: 'chat1'),
            copy: testContactSnapshot,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$brightness $uid');

        final dial = find.byKey(const Key('contact-dial-button'));
        expect(dial, findsOneWidget, reason: '$brightness $uid');
        if (uid == detailPhotographerUid) {
          final done = find.widgetWithText(AppButton, 'Đã chụp xong');
          await tester.ensureVisible(done);
          await tester.pump();
          final a = tester.getRect(dial);
          final b = tester.getRect(done);
          expect(a.overlaps(b), isFalse, reason: '$brightness');
        }
      }
    }
  });

  testWidgets('shows bookingBlockedNote and hides contact actions when parties are blocked', (
    tester,
  ) async {
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      clock: TestClock(_startsAt.subtract(const Duration(hours: 1))),
      bookings: _repo(_booking(status: BookingStatus.accepted, chatId: 'chat1')),
      extraOverrides: [
        hiddenUsersProvider.overrideWithValue({detailPhotographerUid}),
      ],
    );
    await _settle(tester);

    expect(
      find.text(
        'Hai bên đã chặn nhau. Cần trao đổi về buổi chụp, hãy liên hệ hỗ trợ.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('contact-dial-button')), findsNothing);
  });

  group('Provider delivery actions (S05.02 / Task 7)', () {
    testWidgets('shot shows Nộp bàn giao button', (tester) async {
      await pumpBookingDetail(
        tester,
        uid: detailPhotographerUid,
        bookings: _repo(_booking(status: BookingStatus.shot)),
      );
      await _settle(tester);

      expect(find.widgetWithText(AppButton, 'Nộp bàn giao'), findsOneWidget);
    });

    testWidgets('revision_requested shows notice card and Nộp vòng {round+1}', (tester) async {
      final b = _booking(status: BookingStatus.revisionRequested).copyWith(
        deliveryRound: 1,
      );
      await pumpBookingDetail(
        tester,
        uid: detailPhotographerUid,
        bookings: _repo(b),
      );
      await _settle(tester);

      expect(find.text('Khách muốn chỉnh sửa vòng 1'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'Nộp vòng 2'), findsOneWidget);
    });

    testWidgets('delivered shows waiting approval message and no primary action', (tester) async {
      final b = _booking(status: BookingStatus.delivered).copyWith(
        deliveryRound: 1,
      );
      await pumpBookingDetail(
        tester,
        uid: detailPhotographerUid,
        bookings: _repo(b),
      );
      await _settle(tester);

      expect(find.text('Đã gửi vòng 1 · chờ khách duyệt'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Nộp bàn giao'), findsNothing);
    });

    testWidgets('delivered with pending extra round shows _ExtraRoundCard and actions', (tester) async {
      final b = _booking(status: BookingStatus.delivered).copyWith(
        deliveryRound: 2,
        extraRound: ExtraRound(
          at: DateTime.utc(2026, 10, 17, 12),
          status: 'pending',
        ),
      );
      await pumpBookingDetail(
        tester,
        uid: detailPhotographerUid,
        bookings: _repo(b, copy: testContactSnapshot),
      );
      await _settle(tester);

      expect(find.textContaining('xin thêm 1 vòng sửa'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cho thêm 1 vòng'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Không thêm'), findsOneWidget);
    });

    testWidgets('approved shows success card for provider', (tester) async {
      final b = _booking(status: BookingStatus.approved).copyWith(
        deliveryRound: 1,
      );
      await pumpBookingDetail(
        tester,
        uid: detailPhotographerUid,
        bookings: _repo(b),
      );
      await _settle(tester);

      expect(
        find.text('Khách đã đồng ý ảnh; tiền chuyển sau 48 giờ kiểm tra'),
        findsOneWidget,
      );
    });
  });

  group('S18 disputes on S05.02', () {
    /// The detail world's "now".
    final now = worldBookingToday;

    /// Shot 6 hours ago: 18 hours left in the shoot window.
    Booking shotBooking({String? disputeId, EscrowStatus? escrow}) =>
        _booking(
          status: BookingStatus.shot,
          escrow: escrow ?? EscrowStatus.held,
        ).copyWith(
          shotAt: now.subtract(const Duration(hours: 6)),
          disputeId: disputeId,
        );

    List<Override> disputeOverrides(DisputeWorld w) => [
      disputeRepositoryProvider.overrideWithValue(w.repo),
      imagePickerProvider.overrideWithValue(w.picker),
    ];

    testWidgets('the red "Báo vấn đề · còn 18 giờ" opens S18.01 and a success '
        'pushes /disputes/:id', (tester) async {
      final w = DisputeWorld(now: now);
      final handles = await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        bookings: _repo(shotBooking()),
        extraOverrides: disputeOverrides(w),
      );
      await _settle(tester);

      final report = find.widgetWithText(AppButton, 'Báo vấn đề · còn 18 giờ');
      expect(report, findsOneWidget);
      final style = tester.widget<AppButton>(report).style;
      expect(
        style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColorsDark.destructive,
      );

      await tester.ensureVisible(report);
      await tester.tap(report);
      await _settle(tester);
      expect(_codeFinder(ScreenCodes.openDispute), findsOneWidget);
      expect(
        find.text(
          'Còn 18 giờ để báo vấn đề. Tiền của buổi chụp được giữ tới khi có '
          'kết quả.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Thợ không đến'));
      await tester.enterText(
        find.byKey(const Key('dispute-description')),
        'Đợi 1 tiếng mà thợ không tới.',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('dispute-submit')));
      await tester.tap(find.byKey(const Key('dispute-submit')));
      await _settle(tester);

      final draft = w.repo.opened.single;
      expect(draft.subjectId, 'b1');
      expect(handles.location, '/disputes/${draft.disputeId}');
    });

    testWidgets('the photographer has no "Báo vấn đề"', (tester) async {
      final w = DisputeWorld(now: now, uid: detailPhotographerUid);
      await pumpBookingDetail(
        tester,
        uid: detailPhotographerUid,
        bookings: _repo(shotBooking(), copy: testContactSnapshot),
        extraOverrides: disputeOverrides(w),
      );
      await _settle(tester);
      expect(find.textContaining('Báo vấn đề'), findsNothing);
    });

    testWidgets('/b/:id/dispute opens the sheet over S05.02', (tester) async {
      final w = DisputeWorld(now: now);
      await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        path: '/b/b1/dispute',
        bookings: _repo(shotBooking()),
        extraOverrides: disputeOverrides(w),
      );
      await _settle(tester);
      expect(_codeFinder(ScreenCodes.bookingDetail), findsOneWidget);
      expect(_codeFinder(ScreenCodes.openDispute), findsOneWidget);
      expect(find.text('Vấn đề là gì?'), findsOneWidget);
    });

    testWidgets('?from=delivery opens the delivery variant', (tester) async {
      final w = DisputeWorld(now: now);
      final approved = _booking(status: BookingStatus.approved).copyWith(
        approvedAt: now.subtract(const Duration(hours: 1)),
        checkUntil: now.add(const Duration(hours: 47)),
      );
      await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        path: '/b/b1/dispute?from=delivery',
        bookings: _repo(approved),
        extraOverrides: disputeOverrides(w),
      );
      await _settle(tester);
      expect(find.text('Báo vấn đề với ảnh gốc'), findsOneWidget);
      expect(
        find.text(
          'Còn 47 giờ để kiểm tra bộ ảnh gốc. Đợt thanh toán thứ hai được '
          'giữ tới khi có kết quả.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('/b/:id/dispute outside the window opens nothing', (
      tester,
    ) async {
      final w = DisputeWorld(now: now);
      await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        path: '/b/b1/dispute',
        bookings: _repo(_booking(status: BookingStatus.upcoming)),
        extraOverrides: disputeOverrides(w),
      );
      await _settle(tester);
      expect(_codeFinder(ScreenCodes.openDispute), findsNothing);
    });

    for (final uid in [detailCustomerUid, detailPhotographerUid]) {
      testWidgets('a booking with disputeId shows "Đang khiếu nại" for $uid '
          'and opens /disputes/:id', (tester) async {
        final w = DisputeWorld(now: now, uid: uid);
        final handles = await pumpBookingDetail(
          tester,
          uid: uid,
          bookings: _repo(
            shotBooking(disputeId: 'dK7Q2', escrow: EscrowStatus.disputed),
            copy: testContactSnapshot,
          ),
          extraOverrides: disputeOverrides(w),
        );
        await _settle(tester);

        expect(find.text('Đang khiếu nại'), findsOneWidget);
        expect(find.text('Tiền được giữ tới khi có kết quả.'), findsOneWidget);
        expect(find.text('Xem khiếu nại'), findsOneWidget);
        expect(find.textContaining('Báo vấn đề'), findsNothing);

        await tester.tap(find.byKey(const Key('dispute-banner')));
        await _settle(tester);
        expect(handles.location, '/disputes/dK7Q2');
      });
    }

    testWidgets('the resolved banner reads "Khiếu nại đã có kết quả"', (
      tester,
    ) async {
      final w = DisputeWorld(now: now);
      await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        bookings: _repo(
          shotBooking(disputeId: 'dK7Q2', escrow: EscrowStatus.released),
        ),
        extraOverrides: disputeOverrides(w),
      );
      await _settle(tester);
      expect(find.text('Khiếu nại đã có kết quả'), findsOneWidget);
      expect(find.text('Đang khiếu nại'), findsNothing);
      expect(find.text('Xem khiếu nại'), findsOneWidget);
    });
  });

  group('S05.02 late delivery cancel (#207)', () {
    final now = DateTime.utc(2026, 10, 18, 9);
    const lateMilestones = BookingMilestones(
      shootAmount: 500000,
      deliveryAmount: 500000,
      shootStatus: 'released',
      deliveryStatus: 'held',
    );

    Booking lateShotBooking() =>
        _booking(status: BookingStatus.shot, chatId: 'chat1').copyWith(
          deposit: 1000000,
          remaining: 0,
          shotAt: DateTime.utc(2026, 10, 12, 9),
          deliveryDays: 5,
        );

    testWidgets(
      'customer sees LateDeliveryCard only when late; tapping opens the sheet; '
      'after success the toast "Đã huỷ phần bàn giao · hoàn 500.000₫" shows '
      'and the Nhắn tin button stays',
      (tester) async {
        // Not yet late: no LateDeliveryCard.
        final onTime = lateShotBooking().copyWith(
          shotAt: DateTime.utc(2026, 10, 15, 9),
        );
        await pumpBookingDetail(
          tester,
          uid: detailCustomerUid,
          clock: TestClock(now),
          bookings: _repo(onTime),
          features: const BookingFeatures(
            chat: true,
            reschedule: false,
            review: false,
          ),
        );
        await _settle(tester);
        expect(find.byType(LateDeliveryCard), findsNothing);

        // Late: LateDeliveryCard shows; primary CTA has no late-cancel action.
        final repo = _repo(lateShotBooking())
          ..milestones['b1'] = lateMilestones;
        await pumpBookingDetail(
          tester,
          uid: detailCustomerUid,
          clock: TestClock(now),
          bookings: repo,
          features: const BookingFeatures(
            chat: true,
            reschedule: false,
            review: false,
          ),
        );
        await _settle(tester);

        expect(find.byType(LateDeliveryCard), findsOneWidget);
        expect(find.text('Hạn bàn giao 17/10 · đã quá 1 ngày'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Nhắn tin'), findsOneWidget);

        await tester.tap(find.byKey(const Key('late-delivery-cancel')));
        await _settle(tester);
        expect(find.text('Huỷ phần bàn giao?'), findsOneWidget);

        await tester.tap(find.byKey(const Key('late-cancel-confirm')));
        await _settle(tester);

        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text('Đã huỷ phần bàn giao · hoàn 500.000₫'),
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(AppButton, 'Nhắn tin'), findsOneWidget);
        expect(_badge(BookingStatus.completed), findsOneWidget);
      },
    );

    testWidgets(
      'provider sees detailLateCancelledProvider on a completed booking with '
      'deliveryCancel and no "Nộp bàn giao"',
      (tester) async {
        final cancelled = lateShotBooking().copyWith(
          status: BookingStatus.completed,
          completedAt: now,
          deliveryCancel: DeliveryCancel(
            at: now,
            dueAt: DateTime.utc(2026, 10, 17, 9),
            refundedAmount: 500000,
          ),
        );
        await pumpBookingDetail(
          tester,
          uid: detailPhotographerUid,
          clock: TestClock(now),
          bookings: _repo(cancelled),
        );
        await _settle(tester);

        expect(
          find.text(
            'Khách đã huỷ phần bàn giao vì quá hạn (hạn 17/10). '
            'Bạn giữ mốc 1, mốc 2 đã hoàn cho khách.',
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(AppButton, 'Nộp bàn giao'), findsNothing);
      },
    );

    testWidgets(
      'golden-free layout at 320 dp, 1.3×, dark and light on late shot booking',
      (tester) async {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await pumpBookingDetail(
            tester,
            uid: detailCustomerUid,
            clock: TestClock(now),
            brightness: brightness,
            textScale: 1.3,
            viewSize: const Size(320, 640),
            bookings: _repo(lateShotBooking())
              ..milestones['b1'] = lateMilestones,
            features: const BookingFeatures(
              chat: true,
              reschedule: false,
              review: false,
            ),
          );
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: '$brightness');
          expect(find.byType(LateDeliveryCard), findsOneWidget);
        }
      },
    );
  });
}
