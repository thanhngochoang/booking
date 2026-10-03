import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/features/booking/booking_features.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';

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
        'Cọc 450.000₫ đang được giữ an toàn. Minh Trí sẽ trả lời trong 24 giờ.',
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
    expect(timeline.steps, hasLength(7));
    expect(timeline.steps[1].state, TimelineStepState.current);
    expect(timeline.steps[1].title, 'Chờ Minh Trí nhận');

    expect(find.byType(ContactDial), findsOneWidget);
    expect(find.text('Liên hệ'), findsOneWidget);
    expect(find.text('Huỷ yêu cầu · hoàn cọc 100%'), findsOneWidget);
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

    expect(find.textContaining('Minh Trí sẽ trả lời'), findsNothing);
    expect(
      tester.widget<EscrowNotice>(find.byType(EscrowNotice)).text,
      'Cọc 450.000₫ đang được giữ an toàn',
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
    expect(find.text('Huỷ yêu cầu · hoàn cọc 100%'), findsOneWidget);

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await _settle(tester);

    expect(find.text('Huỷ yêu cầu · hoàn cọc 50%'), findsOneWidget);
    expect(find.text('Huỷ yêu cầu · hoàn cọc 100%'), findsNothing);
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

  testWidgets('Hoàn thành appears for the photographer only after the end '
      'time and calls transitionBooking(complete)', (tester) async {
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
    expect(find.widgetWithText(AppButton, 'Hoàn thành'), findsNothing);

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await _settle(tester);

    final done = find.widgetWithText(AppButton, 'Hoàn thành');
    expect(done, findsOneWidget);
    await tester.ensureVisible(done);
    await tester.tap(done);
    await _settle(tester);
    expect(handles.bookings.transitions, [
      (bookingId: 'b1', action: 'complete', reason: null),
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

    final cancel = find.text('Huỷ yêu cầu · hoàn cọc 100%');
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
          final done = find.widgetWithText(AppButton, 'Hoàn thành');
          await tester.ensureVisible(done);
          await tester.pump();
          final a = tester.getRect(dial);
          final b = tester.getRect(done);
          expect(a.overlaps(b), isFalse, reason: '$brightness');
        }
      }
    }
  });
}
