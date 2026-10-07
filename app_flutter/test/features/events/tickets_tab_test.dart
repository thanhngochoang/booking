import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/features/events/tickets_tab.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/event_world.dart';

EventRegistration _reg(
  String id, {
  String eventId = 'ev1',
  RegistrationStatus status = RegistrationStatus.paid,
  int amount = 0,
  Duration startsIn = const Duration(days: 3),
  DateTime? checkedInAt,
  int? refundPercent,
  int quantity = 1,
  DateTime? holdExpiresAt,
  bool refundDue = false,
}) {
  final start = eventNow.add(startsIn);
  return EventRegistration(
    id: id,
    eventId: eventId,
    userId: 'u1',
    userName: 'Lan',
    ticketCode: status == RegistrationStatus.paid ? 'VE-$id-1013' : '',
    quantity: quantity,
    amount: amount,
    status: status,
    checkedInAt: checkedInAt,
    refundPercent: refundPercent,
    holdExpiresAt: holdExpiresAt,
    refundDue: refundDue,
    paymentId: amount > 0 ? 'pay-$id' : null,
    event: EventTicketSnapshot(
      title: 'Photo walk $id',
      type: EventType.photoWalk,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 2)),
      locationName: 'Công viên Bạch Đằng',
      lat: 10.78,
      lng: 106.70,
    ),
    createdAt: eventNow,
  );
}

Future<EventsWorld> _open(
  WidgetTester tester,
  List<EventRegistration> regs, {
  String? highlight,
  double textScale = 1,
  Size size = const Size(390, 1400),
  DateTime? now,
  int priceVnd = 0,
  List<Override> extra = const [],
}) async {
  final w = EventsWorld(
    events: [detailOf('ev1', priceVnd: priceVnd)],
    registrations: regs,
    now: now,
  );
  await w.pump(
    tester,
    path: '/bookings',
    size: size,
    textScale: textScale,
    extra: extra,
    bookings: (_) => Scaffold(body: EventTicketsTab(highlightId: highlight)),
  );
  return w;
}

/// [r] as the server rewrites it.
EventRegistration _as(
  EventRegistration r,
  RegistrationStatus status, {
  bool refundDue = false,
  int? refundPercent,
}) => EventRegistration(
  id: r.id,
  eventId: r.eventId,
  userId: r.userId,
  userName: r.userName,
  ticketCode: r.ticketCode,
  quantity: r.quantity,
  amount: r.amount,
  status: status,
  event: r.event,
  createdAt: r.createdAt,
  paymentId: r.paymentId,
  holdExpiresAt: r.holdExpiresAt,
  refundPercent: refundPercent,
  refundDue: refundDue,
);

List<TicketCard> _cards(WidgetTester t) =>
    t.widgetList<TicketCard>(find.byType(TicketCard)).toList();

void main() {
  final l = AppLocalizationsVi();

  group('ticketViewOf', () {
    test('free paid upcoming has no refund percent', () {
      final v = ticketViewOf(_reg('a'), now: eventNow, l: l);
      expect(v.state, TicketState.upcoming);
      expect(v.refundPercentIfCancelled, isNull);
    });
    test('paid upcoming: 100% from 48 h before, 0% after', () {
      final far = ticketViewOf(
        _reg('a', amount: 100000, startsIn: const Duration(hours: 49)),
        now: eventNow,
        l: l,
      );
      final near = ticketViewOf(
        _reg('a', amount: 100000, startsIn: const Duration(hours: 47)),
        now: eventNow,
        l: l,
      );
      expect(far.refundPercentIfCancelled, 100);
      expect(near.refundPercentIfCancelled, 0);
    });
    test('held is pending payment', () {
      final v = ticketViewOf(
        _reg('a', status: RegistrationStatus.held, amount: 1000),
        now: eventNow,
        l: l,
      );
      expect(v.state, TicketState.pendingPayment);
    });
    test('a lapsed hold is Hết hạn; refundDue is Đang hoàn', () {
      final lapsed = ticketViewOf(
        _reg(
          'a',
          status: RegistrationStatus.held,
          amount: 1000,
          holdExpiresAt: eventNow,
        ),
        now: eventNow,
        l: l,
      );
      expect(lapsed.state, TicketState.cancelled);
      expect(lapsed.statusLabel, 'Hết hạn');
      final due = ticketViewOf(
        _reg('b', amount: 1000, refundDue: true),
        now: eventNow,
        l: l,
      );
      expect(due.state, TicketState.cancelled);
      expect(due.statusLabel, 'Đang hoàn');
    });
    test('checked in is attended, even before the end', () {
      final v = ticketViewOf(
        _reg('a', checkedInAt: eventNow),
        now: eventNow,
        l: l,
      );
      expect(v.state, TicketState.attended);
    });
    test('an event that ended is past', () {
      final v = ticketViewOf(
        _reg('a', startsIn: const Duration(hours: -5)),
        now: eventNow,
        l: l,
      );
      expect(v.state, TicketState.past);
    });
    test('cancelled, refunding and refunded', () {
      expect(
        ticketViewOf(
          _reg('a', status: RegistrationStatus.cancelled),
          now: eventNow,
          l: l,
        ).statusLabel,
        isNull,
      );
      expect(
        ticketViewOf(
          _reg('a', status: RegistrationStatus.cancelled, refundPercent: 100),
          now: eventNow,
          l: l,
        ).statusLabel,
        'Đang hoàn',
      );
      final refunded = ticketViewOf(
        _reg('a', status: RegistrationStatus.refunded),
        now: eventNow,
        l: l,
      );
      expect(refunded.state, TicketState.cancelled);
      expect(refunded.statusLabel, 'Đã hoàn tiền');
    });
  });

  testWidgets('upcoming ticket shows QR and code', (tester) async {
    await _open(tester, [_reg('a')]);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('VE-a-1013'), findsOneWidget);
    expect(find.text('Chỉ đường'), findsOneWidget);
    expect(find.text('Thêm vào lịch'), findsOneWidget);
    expect(
      find.text('Đưa mã này cho chủ sự kiện khi đến điểm hẹn.'),
      findsOneWidget,
    );
    expect(find.text('ĐÃ ĐĂNG KÝ'), findsOneWidget);
  });

  testWidgets('only the soonest ticket is highlighted', (tester) async {
    await _open(tester, [
      _reg('later', startsIn: const Duration(days: 9)),
      _reg('soon', startsIn: const Duration(days: 2)),
    ]);
    final cards = _cards(tester);
    expect(cards.map((c) => c.ticket.eventTitle), [
      'Photo walk soon',
      'Photo walk later',
    ]);
    expect(cards.map((c) => c.highlighted), [true, false]);
    expect(find.byType(QrImageView), findsNWidgets(2));
  });

  testWidgets('the ticket just bought is the highlighted one', (tester) async {
    await _open(tester, [
      _reg('later', startsIn: const Duration(days: 9)),
      _reg('soon', startsIn: const Duration(days: 2)),
    ], highlight: 'later');
    expect(_cards(tester).map((c) => c.highlighted), [false, true]);
  });

  testWidgets('a checked-in ticket says Đã tham gia without QR', (
    tester,
  ) async {
    await _open(tester, [_reg('a', checkedInAt: eventNow)]);
    expect(find.text('ĐÃ THAM GIA'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('a past ticket has no QR', (tester) async {
    await _open(tester, [_reg('a', startsIn: const Duration(days: -2))]);
    expect(find.text('ĐÃ QUA'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('cancelled and refunded tickets are compact with their label', (
    tester,
  ) async {
    await _open(tester, [
      _reg('c', status: RegistrationStatus.cancelled),
      _reg('r', status: RegistrationStatus.refunded, amount: 1000),
    ]);
    expect(find.text('ĐÃ HUỶ'), findsOneWidget);
    expect(find.text('ĐÃ HOÀN TIỀN'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('held ticket offers Thanh toán tiếp then Hết hạn', (
    tester,
  ) async {
    final live = _reg(
      'h',
      status: RegistrationStatus.held,
      amount: 500000,
      holdExpiresAt: eventNow.add(const Duration(minutes: 6)),
    );
    final lapsed = _reg(
      'x',
      status: RegistrationStatus.held,
      amount: 250000,
      startsIn: const Duration(days: 5),
      holdExpiresAt: eventNow.subtract(const Duration(minutes: 1)),
    );
    final w = await _open(tester, [live, lapsed], priceVnd: 250000);
    expect(find.text('CHỜ THANH TOÁN'), findsOneWidget);
    expect(find.text('HẾT HẠN'), findsOneWidget);
    expect(find.text('Thanh toán tiếp'), findsOneWidget);

    await tester.tap(find.text('Thanh toán tiếp'));
    await settle(tester);
    expect(w.repo.paymentChecks, ['ev1/h']);
    expect(find.text('Thanh toán thử'), findsOneWidget);
    expect(find.text('500.000₫'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ticket-pay-confirm')));
    await settle(tester);
    expect(w.repo.fakeConfirmed, ['pay-h']);
    expect(
      w.repo.registrations.firstWhere((r) => r.id == 'h').status,
      RegistrationStatus.paid,
    );
    expect(find.text('ĐÃ ĐĂNG KÝ'), findsOneWidget);
  });

  testWidgets('Thanh toán tiếp with real payments opens the pay URL', (
    tester,
  ) async {
    final w = await _open(
      tester,
      [
        _reg(
          'h',
          status: RegistrationStatus.held,
          amount: 250000,
          holdExpiresAt: eventNow.add(const Duration(minutes: 6)),
        ),
      ],
      priceVnd: 250000,
      extra: [realPaymentsProvider.overrideWithValue(true)],
    );
    await tester.tap(find.text('Thanh toán tiếp'));
    await settle(tester);
    expect(w.launcher.opened.map((u) => u.toString()), ['https://pay.test/h']);
    expect(find.text('Thanh toán thử'), findsNothing);
  });

  testWidgets('free tickets say Huỷ vé without a percent', (tester) async {
    await _open(tester, [_reg('a')]);
    expect(find.text('Huỷ vé'), findsOneWidget);
    expect(find.textContaining('hoàn'), findsNothing);
  });

  testWidgets('paid tickets show the refund percent', (tester) async {
    await _open(tester, [
      _reg('far', amount: 100000, startsIn: const Duration(days: 9)),
      _reg('near', amount: 100000, startsIn: const Duration(hours: 30)),
    ]);
    expect(find.text('Huỷ vé · hoàn 100%'), findsOneWidget);
    expect(find.text('Huỷ vé · không hoàn tiền'), findsOneWidget);
  });

  testWidgets('cancel asks first and calls cancelRegistration', (tester) async {
    final w = await _open(tester, [_reg('a')]);
    await tester.tap(find.text('Huỷ vé'));
    await settle(tester);
    expect(find.text('Huỷ vé Photo walk a?'), findsOneWidget);
    expect(
      w.repo.registrations.single.status,
      RegistrationStatus.paid,
      reason: 'nothing is cancelled before the answer',
    );
    await tester.tap(find.text('Giữ vé'));
    await settle(tester);
    expect(w.repo.registrations.single.status, RegistrationStatus.paid);

    await tester.tap(find.text('Huỷ vé'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-sheet')),
        matching: find.widgetWithText(AppButton, 'Huỷ vé'),
      ),
    );
    await settle(tester);
    expect(w.repo.registrations.single.status, RegistrationStatus.cancelled);
    expect(find.text('Đã huỷ vé'), findsOneWidget);
  });

  testWidgets('cancel 3 days before shows hoàn 100% and the amount', (
    tester,
  ) async {
    final w = await _open(tester, [
      _reg('a', amount: 500000, quantity: 2),
    ], priceVnd: 250000);
    expect(find.text('Huỷ vé · hoàn 100%'), findsOneWidget);
    await tester.tap(find.text('Huỷ vé · hoàn 100%'));
    await settle(tester);
    expect(find.text('Bạn nhận lại 500.000₫'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-sheet')),
        matching: find.widgetWithText(AppButton, 'Huỷ vé'),
      ),
    );
    await settle(tester);
    expect(w.repo.registrations.single.status, RegistrationStatus.refunded);
    expect(find.text('ĐÃ HOÀN TIỀN'), findsOneWidget);
  });

  testWidgets('cancel within 48 hours warns there is no refund', (
    tester,
  ) async {
    await _open(
      tester,
      [_reg('a', amount: 250000)],
      priceVnd: 250000,
      now: eventNow.add(const Duration(days: 2)),
    );
    expect(find.text('Huỷ vé · không hoàn tiền'), findsOneWidget);
    await tester.tap(find.text('Huỷ vé · không hoàn tiền'));
    await settle(tester);
    expect(
      find.text('Vé không được hoàn tiền khi huỷ trong vòng 48 giờ.'),
      findsOneWidget,
    );
  });

  testWidgets("a cancelled event's ticket shows Đang hoàn, then Đã hoàn tiền", (
    tester,
  ) async {
    final due = _reg('a', amount: 250000, refundDue: true);
    final w = await _open(tester, [due], priceVnd: 250000);
    expect(find.text('ĐANG HOÀN'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Huỷ vé'), findsNothing);
    w.repo.putRegistration(
      _as(due, RegistrationStatus.refunded, refundPercent: 100),
    );
    await settle(tester);
    expect(find.text('ĐANG HOÀN'), findsNothing);
    expect(find.text('ĐÃ HOÀN TIỀN'), findsOneWidget);
  });

  testWidgets('empty state links to events', (tester) async {
    final w = await _open(tester, const []);
    expect(find.text('Chưa có vé sự kiện'), findsOneWidget);
    await tester.tap(find.text('Xem sự kiện'));
    await settle(tester);
    expect(w.location, '/events');
  });

  testWidgets('a paid ticket has Vào nhóm chat that opens the group chat', (
    tester,
  ) async {
    final w = await _open(tester, [_reg('a')]);
    expect(find.text('Vào nhóm chat'), findsOneWidget);
    await tester.tap(find.text('Vào nhóm chat'));
    await settle(tester);
    expect(w.location, '/e/ev1/chat');
  });

  testWidgets('a held ticket has no group chat yet', (tester) async {
    await _open(tester, [_reg('a', status: RegistrationStatus.held)]);
    expect(find.text('Vào nhóm chat'), findsNothing);
  });

  testWidgets('tapping a card opens the event', (tester) async {
    final w = await _open(tester, [_reg('a')]);
    await tester.tap(find.text('Photo walk a'));
    await settle(tester);
    expect(w.location, '/e/ev1');
  });

  testWidgets('Chỉ đường and Thêm vào lịch open the external apps', (
    tester,
  ) async {
    final w = await _open(tester, [_reg('a')]);
    await tester.tap(find.text('Chỉ đường'));
    await settle(tester);
    expect(w.launcher.opened.single.host, 'www.google.com');
    await tester.tap(find.text('Thêm vào lịch'));
    await settle(tester);
    expect(w.launcher.opened.last.host, 'calendar.google.com');
  });

  testWidgets('tapping the QR shows it full screen on white', (tester) async {
    await _open(tester, [_reg('a')]);
    await tester.tap(find.byKey(const Key('ticket-qr')));
    await settle(tester);
    final big = find.byKey(const Key('ticket-qr-full'));
    expect(big, findsOneWidget);
    expect(tester.widget<QrImageView>(big).backgroundColor, Colors.white);
    await tester.tap(find.text('Đóng'));
    await settle(tester);
    expect(big, findsNothing);
  });

  testWidgets('fits 320dp at 1.3 text scale', (tester) async {
    await _open(
      tester,
      [
        _reg('a', amount: 100000),
        _reg('b', startsIn: const Duration(days: 9)),
        _reg('c', checkedInAt: eventNow),
      ],
      textScale: 1.3,
      size: const Size(320, 900),
    );
    expect(tester.takeException(), isNull);
  });
}
