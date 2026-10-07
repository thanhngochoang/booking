// test/features/event_manage/manage_event_screen_test.dart
//
// S12.03. No camera, no endless animation: the scanner is the fake from
// `test/support`, every fake stream emits at once, and pumps are bounded
// (`settle`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/event_create/create_event_screen.dart';

import '../../support/event_world.dart';

const _path = '/events/ev1/manage';

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

  testWidgets('scan success says Đã vào', (tester) async {
    final w = _host(
      registrations: [
        registrationOf('r1', 'ev1', userName: 'Lan Anh', quantity: 2),
      ],
    );
    w.scanner.enqueue('VE-AB2C-1013');
    await _open(tester, w);
    expect(_scanEnabled(tester), isTrue);

    await _tap(tester, find.byKey(const Key('manage-scan')));
    expect(w.repo.checkedIn, ['VE-AB2C-1013']);
    expect(find.text('Đã vào · Lan Anh · 2 vé'), findsOneWidget);

    // "Quét tiếp" asks the scanner again; closing it ends the loop.
    await _tap(tester, find.byKey(const Key('checkin-next')));
    expect(w.scanner.calls, 2);
    expect(find.byKey(const Key('checkin-result')), findsNothing);
    expect(find.text(_badge('Đã vào')), findsOneWidget); // the row's badge
  });

  testWidgets('scanning a used ticket says Vé đã dùng', (tester) async {
    final w = _host(
      registrations: [
        registrationOf(
          'r1',
          'ev1',
          checkedInAt: eventNow.subtract(const Duration(minutes: 5)),
        ),
      ],
    );
    w.scanner.enqueue('VE-AB2C-1013');
    await _open(tester, w);
    await _tap(tester, find.byKey(const Key('manage-scan')));
    expect(find.text('Vé đã dùng'), findsOneWidget);
    expect(w.repo.checkedIn, isEmpty);
  });

  testWidgets('an unknown code says Vé không hợp lệ', (tester) async {
    final w = _host(registrations: [registrationOf('r1', 'ev1')]);
    w.scanner.enqueue('VE-ZZZZ-1013');
    await _open(tester, w);
    await _tap(tester, find.byKey(const Key('manage-scan')));
    expect(find.text('Vé không hợp lệ'), findsOneWidget);
  });

  testWidgets('manual code entry checks in', (tester) async {
    final w = _host(
      registrations: [registrationOf('r1', 'ev1', userName: 'Lan Anh')],
    );
    w.scanner.manual = true;
    await _open(tester, w);
    await _tap(tester, find.byKey(const Key('manage-scan')));

    expect(find.text('Nhập mã vé'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('checkin-code')),
      ' ve-ab2c-1013 ',
    );
    await tester.pump();
    await _tap(tester, find.byKey(const Key('checkin-submit')));

    expect(w.repo.checkedIn, ['VE-AB2C-1013']);
    expect(find.text('Đã vào · Lan Anh · 1 vé'), findsOneWidget);
  });

  // detailOf: starts eventNow + 3 days, ends two hours later.
  final end = eventNow.add(const Duration(days: 3, hours: 2));

  testWidgets('scan stays open until two hours after the end', (tester) async {
    final w = _host(now: end.add(const Duration(hours: 1, minutes: 59)));
    await _open(tester, w);
    expect(_scanEnabled(tester), isTrue);
  });

  testWidgets('scan is disabled two hours after the end', (tester) async {
    final w = _host(now: end.add(const Duration(hours: 2, minutes: 1)));
    await _open(tester, w);
    expect(_scanEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('manage-scan')));
    await settle(tester);
    expect(w.scanner.calls, 0);
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
    await _tap(tester, find.text('Huỷ sự kiện · hoàn tiền mọi vé'));
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
    expect(find.byKey(const Key('manage-broadcast')), findsNothing);
    expect(find.byKey(const Key('manage-cancel')), findsNothing);
    expect(find.byKey(const Key('manage-empty-share')), findsNothing);
  });

  testWidgets('Nhắn nhóm waits for the group chat', (tester) async {
    final w = _host();
    await _open(tester, w);
    expect(
      tester
          .widget<AppButton>(find.byKey(const Key('manage-broadcast')))
          .onPressed,
      isNull,
    );
    // One primary action: the scan button.
    expect(find.byType(CtaSurface), findsOneWidget);
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
}
