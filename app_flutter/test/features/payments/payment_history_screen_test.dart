import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/features/payments/payment_history_controller.dart';
import 'package:photobooking/features/payments/payment_history_screen.dart';

import '../../support/fake_payments_repository.dart';
import '../../support/screen_host.dart';

const _uid = 'lan';

/// 10:00 on Sunday 25/10 in Vietnam.
final _now = DateTime.utc(2026, 10, 25, 3);

PayerPaymentRow _row(
  String id, {
  PayerSubjectType subject = PayerSubjectType.booking,
  String? subjectId,
  PayerRowStatus status = PayerRowStatus.held,
  PayMethod? method = PayMethod.bankQr,
  int amount = 1500000,
  DateTime? createdAt,
  String? day = '2026-10-12',
  String? photographerName = 'Minh Trí',
  String? serviceName = 'Chân dung 2 giờ',
  String? eventId,
  String? eventTitle,
  int? quantity,
  String? areaLabel,
  bool open = true,
  bool toPlatform = false,
  bool searching = false,
  bool cancelled = false,
  int refundingAmount = 0,
  int refundedAmount = 0,
  List<PayerRefundView> refunds = const [],
}) => PayerPaymentRow(
  paymentId: id,
  subjectType: subject,
  subjectId: subjectId ?? 'b_$id',
  eventId: eventId,
  photographerName: photographerName,
  serviceName: serviceName,
  eventTitle: eventTitle,
  quantity: quantity,
  areaLabel: areaLabel,
  day: day,
  method: method,
  amount: amount,
  status: status,
  open: open,
  toPlatform: toPlatform,
  refundingAmount: refundingAmount,
  refundedAmount: refundedAmount,
  searching: searching,
  cancelled: cancelled,
  refunds: refunds,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 12, 3),
);

/// Holds every page bigger than the first until [gate] completes.
class _SlowPages extends FakePaymentsRepository {
  final gate = Completer<void>();

  @override
  Stream<List<PayerPaymentRow>> watchHistory(
    String uid, {
    required int limit,
  }) async* {
    if (limit > paymentsPageSize) await gate.future;
    yield* super.watchHistory(uid, limit: limit);
  }
}

PayerPaymentRow _ticket({
  PayerRowStatus status = PayerRowStatus.refunding,
  bool toPlatform = false,
  List<PayerRefundView> refunds = const [],
  int refundingAmount = 0,
}) => _row(
  't1',
  subject: PayerSubjectType.eventRegistration,
  subjectId: 'reg1',
  eventId: 'e1',
  eventTitle: 'Photo walk phố cổ',
  quantity: 2,
  photographerName: null,
  serviceName: null,
  day: '2026-10-18',
  method: PayMethod.zaloPay,
  amount: 500000,
  status: status,
  toPlatform: toPlatform,
  refunds: refunds,
  refundingAmount: refundingAmount,
  createdAt: DateTime.utc(2026, 10, 14, 3),
);

PayerPaymentRow _instant() => _row(
  'i1',
  subject: PayerSubjectType.instantRequest,
  subjectId: 'req1',
  photographerName: null,
  serviceName: null,
  areaLabel: 'Quận 1',
  day: null,
  method: PayMethod.momo,
  amount: 800000,
  searching: true,
  // 09:12 today in Vietnam.
  createdAt: DateTime.utc(2026, 10, 25, 2, 12),
);

Finder _key(String k) => find.byKey(Key(k));

Finder _inRow(String paymentId, Finder f) =>
    find.descendant(of: _key('pay-row-$paymentId'), matching: f);

/// Bounded frames: the list arrives from streams, rows animate open.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapRow(WidgetTester tester, String paymentId) async {
  final row = _key('pay-row-$paymentId');
  await tester.ensureVisible(row);
  await tester.pump();
  // The title sits at the top of the row, away from its buttons.
  await tester.tapAt(tester.getTopLeft(row) + const Offset(24, 16));
  await _settle(tester);
}

class _Harness {
  _Harness(this.payments, this.router);

  final FakePaymentsRepository payments;
  final GoRouter router;

  String get location => router.routeInformationProvider.value.uri.toString();
}

Future<_Harness> _open(
  WidgetTester tester, {
  List<PayerPaymentRow> rows = const [],
  PaymentTotals totals = const PaymentTotals(),
  double width = 390,
  double textScale = 1,
  void Function(FakePaymentsRepository p)? seed,
  FakePaymentsRepository? repo,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final payments = (repo ?? FakePaymentsRepository())
    ..emitHistory(_uid, rows)
    ..emitTotals(_uid, totals);
  seed?.call(payments);
  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/me/payments'),
            child: const Text('go'),
          ),
        ),
      ),
      GoRoute(
        path: '/me/payments',
        builder: (_, _) => const PaymentHistoryScreen(),
      ),
      GoRoute(path: '/b/:id', builder: stub),
      GoRoute(path: '/bookings', builder: stub),
      GoRoute(path: '/instant/:id', builder: stub),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      textScale: textScale,
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: _uid)),
        ),
        paymentsRepositoryProvider.overrideWithValue(payments),
        clockProvider.overrideWithValue(() => _now),
      ],
    ),
  );
  await tester.tap(find.text('go'));
  await _settle(tester);
  return _Harness(payments, router);
}

void main() {
  testWidgets('shows held and refunding totals', (tester) async {
    await _open(
      tester,
      totals: const PaymentTotals(held: 2300000, refunding: 1700000),
    );
    expect(find.text('Lịch sử thanh toán'), findsOneWidget);
    expect(find.widgetWithText(StatTile, '2,3M'), findsOneWidget);
    expect(find.widgetWithText(StatTile, 'Đang giữ'), findsOneWidget);
    expect(find.widgetWithText(StatTile, '1,7M'), findsOneWidget);
    expect(find.widgetWithText(StatTile, 'Đang hoàn'), findsOneWidget);
    expect(
      find.text(
        'Tiền bạn trả được trung gian thanh toán giữ, chỉ chuyển cho thợ '
        'theo 2 mốc.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('groups rows by month with "Các khoản" first', (tester) async {
    await _open(
      tester,
      rows: [
        _row('a'),
        _row(
          'b',
          photographerName: 'Quốc Bảo',
          serviceName: 'Gia đình 1 giờ',
          day: '2026-09-28',
          createdAt: DateTime.utc(2026, 9, 20, 3),
        ),
      ],
    );
    expect(find.text('Các khoản'), findsOneWidget);
    expect(find.text('Tháng 10'), findsOneWidget);
    expect(find.text('Tháng 9'), findsOneWidget);
    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(find.text('Các khoản')), lessThan(y(_key('pay-row-a'))));
    expect(y(_key('pay-row-a')), lessThan(y(find.text('Tháng 9'))));
    expect(y(find.text('Tháng 9')), lessThan(y(_key('pay-row-b'))));
  });

  testWidgets(
    'a held booking row reads "Đang giữ" with method "Chuyển khoản QR"',
    (tester) async {
      await _open(tester, rows: [_row('a')]);
      expect(
        _inRow('a', find.text('Minh Trí · Chân dung 2 giờ')),
        findsOneWidget,
      );
      expect(
        _inRow('a', find.text('T2 12/10 · Chuyển khoản QR')),
        findsOneWidget,
      );
      expect(_inRow('a', find.text('1,5M')), findsOneWidget);
      expect(_inRow('a', find.text('Đang giữ')), findsOneWidget);
    },
  );

  testWidgets('a released ticket reads "Đã chuyển cho chủ sự kiện"', (
    tester,
  ) async {
    await _open(
      tester,
      rows: [
        _ticket(status: PayerRowStatus.released),
        _row(
          'p',
          subject: PayerSubjectType.eventRegistration,
          subjectId: 'reg2',
          eventId: 'e2',
          eventTitle: 'Ngày hội nhiếp ảnh',
          quantity: 1,
          status: PayerRowStatus.released,
          toPlatform: true,
          open: false,
        ),
        _row(
          'b',
          status: PayerRowStatus.released,
          open: false,
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      ],
    );
    expect(_inRow('t1', find.text('Photo walk phố cổ · 2 vé')), findsOneWidget);
    expect(
      _inRow('t1', find.text('Đã chuyển cho chủ sự kiện')),
      findsOneWidget,
    );
    expect(_inRow('p', find.text('Đã thanh toán')), findsOneWidget);
    expect(_inRow('b', find.text('Đã chuyển cho thợ')), findsOneWidget);
  });

  testWidgets('the S21 fee row reads "Phí xác minh" and "Đã thanh toán"', (
    tester,
  ) async {
    await _open(
      tester,
      rows: [
        _row(
          'f',
          subject: PayerSubjectType.verificationFee,
          subjectId: 'fee1',
          photographerName: null,
          serviceName: null,
          day: null,
          status: PayerRowStatus.released,
          toPlatform: true,
          open: false,
          amount: 50000,
        ),
      ],
    );
    expect(_inRow('f', find.text('Phí xác minh')), findsOneWidget);
    expect(_inRow('f', find.text('Đã thanh toán')), findsOneWidget);
    expect(
      _inRow('f', find.text('T2 12/10 · Chuyển khoản QR')),
      findsOneWidget,
    );
  });

  testWidgets('an instant row reads "Chụp ngay · Quận 1" and "đang tìm thợ"', (
    tester,
  ) async {
    await _open(tester, rows: [_instant()]);
    expect(_inRow('i1', find.text('Chụp ngay · Quận 1')), findsOneWidget);
    expect(
      _inRow('i1', find.text('Hôm nay 09:12 · MoMo · đang tìm thợ')),
      findsOneWidget,
    );
    expect(_inRow('i1', find.text('800K')), findsOneWidget);
    expect(_inRow('i1', find.text('Đang giữ')), findsOneWidget);

    await _tapRow(tester, 'i1');
    await tester.tap(find.text('Xem yêu cầu Chụp ngay'));
    await _settle(tester);
    expect(find.text('stub /instant/req1'), findsOneWidget);
  });

  testWidgets(
    'tapping a refunding row shows "Hoàn về ví ZaloPay · đang xử lý" and "Sẽ nhận lại"',
    (tester) async {
      final h = await _open(
        tester,
        rows: [
          _ticket(
            refundingAmount: 500000,
            refunds: [
              PayerRefundView(
                refundId: 'r1',
                amount: 500000,
                status: 'pending',
                wallet: true,
                destinationLabel: null,
                createdAt: DateTime.utc(2026, 10, 20),
              ),
            ],
          ),
        ],
      );
      expect(_inRow('t1', find.text('CN 18/10 · ZaloPay')), findsOneWidget);
      expect(_inRow('t1', find.text('Đang hoàn')), findsOneWidget);
      expect(find.text('Sẽ nhận lại'), findsNothing);

      await _tapRow(tester, 't1');
      expect(find.text('Đã trả'), findsOneWidget);
      expect(find.text('Hoàn về ví ZaloPay · đang xử lý'), findsOneWidget);
      expect(find.text('Sẽ nhận lại'), findsOneWidget);
      expect(find.text('500.000₫'), findsNWidgets(3));

      await tester.tap(find.text('Xem vé'));
      await _settle(tester);
      expect(h.location, '/bookings?tab=events&highlight=reg1');
    },
  );

  testWidgets('a bank refund line shows "Vietcombank •••• 6789"', (
    tester,
  ) async {
    await _open(
      tester,
      rows: [
        _row(
          'a',
          status: PayerRowStatus.partiallyRefunded,
          open: false,
          cancelled: true,
          refundedAmount: 750000,
          refunds: [
            PayerRefundView(
              refundId: 'r1',
              amount: 750000,
              status: 'done',
              wallet: false,
              destinationLabel: 'Vietcombank •••• 6789',
              createdAt: DateTime.utc(2026, 10, 12, 5),
              doneAt: DateTime.utc(2026, 10, 13),
            ),
          ],
        ),
      ],
    );
    expect(
      _inRow('a', find.text('T2 12/10 · Chuyển khoản QR · đã huỷ')),
      findsOneWidget,
    );
    expect(_inRow('a', find.text('Đã hoàn một phần')), findsOneWidget);
    await _tapRow(tester, 'a');
    expect(find.text('Hoàn về Vietcombank •••• 6789 · đã về'), findsOneWidget);
    expect(find.text('750.000₫'), findsOneWidget);
    // Nothing is on its way back any more.
    expect(find.text('Sẽ nhận lại'), findsNothing);
  });

  testWidgets('"Xem buổi chụp" opens /b/:id', (tester) async {
    await _open(tester, rows: [_row('a', subjectId: 'bk42')]);
    expect(find.text('Xem buổi chụp'), findsNothing);
    await _tapRow(tester, 'a');
    await tester.tap(find.text('Xem buổi chụp'));
    await _settle(tester);
    expect(find.text('stub /b/bk42'), findsOneWidget);
  });

  testWidgets('"Xem thêm" raises the limit by 20', (tester) async {
    final rows = [
      for (var i = 0; i < 25; i++)
        _row(
          'r$i',
          createdAt: DateTime.utc(2026, 10, 1).add(Duration(hours: i)),
        ),
    ];
    final slow = _SlowPages();
    final h = await _open(tester, rows: rows, repo: slow);
    expect(h.payments.historyLimits, [20]);
    final more = find.widgetWithText(AppButton, 'Xem thêm');
    await tester.scrollUntilVisible(more, 300);
    await tester.pump();
    await tester.tap(more);
    await _settle(tester);
    // The rows shown so far stay while the bigger page loads: no skeleton.
    expect(_key('pay-row-r24'), findsOneWidget);
    expect(find.byType(DotRingLoader), findsNothing);
    slow.gate.complete();
    await _settle(tester);
    expect(h.payments.historyLimits, [20, 40]);
    // 25 rows < 40: the page is not full, no more button.
    expect(more, findsNothing);
  });

  testWidgets(
    '"Chọn tài khoản nhận hoàn" on a refund_account_needed row opens the S22.04 sheet for that subject',
    (tester) async {
      final h = await _open(
        tester,
        rows: [
          _row(
            'a',
            subjectId: 'bk7',
            status: PayerRowStatus.refundAccountNeeded,
            cancelled: true,
          ),
          // A Chụp ngay refund never asks (it reads "Đang hoàn").
          _row(
            'i',
            subject: PayerSubjectType.instantRequest,
            subjectId: 'req9',
            status: PayerRowStatus.refunding,
            areaLabel: 'Quận 3',
            createdAt: DateTime.utc(2026, 10, 10),
          ),
        ],
        seed: (p) => p.pendingBySubject[const BookingRefund('bk7')] =
            const PendingRefund(refundId: 'rf1', amount: 1500000),
      );
      expect(_inRow('a', find.text('Cần tài khoản')), findsOneWidget);
      final button = find.widgetWithText(AppButton, 'Chọn tài khoản nhận hoàn');
      expect(button, findsOneWidget);
      expect(_inRow('i', find.text('Chọn tài khoản nhận hoàn')), findsNothing);

      await tester.tap(button);
      await _settle(tester);
      expect(h.payments.pendingCalls, [const BookingRefund('bk7')]);
      expect(find.text('Tài khoản nhận hoàn'), findsOneWidget);
      expect(
        find.text(
          'Chưa có thông tin tài khoản đã chuyển. Nhập tài khoản để nhận tiền hoàn.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a ticket waiting for an account opens S22.04 for the ticket', (
    tester,
  ) async {
    final h = await _open(
      tester,
      rows: [_ticket(status: PayerRowStatus.refundAccountNeeded)],
    );
    await tester.tap(
      find.widgetWithText(AppButton, 'Chọn tài khoản nhận hoàn'),
    );
    await _settle(tester);
    expect(h.payments.pendingCalls, [const TicketRefund('e1', 'reg1')]);
  });

  testWidgets('an unknown status/subject renders as a generic row', (
    tester,
  ) async {
    await _open(
      tester,
      rows: [
        _row(
          'u',
          subject: PayerSubjectType.unknown,
          status: PayerRowStatus.unknown,
          photographerName: null,
          serviceName: null,
        ),
        _row(
          'v',
          status: PayerRowStatus.unknown,
          open: false,
          createdAt: DateTime.utc(2026, 10, 11),
        ),
      ],
    );
    expect(_inRow('u', find.text('Thanh toán')), findsOneWidget);
    expect(_inRow('u', find.text('Đang giữ')), findsOneWidget);
    expect(_inRow('u', find.text('1,5M')), findsOneWidget);
    expect(
      _inRow('v', find.text('Minh Trí · Chân dung 2 giờ')),
      findsOneWidget,
    );
    expect(_inRow('v', find.text('Đã thanh toán')), findsOneWidget);
    await _tapRow(tester, 'u');
    expect(find.text('Đã trả'), findsOneWidget);
    expect(find.text('Xem buổi chụp'), findsNothing);
  });

  testWidgets('empty state copy', (tester) async {
    await _open(tester);
    expect(find.text('Chưa có khoản thanh toán nào'), findsOneWidget);
    expect(
      find.text('Khi bạn đặt lịch hay mua vé, các khoản sẽ hiện ở đây.'),
      findsOneWidget,
    );
    expect(find.byType(EarningRow), findsNothing);
  });

  testWidgets('no text contains "cọc"', (tester) async {
    await _open(
      tester,
      totals: const PaymentTotals(held: 2300000, refunding: 500000),
      rows: [
        _ticket(
          refundingAmount: 500000,
          refunds: [
            PayerRefundView(
              refundId: 'r1',
              amount: 500000,
              status: 'pending',
              wallet: true,
              destinationLabel: null,
              createdAt: DateTime.utc(2026, 10, 20),
            ),
          ],
        ),
        _row('a'),
        _instant(),
      ],
    );
    for (final id in ['t1', 'a', 'i1']) {
      await _tapRow(tester, id);
    }
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
    expect(texts.where((t) => t.toLowerCase().contains('cọc')), isEmpty);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _open(
      tester,
      width: 320,
      textScale: 1.3,
      totals: const PaymentTotals(held: 12400000, refunding: 1700000),
      rows: [
        _ticket(status: PayerRowStatus.released),
        _row('a', status: PayerRowStatus.refundAccountNeeded, cancelled: true),
        _instant(),
      ],
    );
    expect(tester.takeException(), isNull);
    await _tapRow(tester, 't1');
    expect(tester.takeException(), isNull);
  });
}
