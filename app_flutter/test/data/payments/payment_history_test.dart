import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payments_repository.dart';

import '../../support/fake_payments_repository.dart';

Timestamp _ts(int day, [int hour = 0]) =>
    Timestamp.fromDate(DateTime.utc(2026, 10, day, hour));

/// A row as Task 6's `payerRowToFirestore` writes it.
Map<String, dynamic> _row({
  String status = 'held',
  String subjectType = 'booking',
  Object? method = 'bank_qr',
  int createdDay = 10,
  List<Map<String, dynamic>> refunds = const [],
}) => {
  'payerId': 'lan',
  'subjectType': subjectType,
  'subjectId': 'b1',
  'eventId': null,
  'photographerName': 'Minh Trí',
  'serviceName': 'Chân dung 2 giờ',
  'eventTitle': null,
  'quantity': null,
  'areaLabel': null,
  'day': '2026-10-20',
  'method': method,
  'amount': 1500000,
  'status': status,
  'open': true,
  'toPlatform': false,
  'heldAmount': 750000,
  'refundingAmount': 750000,
  'refundedAmount': 0,
  'searching': false,
  'cancelled': true,
  'refunds': refunds,
  'createdAt': _ts(createdDay, 3),
  'paidAt': _ts(createdDay, 4),
  'updatedAt': _ts(createdDay, 5),
};

void main() {
  group('payerRowFrom', () {
    test('payerRowFrom parses every status code and the refunds list', () {
      const codes = {
        'held': PayerRowStatus.held,
        'disputed': PayerRowStatus.disputed,
        'released': PayerRowStatus.released,
        'refund_account_needed': PayerRowStatus.refundAccountNeeded,
        'refunding': PayerRowStatus.refunding,
        'refunded': PayerRowStatus.refunded,
        'partially_refunded': PayerRowStatus.partiallyRefunded,
      };
      for (final e in codes.entries) {
        expect(payerRowFrom('p1', _row(status: e.key))?.status, e.value);
      }

      final row = payerRowFrom(
        'p1',
        _row(
          status: 'refunding',
          refunds: [
            {
              'refundId': 'r1',
              'amount': 750000,
              'status': 'pending',
              'method': 'bank_transfer',
              'kind': 'policy',
              'destinationLabel': 'Vietcombank •••• 6789',
              'createdAt': _ts(12, 1),
              'doneAt': null,
            },
            {
              'refundId': 'r2',
              'amount': 200000,
              'status': 'done',
              'method': 'gateway',
              'kind': 'excess',
              'destinationLabel': null,
              'createdAt': _ts(10, 4),
              'doneAt': _ts(10, 6),
            },
          ],
        ),
      )!;
      expect(row.paymentId, 'p1');
      expect(row.subjectType, PayerSubjectType.booking);
      expect(row.subjectId, 'b1');
      expect(row.photographerName, 'Minh Trí');
      expect(row.serviceName, 'Chân dung 2 giờ');
      expect(row.day, '2026-10-20');
      expect(row.method, PayMethod.bankQr);
      expect(row.amount, 1500000);
      expect(row.open, isTrue);
      expect(row.toPlatform, isFalse);
      expect(row.heldAmount, 750000);
      expect(row.refundingAmount, 750000);
      expect(row.refundedAmount, 0);
      expect(row.cancelled, isTrue);
      expect(row.searching, isFalse);
      expect(row.createdAt, DateTime.utc(2026, 10, 10, 3));
      expect(row.paidAt, DateTime.utc(2026, 10, 10, 4));
      expect(row.refunds, hasLength(2));
      final bank = row.refunds.first;
      expect(bank.refundId, 'r1');
      expect(bank.amount, 750000);
      expect(bank.status, 'pending');
      expect(bank.done, isFalse);
      expect(bank.wallet, isFalse);
      expect(bank.destinationLabel, 'Vietcombank •••• 6789');
      expect(bank.createdAt, DateTime.utc(2026, 10, 12, 1));
      expect(bank.doneAt, isNull);
      final wallet = row.refunds.last;
      expect(wallet.wallet, isTrue);
      expect(wallet.done, isTrue);
      expect(wallet.destinationLabel, isNull);
      expect(wallet.doneAt, DateTime.utc(2026, 10, 10, 6));
    });

    test('a refund without a method is not a wallet refund', () {
      final row = payerRowFrom(
        'p1',
        _row(
          refunds: [
            {
              'refundId': 'r1',
              'amount': 1000,
              'status': 'pending',
              'createdAt': _ts(12, 1),
            },
          ],
        ),
      )!;
      expect(row.refunds.single.wallet, isFalse);
    });

    test('an unknown status/subject renders as a generic row', () {
      // Installed apps lag behind the server: a newer code keeps its row (its
      // money and its place in the page), only a missing document is skipped.
      final status = payerRowFrom('p1', _row(status: 'paid_out'))!;
      expect(status.status, PayerRowStatus.unknown);
      expect(status.subjectType, PayerSubjectType.booking);
      expect(status.amount, 1500000);
      expect(status.open, isTrue);

      final subject = payerRowFrom('p1', _row(subjectType: 'gift_card'))!;
      expect(subject.subjectType, PayerSubjectType.unknown);
      expect(subject.status, PayerRowStatus.held);

      final noStatus = payerRowFrom('p1', {..._row(), 'status': null})!;
      expect(noStatus.status, PayerRowStatus.unknown);

      expect(payerRowFrom('p1', null), isNull);
    });

    test('instant_request subject parses', () {
      final row = payerRowFrom('p2', {
        ..._row(subjectType: 'instant_request', method: 'zalopay'),
        'photographerName': null,
        'serviceName': null,
        'areaLabel': 'Quận 1, TP.HCM',
        'day': null,
        'searching': true,
        'cancelled': false,
      })!;
      expect(row.subjectType, PayerSubjectType.instantRequest);
      expect(row.areaLabel, 'Quận 1, TP.HCM');
      expect(row.searching, isTrue);
      expect(row.day, isNull);
      expect(row.method, PayMethod.zaloPay);
    });

    test(
      'a ticket, the S21 fee and a legacy payment without a method parse',
      () {
        final ticket = payerRowFrom('p3', {
          ..._row(subjectType: 'event_registration'),
          'eventId': 'e1',
          'eventTitle': 'Workshop ánh sáng',
          'quantity': 2,
          'toPlatform': true,
        })!;
        expect(ticket.subjectType, PayerSubjectType.eventRegistration);
        expect(ticket.eventId, 'e1');
        expect(ticket.eventTitle, 'Workshop ánh sáng');
        expect(ticket.quantity, 2);
        expect(ticket.toPlatform, isTrue);

        final fee = payerRowFrom(
          'p4',
          _row(subjectType: 'verification_fee', method: null),
        )!;
        expect(fee.subjectType, PayerSubjectType.verificationFee);
        expect(fee.method, isNull);
      },
    );

    test('PaymentTotals parses held and refunding; missing is zero', () {
      final t = paymentTotalsFrom({'held': 1500000, 'refunding': 200000});
      expect(t.held, 1500000);
      expect(t.refunding, 200000);
      final none = paymentTotalsFrom(null);
      expect(none.held, 0);
      expect(none.refunding, 0);
    });
  });

  group('pendingRefundFrom', () {
    test('PendingRefund parses payer and confirmBy, and null', () {
      final p = pendingRefundFrom({
        'refundId': 'r1',
        'amount': 750000,
        'payer': {
          'bankName': 'Vietcombank',
          'accountLast4': '6789',
          'holderName': 'NGUYEN THANH HA',
        },
        'confirmBy': '2026-10-11T03:00:00.000Z',
      })!;
      expect(p.refundId, 'r1');
      expect(p.amount, 750000);
      expect(p.payer?.bankName, 'Vietcombank');
      expect(p.payer?.accountLast4, '6789');
      expect(p.payer?.holderName, 'NGUYEN THANH HA');
      expect(p.confirmBy, DateTime.utc(2026, 10, 11, 3));

      final noPayer = pendingRefundFrom(<Object?, Object?>{
        'refundId': 'r2',
        'amount': 300000,
        'payer': null,
        'confirmBy': null,
      })!;
      expect(noPayer.payer, isNull);
      expect(noPayer.confirmBy, isNull);

      expect(pendingRefundFrom(null), isNull);
    });
  });

  group('FirebasePaymentsRepository (Firestore)', () {
    late FakeFirebaseFirestore db;
    late FirebasePaymentsRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = FirebasePaymentsRepository(firestore: db);
    });

    test('watchHistory reads the owner rows newest first, limited, keeping unknown ones', () async {
      final rows = db.collection('users').doc('lan').collection('payments');
      await rows.doc('old').set(_row(createdDay: 1));
      await rows.doc('new').set(_row(createdDay: 9));
      await rows.doc('mid').set(_row(createdDay: 5));
      await rows.doc('odd').set(_row(createdDay: 8, status: 'mystery'));
      await db
          .collection('users')
          .doc('giang')
          .collection('payments')
          .doc('other')
          .set(_row(createdDay: 20));

      final firstThree = await repo.watchHistory('lan', limit: 3).first;
      expect(firstThree.map((r) => r.paymentId), ['new', 'odd', 'mid']);
      expect(firstThree[1].status, PayerRowStatus.unknown);

      final all = await repo.watchHistory('lan', limit: 20).first;
      expect(all.map((r) => r.paymentId), ['new', 'odd', 'mid', 'old']);
    });

    test(
      'watchTotals reads users/{uid}/private/paymentTotals; missing is zero',
      () async {
        expect((await repo.watchTotals('lan').first).held, 0);
        await db
            .collection('users')
            .doc('lan')
            .collection('private')
            .doc('paymentTotals')
            .set({'held': 750000, 'refunding': 200000, 'updatedAt': _ts(10)});
        final t = await repo.watchTotals('lan').first;
        expect(t.held, 750000);
        expect(t.refunding, 200000);
      },
    );
  });

  group('providers', () {
    test('paymentHistoryProvider and paymentTotalsProvider follow the signed-in uid', () async {
      final fake = FakePaymentsRepository()
        ..emitHistory('lan', [payerRowFrom('p1', _row())!])
        ..emitTotals('lan', const PaymentTotals(held: 750000))
        ..emitHistory('giang', [payerRowFrom('p9', _row(createdDay: 2))!])
        ..emitTotals('giang', const PaymentTotals(refunding: 200000));
      final auth = StreamController<AuthUser?>();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          paymentsRepositoryProvider.overrideWithValue(fake),
          authStateProvider.overrideWith((ref) => auth.stream),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(paymentHistoryProvider(20), (_, _) {});
      final totalsSub = container.listen(paymentTotalsProvider, (_, _) {});
      addTearDown(sub.close);
      addTearDown(totalsSub.close);
      auth.add(const AuthUser(uid: 'lan'));
      await container.read(authStateProvider.future);
      final rows = await container.read(paymentHistoryProvider(20).future);
      expect(rows.single.paymentId, 'p1');
      expect(fake.historyLimits, [20]);
      final totals = await container.read(paymentTotalsProvider.future);
      expect(totals.held, 750000);

      // Another account signs in on the same device: its own rows only.
      auth.add(const AuthUser(uid: 'giang'));
      await pumpEventQueue();
      final next = await container.read(paymentHistoryProvider(20).future);
      expect(next.single.paymentId, 'p9');
      final nextTotals = await container.read(paymentTotalsProvider.future);
      expect(nextTotals.held, 0);
      expect(nextTotals.refunding, 200000);
    });

    test('signed out → no rows and zero totals', () async {
      final container = ProviderContainer(
        overrides: [
          paymentsRepositoryProvider.overrideWithValue(
            FakePaymentsRepository(),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(paymentHistoryProvider(20), (_, _) {});
      final totalsSub = container.listen(paymentTotalsProvider, (_, _) {});
      addTearDown(sub.close);
      addTearDown(totalsSub.close);
      await container.read(authStateProvider.future);
      expect(await container.read(paymentHistoryProvider(20).future), isEmpty);
      expect((await container.read(paymentTotalsProvider.future)).held, 0);
    });
  });
}
