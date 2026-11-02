// test/features/event_manage/manage_event_screen_test.dart
//
// S12.03. No camera here: "Quét mã" opens S30.07 (`/scan?event=`, tested
// in test/features/scan); every fake stream emits at once, and pumps are
// bounded (`settle`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/event_create/create_event_screen.dart';

import '../../support/event_world.dart';

const _path = '/events/ev1/manage';

/// 13/10 08:00 in Việt Nam: the event day, two hours before the start.
final _eventDay = eventNow.add(const Duration(days: 3, hours: -2));

/// The host (p1) of ev1, signed in.
EventsWorld _host({
  int priceVnd = 250000,
  int registered = 5,
  EventStatus status = EventStatus.open,
  List<EventRegistration> registrations = const [],
  DateTime? now,
}) => EventsWorld(
  uid: 'p1',
  role: UserRole.photographer,
  onboardingComplete: true,
  now: now,
  events: [
    detailOf('ev1', priceVnd: priceVnd, registered: registered, status: status),
  ],
  registrations: registrations,
);

Future<void> _open(
  WidgetTester tester,
  EventsWorld w, {
  Size size = const Size(390, 900),
  double textScale = 1,
}) => w.pump(
  tester,
  path: _path,
  organizer: true,
  size: size,
  textScale: textScale,
);

String _kpi(WidgetTester tester, String key) =>
    tester.widget<StatTile>(find.byKey(Key(key))).value;

bool _scanEnabled(WidgetTester tester) =>
    tester.widget<AppButton>(find.byKey(const Key('manage-scan'))).onPressed !=
    null;

/// Badges are set in capitals (mock `.badge`).
String _badge(String label) => label.toUpperCase();

/// [r] with the fields the paid path adds (late cancel, event refund).
EventRegistration _with(
  EventRegistration r, {
  RegistrationStatus? status,
  int? refundPercent,
  bool refundDue = false,
}) => EventRegistration(
  id: r.id,
  eventId: r.eventId,
  userId: r.userId,
  userName: r.userName,
  ticketCode: r.ticketCode,
  quantity: r.quantity,
  amount: r.amount,
  status: status ?? r.status,
  event: r.event,
  createdAt: r.createdAt,
  refundPercent: refundPercent,
  refundDue: refundDue,
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

void main() {
  testWidgets('KPIs show registered, revenue dash for free, days left', (
    tester,
  ) async {
    final w = _host(
      priceVnd: 0,
      registered: 2,
      registrations: [
        registrationOf('r1', 'ev1', userName: 'Lan Anh', quantity: 2),
      ],
    );
    await _open(tester, w);

    expect(find.text('Quản lý sự kiện'), findsOneWidget);
    expect(_kpi(tester, 'manage-kpi-registered'), '2/20');
    expect(_kpi(tester, 'manage-kpi-revenue'), '—');
    expect(find.text('0₫'), findsNothing);
    // 10/10 10:00 → 13/10 (Việt Nam days).
    expect(_kpi(tester, 'manage-kpi-days'), '3');
    expect(find.text(_badge('Đang mở')), findsOneWidget);
    expect(find.text('Người tham gia'), findsOneWidget);
  });

  testWidgets('a paid event shows the money of its paid tickets', (
    tester,
  ) async {
    final w = _host(
      registrations: [
        registrationOf('r1', 'ev1', quantity: 2, amount: 500000),
        registrationOf(
          'r2',
          'ev1',
          userId: 'u2',
          status: RegistrationStatus.held,
          amount: 250000,
        ),
      ],
    );
    await _open(tester, w);
    expect(
      _kpi(tester, 'manage-kpi-revenue'),
      formatMoney(500000, short: true),
    );
  });

  testWidgets('revenue sums paid tickets only', (tester) async {
    final w = _host(
      registrations: [
        registrationOf('r1', 'ev1', quantity: 4, amount: 3000000),
        registrationOf('r2', 'ev1', userId: 'u2', amount: 500000),
        registrationOf(
          'r3',
          'ev1',
          userId: 'u3',
          status: RegistrationStatus.held,
          amount: 250000,
        ),
        _with(
          registrationOf('r4', 'ev1', userId: 'u4', amount: 250000),
          status: RegistrationStatus.refunded,
          refundPercent: 100,
        ),
        _with(
          registrationOf('r5', 'ev1', userId: 'u5', amount: 250000),
          status: RegistrationStatus.cancelled,
          refundPercent: 0,
        ),
      ],
    );
    await _open(tester, w);
    expect(_kpi(tester, 'manage-kpi-revenue'), '3,5M');
  });

  testWidgets('held rows say Chờ trả', (tester) async {
    final w = _host(
      registrations: [
        registrationOf(
          'r1',
          'ev1',
          status: RegistrationStatus.held,
          amount: 250000,
        ),
      ],
    );
    await _open(tester, w);
    expect(find.text(_badge('Chờ trả')), findsOneWidget);
    expect(find.text(_badge('Đã trả')), findsNothing);
  });

  testWidgets('cancel sheet totals refunds', (tester) async {
    final w = _host(
      registrations: [
        registrationOf('r1', 'ev1', quantity: 2, amount: 500000),
        // Cancelled late (no refund, money held for the host): a host cancel
        // gives it back too.
        _with(
          registrationOf('r2', 'ev1', userId: 'u2', amount: 250000),
          status: RegistrationStatus.cancelled,
          refundPercent: 0,
        ),
        registrationOf(
          'r3',
          'ev1',
          userId: 'u3',
          status: RegistrationStatus.held,
          amount: 250000,
        ),
      ],
    );
    await _open(tester, w);
    await _tap(tester, find.text('Huỷ sự kiện · hoàn tiền mọi vé'));
    expect(find.text('3 vé · hoàn ${formatMoney(750000)}'), findsOneWidget);
  });

  testWidgets('participants show code and contact only for paid rows', (
    tester,
  ) async {
    final w = _host(
      registrations: [
        registrationOf(
          'r1',
          'ev1',
          userName: 'Lan Anh',
          quantity: 2,
          amount: 500000,
          ticketCode: 'VE-7K2Q-1013',
          contactEligible: true,
        ),
        registrationOf(
          'r2',
          'ev1',
          userId: 'u2',
          userName: 'Thảo Vy',
          status: RegistrationStatus.held,
          amount: 250000,
        ),
      ],
    );
    w.repo.contacts['ev1/r1'] = const BookingContactSnapshot(
      name: 'Lan Anh',
      phone: '+84903123456',
      allowZalo: true,
      allowWhatsApp: false,
    );
    w.repo.contacts['ev1/r2'] = const BookingContactSnapshot(
      name: 'Thảo Vy',
      phone: '+84903000000',
      allowZalo: true,
      allowWhatsApp: false,
    );
    await _open(tester, w);

    expect(find.text('Lan Anh'), findsOneWidget);
    expect(find.text('2 vé · VE-7K2Q-1013'), findsOneWidget);
    expect(find.text(_badge('Đã trả')), findsOneWidget);
    expect(find.byKey(const Key('manage-dial-r1')), findsOneWidget);

    expect(find.text('Thảo Vy'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('manage-row-sub-r2'))).data,
      '1 vé',
    );
    expect(find.text(_badge('Chờ trả')), findsOneWidget);
    expect(find.byKey(const Key('manage-dial-r2')), findsNothing);
  });

  testWidgets('a free ticket shows neither code nor contact (O3)', (
    tester,
  ) async {
    final w = _host(
      priceVnd: 0,
      registered: 1,
      registrations: [
        registrationOf('r1', 'ev1', userName: 'Lan Anh', contactEligible: true),
      ],
    );
    w.repo.contacts['ev1/r1'] = const BookingContactSnapshot(
      name: 'Lan Anh',
      phone: '+84903123456',
      allowZalo: true,
      allowWhatsApp: false,
    );
    await _open(tester, w);
    expect(
      tester.widget<Text>(find.byKey(const Key('manage-row-sub-r1'))).data,
      '1 vé',
    );
    expect(find.textContaining('VE-'), findsNothing);
    expect(find.byKey(const Key('manage-dial-r1')), findsNothing);
  });

  testWidgets('no registrations shows Chưa có người đăng ký and share', (
    tester,
  ) async {
    final w = _host(registered: 0);
    await _open(tester, w);
    expect(find.text('Chưa có người đăng ký'), findsOneWidget);
    expect(find.byKey(const Key('manage-empty-share')), findsOneWidget);
  });

  testWidgets('Quét mã opens S30.07 for this event (the scanner moved)', (
    tester,
  ) async {
    final w = _host(
      now: _eventDay,
      registrations: [
        registrationOf('r1', 'ev1', userName: 'Lan Anh', quantity: 2),
      ],
    );
    await _open(tester, w);
    expect(_scanEnabled(tester), isTrue);
    await _tap(tester, find.byKey(const Key('manage-scan')));
    expect(w.location, '/scan?event=ev1');
  });

  testWidgets('the Check‑in link opens the same scanner (O3)', (tester) async {
    final w = _host(
      now: _eventDay,
      registrations: [
        registrationOf('r1', 'ev1', userName: 'Lan Anh', quantity: 2),
      ],
    );
    await _open(tester, w);
    final link = find.byKey(const Key('manage-checkin-link'));
    expect(
      find.descendant(of: link, matching: find.text('Check‑in')),
      findsOneWidget,
    );
    expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
    await _tap(tester, link);
    expect(w.location, '/scan?event=ev1');
  });

  testWidgets('the Check‑in link follows the scan window (O3)', (tester) async {
    final w = _host(
      now: _eventDay.subtract(const Duration(hours: 8, minutes: 1)),
    );
    await _open(tester, w);
    expect(_scanEnabled(tester), isFalse);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('manage-checkin-link')))
          .onPressed,
      isNull,
    );
  });

  // detailOf: starts eventNow + 3 days, ends two hours later.
  final end = eventNow.add(const Duration(days: 3, hours: 2));

  testWidgets('scan stays open until two hours after the end', (tester) async {
    final w = _host(now: end.add(const Duration(hours: 1, minutes: 59)));
    await _open(tester, w);
    expect(_scanEnabled(tester), isTrue);
  });

  testWidgets('before the event day scan is off and says when it opens', (
    tester,
  ) async {
    // eventNow is three days before; 12/10 23:59 VN is one minute early.
    final w = _host(
      now: _eventDay.subtract(const Duration(hours: 8, minutes: 1)),
    );
    await _open(tester, w);
    expect(_scanEnabled(tester), isFalse);
    expect(
      tester
          .widget<Tooltip>(
            find.ancestor(
              of: find.byKey(const Key('manage-scan')),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      'Chưa tới ngày diễn ra. Check‑in mở từ 00:00 hôm đó.',
    );
  });

  testWidgets('scan opens at 00:00 on the event day', (tester) async {
    final w = _host(now: _eventDay.subtract(const Duration(hours: 8)));
    await _open(tester, w);
    expect(_scanEnabled(tester), isTrue);
  });

  testWidgets('scan is disabled two hours after the end', (tester) async {
    final w = _host(now: end.add(const Duration(hours: 2, minutes: 1)));
    await _open(tester, w);
    expect(_scanEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('manage-scan')));
    await settle(tester);
    expect(w.location, isNot(startsWith('/scan')));
  });

  testWidgets('cancel asks with the count and calls cancelEvent', (
    tester,
  ) async {
    final w = _host(
      registrations: [
        registrationOf('r1', 'ev1', quantity: 2, amount: 500000),
        registrationOf(
          'r2',
          'ev1',
          userId: 'u2',
          status: RegistrationStatus.held,
          amount: 250000,
        ),
      ],
    );
    await _open(tester, w);

    await _tap(tester, find.text('Huỷ sự kiện · hoàn tiền mọi vé'));
    expect(find.text('Huỷ sự kiện này?'), findsOneWidget);
    expect(find.text('3 vé · hoàn ${formatMoney(500000)}'), findsOneWidget);
    expect(w.repo.cancelledEvents, isEmpty);

    await _tap(tester, find.text('Huỷ sự kiện'));
    expect(w.repo.cancelledEvents, ['ev1']);
    expect(find.text('Đã huỷ sự kiện'), findsOneWidget);
    expect(find.byKey(const Key('manage-cancelled-strip')), findsOneWidget);
  });

  testWidgets('cancelling a free event says Không có khoản hoàn, never 0₫', (
    tester,
  ) async {
    final w = _host(
      priceVnd: 0,
      registered: 1,
      registrations: [registrationOf('r1', 'ev1')],
    );
    await _open(tester, w);
    // Nothing to refund: the link says only "Huỷ sự kiện".
    expect(find.text('Huỷ sự kiện · hoàn tiền mọi vé'), findsNothing);
    await _tap(tester, find.byKey(const Key('manage-cancel')));
    expect(find.text('1 vé · Không có khoản hoàn'), findsOneWidget);
    expect(find.textContaining('0₫'), findsNothing);
    await _tap(tester, find.text('Giữ sự kiện'));
    expect(w.repo.cancelledEvents, isEmpty);
  });

  testWidgets('a cancelled event is read-only', (tester) async {
    final w = _host(
      status: EventStatus.cancelled,
      registrations: [registrationOf('r1', 'ev1')],
    );
    await _open(tester, w);
    expect(find.text(_badge('Đã huỷ')), findsOneWidget);
    expect(find.byKey(const Key('manage-cancelled-strip')), findsOneWidget);
    expect(find.byKey(const Key('manage-scan')), findsNothing);
    expect(find.byKey(const Key('manage-broadcast')), findsNothing); // M5
    expect(find.byKey(const Key('manage-checkin-link')), findsNothing);
    expect(find.byKey(const Key('manage-cancel')), findsNothing);
    expect(find.byKey(const Key('manage-empty-share')), findsNothing);
  });

  testWidgets('Nhắn nhóm pins an announcement', (tester) async {
    final w = _host();
    await _open(tester, w);
    // One primary action: the scan button; Nhắn nhóm is secondary.
    expect(find.byType(CtaSurface), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage-broadcast')));
    await settle(tester);
    expect(find.text('Ghim thông báo vào nhóm'), findsOneWidget);
    // Empty: nothing to send.
    expect(
      tester
          .widget<AppButton>(find.byKey(const Key('announce-send')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('announce-text')),
      '  Tập trung 7h45 nhé  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('announce-send')));
    await settle(tester);
    expect(w.chat.announcements.single, 'Tập trung 7h45 nhé');
    expect(find.text('Đã ghim thông báo vào nhóm'), findsOneWidget);
    expect(find.text('Ghim thông báo vào nhóm'), findsNothing);
  });

  testWidgets('a failed announcement stays open with the reason', (
    tester,
  ) async {
    final w = _host();
    w.chat.failWith = StateError('offline');
    await _open(tester, w);
    await tester.tap(find.byKey(const Key('manage-broadcast')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('announce-text')), 'Xin chào');
    await tester.pump();
    await tester.tap(find.byKey(const Key('announce-send')));
    await settle(tester);
    expect(find.byKey(const Key('announce-error')), findsOneWidget);
    expect(find.text('Ghim thông báo vào nhóm'), findsOneWidget);
    w.chat.failWith = null;
    await tester.tap(find.byKey(const Key('announce-send')));
    await settle(tester);
    expect(w.chat.announcements.single, 'Xin chào');
    // M3: the retry reuses the first attempt's clientId (the server posts once).
    expect(w.chat.announcementIds, hasLength(2));
    expect(w.chat.announcementIds.toSet(), hasLength(1));
  });

  testWidgets('closing the announcement sheet with text asks first', (
    tester,
  ) async {
    final w = _host();
    await _open(tester, w);
    await tester.tap(find.byKey(const Key('manage-broadcast')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('announce-close'))); // empty: closes
    await settle(tester);
    expect(find.text('Ghim thông báo vào nhóm'), findsNothing);
    await tester.tap(find.byKey(const Key('manage-broadcast')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('announce-text')), 'Dở dang');
    await tester.tap(find.byKey(const Key('announce-close')));
    await settle(tester);
    expect(find.text('Bỏ bài đang soạn?'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục soạn'));
    await settle(tester);
    expect(find.text('Ghim thông báo vào nhóm'), findsOneWidget);
    expect(w.chat.announcements, isEmpty);
  });

  testWidgets('Bài chờ duyệt shows the count and opens the review mode', (
    tester,
  ) async {
    final w = EventsWorld(
      uid: 'p1',
      role: UserRole.photographer,
      onboardingComplete: true,
      events: [detailOf('ev1')],
      timelineItems: {
        'ev1': [
          timelineItemOf('w1', 'Chờ 1', status: TimelineStatus.pending),
          timelineItemOf('w2', 'Chờ 2', status: TimelineStatus.pending),
          timelineItemOf('v1', 'Đã đăng'),
        ],
      },
    );
    await _open(tester, w);
    expect(find.text('Bài chờ duyệt'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('manage-pending-count'))).data,
      '2',
    );
    await tester.tap(find.byKey(const Key('manage-pending-row')));
    await settle(tester);
    expect(w.location, '/e/ev1/timeline?review=1');
  });

  testWidgets('a draft resumes in S12.01', (tester) async {
    final w = _host(status: EventStatus.draft, registered: 0);
    await _open(tester, w);
    expect(w.location, '/events/new?draft=ev1');
    expect(find.byType(CreateEventScreen), findsOneWidget);
  });

  testWidgets('a staff-made draft asks the named host to accept (O1)', (
    tester,
  ) async {
    final w = EventsWorld(
      uid: 'p1',
      role: UserRole.photographer,
      onboardingComplete: true,
      events: [
        detailOf(
          'ev1',
          createdBy: 'staff1',
          status: EventStatus.draft,
          registered: 0,
          hostConsent: HostConsent.pending,
          hostConsentExpiresAt: eventNow.add(const Duration(hours: 20)),
        ),
      ],
    );
    await _open(tester, w);
    expect(find.text('Lời mời tổ chức sự kiện'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('manage-accept')));
    expect(w.repo.consentAnswers.single, (eventId: 'ev1', accept: true));
  });

  testWidgets('320 dp at 1.3× text fits', (tester) async {
    final w = _host(
      registrations: [
        registrationOf(
          'r1',
          'ev1',
          userName: 'Nguyễn Thị Lan Anh',
          quantity: 2,
          amount: 500000,
          ticketCode: 'VE-7K2Q-1013',
        ),
      ],
    );
    await _open(tester, w, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('manage-scan')), findsOneWidget);
  });

  group('S12.03 venue status', () {
    const managed = EventVenue(
      kind: VenueKind.managedSpot,
      spotId: 'bd',
      termsVersion: organizerTermsVersion,
    );

    EventsWorld world({
      EventStatus status = EventStatus.open,
      HostConsent consent = HostConsent.accepted,
      int fee = 0,
      String createdBy = 'p1',
    }) => EventsWorld(
      uid: 'p1',
      role: UserRole.photographer,
      onboardingComplete: true,
      events: [
        detailOf(
          'ev1',
          status: status,
          createdBy: createdBy,
          venue: managed,
          venueConsent: consent,
          venueFeePerGuest: fee,
        ),
      ],
    );

    String line(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('manage-venue-status'))).data!;

    testWidgets(
      'accepted with a fee: "Địa điểm: đã đồng ý · phí quản lý {x}"',
      (tester) async {
        await _open(tester, world(fee: 50000));
        expect(line(tester), 'Địa điểm: đã đồng ý · phí quản lý 50.000₫');
      },
    );

    testWidgets('accepted without a fee: no amount, never 0₫', (tester) async {
      await _open(tester, world());
      expect(line(tester), 'Địa điểm: đã đồng ý');
    });

    testWidgets(
      'my published-at-a-managed-spot draft stays here: "Địa điểm: chờ đồng ý"',
      (tester) async {
        final w = world(
          status: EventStatus.draft,
          consent: HostConsent.pending,
        );
        await _open(tester, w);
        expect(w.location, _path, reason: 'not sent back to the editor');
        expect(line(tester), 'Địa điểm: chờ đồng ý');
      },
    );

    testWidgets('declined: the line says so', (tester) async {
      await _open(
        tester,
        world(status: EventStatus.cancelled, consent: HostConsent.declined),
      );
      expect(line(tester), 'Địa điểm: đã từ chối');
    });

    testWidgets('no line for an event without a managed venue', (tester) async {
      await _open(tester, _host());
      expect(find.byKey(const Key('manage-venue-status')), findsNothing);
    });

    testWidgets('fits 320 dp at 1.3× text with the venue line', (tester) async {
      await _open(
        tester,
        world(fee: 50000),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
