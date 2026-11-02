import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/payments/payment_group.dart';

Timestamp _ts(String iso) => Timestamp.fromDate(DateTime.parse(iso));

Map<String, dynamic> _doc() => {
  'payerId': 'c1',
  'lines': [
    {
      'paymentId': 'p1',
      'kind': 'booking',
      'subjectType': 'booking',
      'subjectId': 'b1',
      'payeeId': 'ph1',
      'amount': 1000000,
    },
    {
      'paymentId': 'p2',
      'kind': 'entry_ticket',
      'subjectType': 'event_registration',
      'subjectId': 'r1',
      'payeeId': 'org1',
      'amount': 140000,
    },
    {'paymentId': 'p3', 'kind': 'unknown_kind', 'amount': 5},
  ],
  'total': 1140000,
  'status': 'paid',
  'expiresAt': _ts('2026-11-01T00:15:00Z'),
  'createdAt': _ts('2026-11-01T00:00:00Z'),
  'updatedAt': _ts('2026-11-01T00:05:00Z'),
};

void main() {
  test('PaymentGroup.fromDoc lists lines with kind and payee', () {
    final g = PaymentGroup.fromDoc('g1', _doc())!;
    expect(g.id, 'g1');
    expect(g.payerId, 'c1');
    expect(g.lines.map((l) => l.kind), [
      PaymentLineKind.booking,
      PaymentLineKind.entryTicket,
    ]);
    expect(g.lines.map((l) => l.payeeId), ['ph1', 'org1']);
    expect(g.lines.last.subjectId, 'r1');
    expect(g.total, 1140000);
    expect(g.status, PaymentGroupStatus.paid);
    expect(g.expiresAt, DateTime.parse('2026-11-01T00:15:00Z'));
    expect(g.amountOf(PaymentLineKind.entryTicket), 140000);
    expect(g.amountOf(PaymentLineKind.venueFee), 0);
    expect(PaymentGroup.fromDoc('g1', null), isNull);
    expect(
      PaymentGroup.fromDoc('g1', {..._doc(), 'status': '?'})!.status,
      PaymentGroupStatus.created,
    );
  });

  test('the Firestore reader watches payment_groups/{id}', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestorePaymentGroupRepository(db: db);
    expect(await repo.watch('g1').first, isNull);
    await db.collection('payment_groups').doc('g1').set(_doc());
    expect((await repo.watch('g1').first)!.total, 1140000);
  });
}
