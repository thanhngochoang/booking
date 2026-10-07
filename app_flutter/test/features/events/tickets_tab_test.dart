import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}) async {
  final w = EventsWorld(
    events: [detailOf('ev1', priceVnd: 0)],
    registrations: regs,
  );
  await w.pump(
    tester,
    path: '/bookings',
    size: size,
    textScale: textScale,
    bookings: (_) => Scaffold(body: EventTicketsTab(highlightId: highlight)),
  );
  return w;
}

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

  testWidgets('a held ticket says Chờ thanh toán, with no pay button yet', (
    tester,
  ) async {
    await _open(tester, [
      _reg('h', status: RegistrationStatus.held, amount: 1000),
    ]);
    expect(find.text('CHỜ THANH TOÁN'), findsOneWidget);
    expect(find.text('Thanh toán'), findsNothing);
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
