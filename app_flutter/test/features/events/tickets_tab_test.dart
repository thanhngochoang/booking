import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:photobooking/features/events/tickets_tab.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/passes/pass_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/dispute_world.dart';
import '../../support/event_world.dart';
import '../../support/fake_organizer_repository.dart';
import '../../support/fake_pass_repository.dart';
import '../../support/organizer_world.dart' show entryDetailOf, makeEntryEvent;
import '../../support/fake_pass_scanner.dart';
import '../../support/fake_push.dart';

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
  TicketRefundStatus? refundStatus,
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
    refundStatus: refundStatus,
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
  DateTime Function()? clock,
  String? path,
}) async {
  final w = EventsWorld(
    events: [detailOf('ev1', priceVnd: priceVnd)],
    registrations: regs,
    now: now,
    clock: clock,
  );
  await w.pump(
    tester,
    path: path ?? '/bookings',
    size: size,
    textScale: textScale,
    extra: extra,
    bookings: (s) => Scaffold(
      body: EventTicketsTab(
        highlightId: highlight ?? s.uri.queryParameters['highlight'],
      ),
    ),
  );
  return w;
}

/// [r] as the server rewrites it.
EventRegistration _as(
  EventRegistration r,
  RegistrationStatus status, {
  bool refundDue = false,
  int? refundPercent,
  TicketRefundStatus? refundStatus,
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
  refundStatus: refundStatus,
);

List<TicketCard> _cards(WidgetTester t) =>
    t.widgetList<TicketCard>(find.byType(TicketCard)).toList();

/// Counts how many times the primer looked at the OS permission.
class _CountingPermission extends FakeNotificationPermission {
  _CountingPermission([super.current]);

  int statusCalls = 0;

  @override
  Future<NotificationPermissionStatus> status() {
    statusCalls++;
    return super.status();
  }
}

List<Override> _permission(FakeNotificationPermission p) => [
  notificationPermissionProvider.overrideWithValue(p),
];

Finder get _primer => find.byType(PermissionPrimer);

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
    test('a refund says Đang hoàn until the gateway is done', () {
      String? label(RegistrationStatus s, TicketRefundStatus? r) =>
          ticketViewOf(
            _reg('a', status: s, amount: 1000, refundStatus: r),
            now: eventNow,
            l: l,
          ).statusLabel;
      const refunded = RegistrationStatus.refunded;
      const cancelled = RegistrationStatus.cancelled;
      expect(label(refunded, TicketRefundStatus.pending), 'Đang hoàn');
      expect(label(refunded, TicketRefundStatus.failed), 'Đang hoàn');
      expect(label(refunded, TicketRefundStatus.done), 'Đã hoàn tiền');
      // A payment that came after the hold: refunded in full, said so.
      expect(
        label(cancelled, TicketRefundStatus.pending),
        'Đã huỷ · đang hoàn tiền',
      );
      expect(
        label(cancelled, TicketRefundStatus.failed),
        'Đã huỷ · đang hoàn tiền',
      );
      expect(
        label(cancelled, TicketRefundStatus.done),
        'Đã huỷ · đã hoàn tiền',
      );
    });
  });

  group('S17.03 notification primer', () {
    setUp(resetNotificationPrimerState);
    tearDown(resetNotificationPrimerState);

    testWidgets(
      'asks once per highlight when the highlighted ticket is shown',
      (tester) async {
        final perm = _CountingPermission();
        final w = await _open(
          tester,
          [_reg('a'), _reg('b', startsIn: const Duration(days: 9))],
          highlight: 'b',
          extra: _permission(perm),
        );
        expect(_primer, findsOneWidget);
        expect(
          find.text(
            'Bật thông báo để được nhắc trước khi Photo walk b bắt đầu',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Nhắc trước khi sự kiện bắt đầu, kèm giờ và điểm tập trung',
          ),
          findsOneWidget,
        );
        expect(perm.statusCalls, 1);

        // Close it, forget the 7-day wait, rebuild the list: not asked again.
        await tester.tap(find.text('Để sau'));
        await settle(tester);
        await w.prefs!.remove('notifPrimerLaterAt');
        ProviderScope.containerOf(tester.element(find.byType(EventTicketsTab)))
            .invalidate(myTicketsProvider);
        await settle(tester);
        expect(_primer, findsNothing);
        expect(perm.statusCalls, 1);
      },
    );

    testWidgets('opening the tickets tab without highlight asks nothing', (
      tester,
    ) async {
      final perm = _CountingPermission();
      await _open(tester, [_reg('a')], extra: _permission(perm));
      expect(_primer, findsNothing);
      expect(perm.statusCalls, 0);
      expect(perm.requests, 0);
    });

    testWidgets('a highlight that is not an upcoming ticket asks nothing', (
      tester,
    ) async {
      final perm = _CountingPermission();
      await _open(
        tester,
        [
          _reg('a'),
          _reg('past', startsIn: const Duration(days: -2)),
          _reg('gone', status: RegistrationStatus.cancelled),
        ],
        highlight: 'past',
        extra: _permission(perm),
      );
      expect(_primer, findsNothing);
      expect(perm.statusCalls, 0);
    });

    testWidgets('a highlight that matches no ticket asks nothing', (
      tester,
    ) async {
      final perm = _CountingPermission();
      await _open(
        tester,
        [_reg('a')],
        highlight: 'ghost',
        extra: _permission(perm),
      );
      expect(_primer, findsNothing);
      expect(perm.statusCalls, 0);
    });

    testWidgets('granted permission asks nothing', (tester) async {
      final perm = _CountingPermission(NotificationPermissionStatus.granted);
      await _open(
        tester,
        [_reg('a')],
        highlight: 'a',
        extra: _permission(perm),
      );
      expect(_primer, findsNothing);
      expect(perm.requests, 0);
    });

    testWidgets('"Để sau" closes it and the 7-day policy is recorded', (
      tester,
    ) async {
      final perm = _CountingPermission();
      final w = await _open(
        tester,
        [_reg('a')],
        highlight: 'a',
        extra: _permission(perm),
      );
      expect(_primer, findsOneWidget);
      await tester.tap(find.text('Để sau'));
      await settle(tester);
      expect(_primer, findsNothing);
      expect(perm.requests, 0);
      expect(
        w.prefs!.getInt('notifPrimerLaterAt'),
        eventNow.millisecondsSinceEpoch,
      );
    });

    testWidgets('a paid ticket landing on the highlight asks once', (
      tester,
    ) async {
      final perm = _CountingPermission();
      await _open(
        tester,
        [_reg('pay1', amount: 250000)],
        priceVnd: 250000,
        path: '/bookings?tab=events&highlight=pay1',
        extra: _permission(perm),
      );
      expect(_primer, findsOneWidget);
      expect(
        find.text(
          'Bật thông báo để được nhắc trước khi Photo walk pay1 bắt đầu',
        ),
        findsOneWidget,
      );
      expect(perm.statusCalls, 1);
    });

    testWidgets('a held ticket highlighted asks nothing until it is paid', (
      tester,
    ) async {
      final perm = _CountingPermission();
      await _open(
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
        highlight: 'h',
        extra: _permission(perm),
      );
      expect(_primer, findsNothing);
      expect(perm.statusCalls, 0);
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

  testWidgets('a paid past ticket inside its window shows "Báo vấn đề"; a '
      'free one does not', (tester) async {
    final w = DisputeWorld(now: eventNow);
    await _open(
      tester,
      [
        // Ended 3 hours ago.
        _reg('paid', amount: 300000, startsIn: const Duration(hours: -5)),
        _reg('free', startsIn: const Duration(hours: -5)),
        // Ended 2 days ago: the window is over.
        _reg('old', amount: 300000, startsIn: const Duration(days: -2)),
      ],
      extra: [
        disputeRepositoryProvider.overrideWithValue(w.repo),
      ],
    );
    expect(find.text('Báo vấn đề'), findsOneWidget);
    final report = find.byKey(const Key('ticket-report-problem'));
    expect(
      find.ancestor(of: report, matching: find.byKey(const ValueKey('paid'))),
      findsOneWidget,
    );
  });

  testWidgets('"Báo vấn đề" appears when the event ends and goes 24 hours '
      'later while the tab stays open', (tester) async {
    var now = eventNow;
    final w = DisputeWorld(now: eventNow);
    // Ends one minute from now.
    await _open(
      tester,
      [
        _reg(
          'paid',
          amount: 300000,
          startsIn: const Duration(hours: -2, minutes: 1),
        ),
      ],
      clock: () => now,
      extra: [disputeRepositoryProvider.overrideWithValue(w.repo)],
    );
    expect(find.byKey(const Key('ticket-report-problem')), findsNothing);

    now = eventNow.add(const Duration(minutes: 2));
    await tester.pump(ticketsTick);
    await tester.pump();
    expect(find.byKey(const Key('ticket-report-problem')), findsOneWidget);

    now = eventNow.add(const Duration(hours: 24, minutes: 2));
    await tester.pump(ticketsTick);
    await tester.pump();
    expect(find.byKey(const Key('ticket-report-problem')), findsNothing);
  });

  testWidgets('"Báo vấn đề" opens S18.01 for the ticket and a success pushes '
      '/disputes/:id', (tester) async {
    final w = DisputeWorld(now: eventNow);
    final world = await _open(
      tester,
      [_reg('paid', amount: 300000, startsIn: const Duration(hours: -5))],
      extra: [
        disputeRepositoryProvider.overrideWithValue(w.repo),
      ],
    );
    await tester.tap(find.byKey(const Key('ticket-report-problem')));
    await settle(tester);
    expect(
      find.text(
        'Còn 21 giờ để báo vấn đề. Tiền vé được giữ tới khi có kết quả.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Sự kiện không diễn ra'));
    await tester.enterText(
      find.byKey(const Key('dispute-description')),
      'Tới nơi không có ai tổ chức cả.',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('dispute-submit')));
    await tester.tap(find.byKey(const Key('dispute-submit')));
    await settle(tester);

    final draft = w.repo.opened.single;
    expect(draft.subjectType, DisputeSubjectType.ticket);
    expect(draft.subjectId, 'paid');
    expect(draft.eventId, 'ev1');
    expect(world.router.state.uri.toString(), '/disputes/${draft.disputeId}');
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
    expect(find.byKey(const Key('ticket-compact')), findsNWidgets(2));
    expect(find.byType(DateBlock), findsNWidgets(2));
  });

  testWidgets('only the upcoming ticket is the big card (mock S11.04)', (
    tester,
  ) async {
    await _open(tester, [
      _reg('up'),
      _reg(
        'h',
        status: RegistrationStatus.held,
        amount: 250000,
        holdExpiresAt: eventNow.add(const Duration(minutes: 6)),
      ),
      _reg('past', startsIn: const Duration(days: -2)),
    ], priceVnd: 250000);
    final cards = _cards(tester);
    expect(cards.map((c) => (c.ticket.eventTitle, c.compact)), [
      ('Photo walk up', false),
      ('Photo walk h', true),
      ('Photo walk past', true),
    ]);
    expect(find.byKey(const Key('ticket-compact')), findsNWidgets(2));
    // The held row: date block, title, "n vé · place", badge.
    final row = find.ancestor(
      of: find.text('Photo walk h'),
      matching: find.byKey(const Key('ticket-compact')),
    );
    expect(
      find.descendant(of: row, matching: find.byType(DateBlock)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text('1 vé · Công viên Bạch Đằng'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('CHỜ THANH TOÁN')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Thanh toán tiếp')),
      findsOneWidget,
    );
  });

  testWidgets('Thanh toán tiếp checks first, then opens S04.04 for the hold', (
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
    expect(w.location, '/e/ev1/pay/h');
  });

  testWidgets(
    'Thanh toán tiếp on a hold the gateway already has does not open S04.04',
    (tester) async {
      final live = _reg(
        'h',
        status: RegistrationStatus.held,
        amount: 500000,
        holdExpiresAt: eventNow.add(const Duration(minutes: 6)),
      );
      final w = await _open(tester, [live], priceVnd: 250000);
      w.repo.gatewayPaid.add('pay-h');
      await tester.tap(find.text('Thanh toán tiếp'));
      await settle(tester);
      expect(w.repo.paymentChecks, ['ev1/h']);
      expect(w.location, isNot('/e/ev1/pay/h'));
    },
  );

  testWidgets('a held ticket flips to Hết hạn when its hold runs out', (
    tester,
  ) async {
    var now = eventNow;
    await _open(
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
      clock: () => now,
    );
    expect(find.text('CHỜ THANH TOÁN'), findsOneWidget);
    expect(find.text('Thanh toán tiếp'), findsOneWidget);
    expect(find.text('HẾT HẠN'), findsNothing);

    // One second before the end nothing changes yet.
    now = eventNow.add(const Duration(minutes: 5, seconds: 59));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Thanh toán tiếp'), findsOneWidget);

    now = eventNow.add(const Duration(minutes: 6));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('HẾT HẠN'), findsOneWidget);
    expect(find.text('CHỜ THANH TOÁN'), findsNothing);
    expect(find.text('Thanh toán tiếp'), findsNothing);
  });



  testWidgets('a refunded ticket says Đang hoàn until its refund is done', (
    tester,
  ) async {
    final r = _reg(
      'a',
      status: RegistrationStatus.refunded,
      amount: 250000,
      refundStatus: TicketRefundStatus.pending,
    );
    final w = await _open(tester, [r], priceVnd: 250000);
    expect(find.text('ĐANG HOÀN'), findsOneWidget);
    w.repo.putRegistration(
      _as(
        r,
        RegistrationStatus.refunded,
        refundPercent: 100,
        refundStatus: TicketRefundStatus.done,
      ),
    );
    await settle(tester);
    expect(find.text('ĐANG HOÀN'), findsNothing);
    expect(find.text('ĐÃ HOÀN TIỀN'), findsOneWidget);
  });

  testWidgets('a payment after the hold shows the refund on the ticket', (
    tester,
  ) async {
    final r = _reg(
      'a',
      status: RegistrationStatus.cancelled,
      amount: 250000,
      refundStatus: TicketRefundStatus.pending,
    );
    final w = await _open(tester, [r], priceVnd: 250000);
    expect(find.text('ĐÃ HUỶ · ĐANG HOÀN TIỀN'), findsOneWidget);
    w.repo.putRegistration(
      _as(
        r,
        RegistrationStatus.cancelled,
        refundStatus: TicketRefundStatus.done,
      ),
    );
    await settle(tester);
    expect(find.text('ĐÃ HUỶ · ĐÃ HOÀN TIỀN'), findsOneWidget);
  });

  testWidgets(
    'Thanh toán tiếp with real payments opens S04.04 (Mở lại there)',
    (tester) async {
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
      expect(w.location, '/e/ev1/pay/h');
    },
  );

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

  testWidgets('a bank_qr ticket cancelled ≥ 48 h opens the sheet', (
    tester,
  ) async {
    final w = EventsWorld(
      events: [detailOf('ev1', priceVnd: 250000)],
      registrations: [_reg('a', amount: 500000, quantity: 2)],
    );
    w.payments.pendingBySubject[const TicketRefund('ev1', 'a')] =
        const PendingRefund(
          refundId: 'r1',
          amount: 500000,
          payer: (
            bankName: 'Vietcombank',
            accountLast4: '6789',
            holderName: 'NGUYEN THANH HA',
          ),
        );
    await w.pump(
      tester,
      path: '/bookings',
      size: const Size(390, 1400),
      bookings: (_) => const Scaffold(body: EventTicketsTab()),
    );
    await tester.tap(find.text('Huỷ vé · hoàn 100%'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-sheet')),
        matching: find.widgetWithText(AppButton, 'Huỷ vé'),
      ),
    );
    await settle(tester);

    expect(w.payments.pendingCalls, [const TicketRefund('ev1', 'a')]);
    expect(find.text('Đã huỷ vé'), findsOneWidget);
    expect(find.text('Tài khoản nhận hoàn'), findsOneWidget);
    expect(find.text('Vietcombank •••• 6789'), findsOneWidget);
  });

  testWidgets('a wallet ticket cancel asks once and opens no sheet', (
    tester,
  ) async {
    final w = await _open(tester, [
      _reg('a', amount: 250000),
    ], priceVnd: 250000);
    await tester.tap(find.text('Huỷ vé · hoàn 100%'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-sheet')),
        matching: find.widgetWithText(AppButton, 'Huỷ vé'),
      ),
    );
    await settle(tester);
    // The registration does not carry the method: the server says nothing
    // waits for a wallet payment.
    expect(w.payments.pendingCalls, [const TicketRefund('ev1', 'a')]);
    expect(find.text('Tài khoản nhận hoàn'), findsNothing);
  });

  testWidgets('a no-refund ticket cancel never asks for a refund account', (
    tester,
  ) async {
    final late = await _open(
      tester,
      [_reg('b', amount: 250000)],
      priceVnd: 250000,
      now: eventNow.add(const Duration(days: 2)),
    );
    await tester.tap(find.text('Huỷ vé · không hoàn tiền'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-sheet')),
        matching: find.widgetWithText(AppButton, 'Huỷ vé'),
      ),
    );
    await settle(tester);
    expect(late.payments.pendingCalls, isEmpty);
  });

  testWidgets('a ticket whose refund waits for an account stays "Đang hoàn" '
      '(S11.04-pending)', (tester) async {
    await _open(tester, [
      _reg(
        'a',
        amount: 250000,
        status: RegistrationStatus.refunded,
        refundPercent: 100,
        refundStatus: TicketRefundStatus.awaitingAccount,
      ),
    ], priceVnd: 250000);
    expect(find.text('ĐANG HOÀN'), findsOneWidget);
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
        _reg(
          'h',
          status: RegistrationStatus.held,
          amount: 250000,
          holdExpiresAt: eventNow.add(const Duration(minutes: 6)),
        ),
        _reg(
          'late',
          status: RegistrationStatus.cancelled,
          amount: 250000,
          refundStatus: TicketRefundStatus.pending,
        ),
      ],
      textScale: 1.3,
      size: const Size(320, 1600),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('ĐÃ HUỶ · ĐANG HOÀN TIỀN'), findsOneWidget);
  });

  group('S11.04-entry (#223)', () {
    EventRegistration entryReg(
      String id, {
      String day = '2026-10-13',
      DateTime? checkedInAt,
      bool refundDue = false,
      String ticketCode = '',
    }) {
      final d = parseDayKey(day)!;
      return EventRegistration(
        id: id,
        eventId: 'ent1',
        userId: 'u1',
        userName: 'Lan',
        ticketCode: ticketCode,
        quantity: 3,
        amount: 190000,
        status: RegistrationStatus.paid,
        checkedInAt: checkedInAt,
        refundDue: refundDue,
        paymentId: 'pay-$id',
        visitDay: day,
        items: const [
          EntryLine(ticketTypeId: 't1', name: 'Người lớn', price: 70000, qty: 2),
          EntryLine(ticketTypeId: 't2', name: 'Trẻ em', price: 50000, qty: 1),
        ],
        event: EventTicketSnapshot(
          title: 'Bãi đá sông Hồng',
          type: EventType.entry,
          startsAt: fromVnWallClock(d.add(const Duration(hours: 6))),
          endsAt: fromVnWallClock(d.add(const Duration(hours: 22))),
          locationName: 'Bãi đá sông Hồng',
          lat: 21.07,
          lng: 105.84,
        ),
        createdAt: eventNow,
      );
    }

    late FakePassRepository passes;
    late FakeScreenBrightness brightness;
    late FakeOrganizerRepository organizers;
    List<Override> extra() {
      passes = FakePassRepository();
      brightness = FakeScreenBrightness();
      organizers = FakeOrganizerRepository(uid: 'u1', clock: () => eventNow);
      return [
        passRepositoryProvider.overrideWithValue(passes),
        screenBrightnessProvider.overrideWithValue(brightness),
        organizerRepositoryProvider.overrideWithValue(organizers),
      ];
    }

    /// The tab over the entry event `ent1` (cutoff [cutoffHours]).
    Future<void> openEntry(
      WidgetTester tester,
      List<EventRegistration> regs,
      List<Override> ov, {
      int cutoffHours = 48,
    }) async {
      final w = EventsWorld(
        events: [
          entryDetailOf(
            makeEntryEvent(
              startDay: '2026-10-01',
            ).copyWith(refundCutoffHours: cutoffHours),
          ),
        ],
        registrations: regs,
      );
      await w.pump(
        tester,
        path: '/bookings',
        size: const Size(390, 1400),
        extra: ov,
        bookings: (_) => const Scaffold(body: EventTicketsTab()),
      );
    }

    testWidgets('entry tickets: tag, visit day with hours, per-type counts, '
        'the gate hint and no chat', (tester) async {
      final ov = extra();
      passes.setRegistrationPass('e1', '7K2Q4R9X');
      await _open(tester, [entryReg('e1')], extra: ov);
      expect(find.text('Vé vào cửa'), findsOneWidget);
      expect(find.text('T3 13/10 · 06:00–22:00 · 3 vé'), findsOneWidget);
      expect(find.text('2 Người lớn · 1 Trẻ em'), findsOneWidget);
      expect(
        find.text('Đưa mã cho nhân viên ở cổng. Dùng được cả nhóm, một lần.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ticket-chat')), findsNothing);
      expect(find.text('Huỷ vé · hoàn 100% (tới 00:00 CN 11/10)'), findsOneWidget);
    });

    testWidgets('the QR comes from private/pass, legacy codes as they are', (
      tester,
    ) async {
      final ov = extra();
      passes.setRegistrationPass('e1', '7K2Q4R9X');
      await _open(tester, [
        entryReg('e1'),
        entryReg('e2', day: '2026-10-14', ticketCode: 'VE-AB2C-1014'),
      ], extra: ov);
      expect(find.text('VE-7K2Q-4R9X'), findsOneWidget);
      expect(find.text('VE-AB2C-1014'), findsOneWidget);
      expect(find.byType(QrImageView), findsNWidgets(2));
    });

    testWidgets('offline, the saved pass still draws', (tester) async {
      final ov = extra();
      passes.failWith = Exception('offline');
      SharedPreferences.setMockInitialValues({'pass.e1': '7K2Q4R9X'});
      final w = EventsWorld(
        events: [detailOf('ev1')],
        registrations: [entryReg('e1')],
      );
      w.prefs = await tester.runAsync(SharedPreferences.getInstance);
      await w.pump(
        tester,
        path: '/bookings',
        size: const Size(390, 1400),
        extra: ov,
        bookings: (_) => const Scaffold(body: EventTicketsTab()),
      );
      expect(find.text('VE-7K2Q-4R9X'), findsOneWidget);
    });

    testWidgets('full screen raises the brightness', (tester) async {
      final ov = extra();
      passes.setRegistrationPass('e1', '7K2Q4R9X');
      await _open(tester, [entryReg('e1')], extra: ov);
      await tester.tap(find.byKey(const Key('ticket-qr')));
      await settle(tester);
      expect(find.byKey(const Key('ticket-qr-full')), findsOneWidget);
      expect(brightness.raised, isTrue);
      await tester.tap(find.text('Đóng'));
      await settle(tester);
      expect(brightness.calls, ['raise', 'restore']);
    });

    testWidgets('checked in: "Đã vào 07:42"', (tester) async {
      await _open(tester, [
        entryReg('e1', checkedInAt: DateTime.utc(2026, 10, 13, 0, 42)),
      ], extra: extra());
      expect(find.text('ĐÃ VÀO 07:42'), findsOneWidget);
    });

    testWidgets('a closed day: "Ngày đóng cửa · đang hoàn 100%"', (
      tester,
    ) async {
      final ov = extra();
      organizers.putEntryDay(
        const EntryDay(eventId: 'ent1', day: '2026-10-13', closed: true),
      );
      await _open(tester, [entryReg('e1', refundDue: true)], extra: ov);
      expect(find.text('NGÀY ĐÓNG CỬA · ĐANG HOÀN 100%'), findsOneWidget);
    });

    testWidgets('another refund (event cancelled, organizer suspended): '
        '"Đang hoàn 100%", not a closed day', (tester) async {
      final ov = extra();
      organizers.putEntryDay(
        const EntryDay(eventId: 'ent1', day: '2026-10-13', sold: 3),
      );
      await _open(tester, [entryReg('e1', refundDue: true)], extra: ov);
      expect(find.text('ĐANG HOÀN 100%'), findsOneWidget);
      expect(find.textContaining('NGÀY ĐÓNG CỬA'), findsNothing);
    });

    testWidgets('the cutoff is the event\'s refundCutoffHours', (tester) async {
      final ov = extra();
      passes.setRegistrationPass('e1', '7K2Q4R9X');
      // 24 h: 13/10 00:00 − 24 h = 12/10 00:00 (48 h would be 11/10).
      await openEntry(tester, [entryReg('e1')], ov, cutoffHours: 24);
      expect(
        find.text('Huỷ vé · hoàn 100% (tới 00:00 T2 12/10)'),
        findsOneWidget,
      );
    });

    testWidgets('a long cutoff (96 h) is already past 3 days before', (
      tester,
    ) async {
      final ov = extra();
      passes.setRegistrationPass('e1', '7K2Q4R9X');
      // 13/10 00:00 − 96 h = 09/10 00:00, before now (10/10 10:00).
      await openEntry(tester, [entryReg('e1')], ov, cutoffHours: 96);
      expect(find.text('Đã qua mốc huỷ'), findsOneWidget);
    });

    testWidgets('a past visit day is over even when the snapshot ends later', (
      tester,
    ) async {
      final ov = extra();
      final past = entryReg('e1', day: '2026-10-09');
      final stale = EventRegistration(
        id: past.id,
        eventId: past.eventId,
        userId: past.userId,
        userName: past.userName,
        ticketCode: '',
        quantity: past.quantity,
        amount: past.amount,
        status: past.status,
        paymentId: past.paymentId,
        visitDay: past.visitDay,
        items: past.items,
        // The sale range end, weeks away.
        event: EventTicketSnapshot(
          title: past.event.title,
          type: EventType.entry,
          startsAt: past.event.startsAt,
          endsAt: DateTime.utc(2026, 12, 31, 17),
          locationName: past.event.locationName,
        ),
        createdAt: past.createdAt,
      );
      await _open(tester, [stale], extra: ov);
      expect(find.byKey(const Key('ticket-compact')), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('past the cutoff: "Đã qua mốc huỷ", cancel off', (
      tester,
    ) async {
      final ov = extra();
      passes.setRegistrationPass('e1', '7K2Q4R9X');
      await _open(tester, [entryReg('e1', day: '2026-10-11')], extra: ov);
      final cancel = find.byKey(const Key('ticket-cancel'));
      expect(
        find.descendant(of: cancel, matching: find.text('Đã qua mốc huỷ')),
        findsOneWidget,
      );
      expect(tester.widget<AppButton>(cancel).onPressed, isNull);
    });

    for (final b in Brightness.values) {
      testWidgets('fits 320 dp at 1.3× text (${b.name})', (tester) async {
        final ov = extra();
        passes.setRegistrationPass('e1', '7K2Q4R9X');
        final w = EventsWorld(
          events: [detailOf('ev1')],
          registrations: [entryReg('e1')],
        );
        await w.pump(
          tester,
          path: '/bookings',
          size: const Size(320, 1600),
          textScale: 1.3,
          extra: ov,
          bookings: (_) => Theme(
            data: b == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
            child: const Scaffold(body: EventTicketsTab()),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('2 Người lớn · 1 Trẻ em'), findsOneWidget);
      });
    }
  });
}
