import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/firestore_earnings_repository.dart';

void main() {
  test('a summary doc parses its three totals', () {
    final s = earningsSummaryFrom({
      'heldAmount': 1200000,
      'soonAmount': 300000,
      'receivedAmount': 4500000,
      'lastPayout': {'id': 'p1', 'status': 'paid'},
    });
    expect(s.heldVnd, 1200000);
    expect(s.soonVnd, 300000);
    expect(s.receivedVnd, 4500000);
    expect(s.lastPayoutFailed, isFalse);
  });

  test('a missing summary doc is all zero', () {
    final s = earningsSummaryFrom(null);
    expect((s.heldVnd, s.soonVnd, s.receivedVnd), (0, 0, 0));
    expect(s.lastPayoutFailed, isFalse);
  });

  test('a failed last payout sets lastPayoutFailed', () {
    final s = earningsSummaryFrom({
      'heldAmount': 0,
      'soonAmount': 10,
      'receivedAmount': 0,
      'lastPayout': {'id': 'p1', 'status': 'failed'},
    });
    expect(s.lastPayoutFailed, isTrue);
  });

  test('a cached snapshot sets fromCache', () {
    expect(
      earningsSummaryFrom({'heldAmount': 1}, fromCache: true).fromCache,
      isTrue,
    );
    expect(earningsSummaryFrom(null, fromCache: true).fromCache, isTrue);
    expect(earningsSummaryFrom({'heldAmount': 1}).fromCache, isFalse);
  });

  test('an item doc parses state, reason and payout date', () {
    final paid = DateTime.utc(2026, 10, 3, 5);
    final item = earningItemFrom('pay1', {
      'subjectType': 'booking',
      'subjectId': 'b1',
      'counterpartName': 'Lan',
      'subjectLabel': 'Chụp cưới',
      'day': '2026-10-01',
      'amount': 800000,
      'state': 'disputed',
      'holdReason': 'dispute',
      'paidOutAt': Timestamp.fromDate(paid),
    })!;
    expect(item.id, 'pay1');
    expect(item.state, EarningState.disputed);
    expect(item.holdReason, holdReasonDispute);
    expect(item.paidOutAt, paid);
    expect(item.amountVnd, 800000);
    expect(item.day, '2026-10-01');
    final paidOut = earningItemFrom('x', {'state': 'paid_out', 'amount': 1})!;
    expect(paidOut.state, EarningState.paidOut);
    expect(paidOut.holdReason, isNull);
    expect(paidOut.paidOutAt, isNull);
  });

  test('an unknown state is skipped', () {
    expect(earningItemFrom('x', {'state': 'mystery', 'amount': 1}), isNull);
    expect(earningItemFrom('x', {'amount': 1}), isNull);
  });

  test('the account view never has a full number field', () {
    final v = payoutAccountViewFrom({
      'accountId': 'a1',
      'bankCode': 'VCB',
      'accountLast4': '3456',
      'holderName': 'NGUYEN VAN AN',
      'accountNumber': '0123456789',
      'accountNumberEnc': 'v1:x',
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
    })!;
    expect(v.accountLast4, '3456');
    expect(v.toString().contains('0123456789'), isFalse);
    expect(payoutAccountViewFrom(null), isNull);
    expect(payoutAccountViewFrom({'accountId': 'a'}), isNull);
  });
}
