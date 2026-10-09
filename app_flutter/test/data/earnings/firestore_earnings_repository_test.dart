import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/firestore_earnings_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreEarningsRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreEarningsRepository(db: db, functions: functions);
  });

  Future<void> addItem(String id, String day, int amount) => db
      .collection('earnings')
      .doc('u1')
      .collection('items')
      .doc(id)
      .set({'state': 'held', 'day': day, 'amount': amount});

  test('items are asked newest day first with the limit', () async {
    await addItem('a', '2026-09-01', 1);
    await addItem('b', '2026-10-01', 2);
    await addItem('c', '2026-10-01', 3);
    await addItem('d', '2026-08-01', 4);
    final list = await repo.watchItems('u1', limit: 3).first;
    expect([for (final i in list) i.id], ['c', 'b', 'a']);
  });

  test('a summary stream reads the doc and a missing doc is zero', () async {
    expect((await repo.watchSummary('u1').first).heldVnd, 0);
    await db.collection('earnings').doc('u1').set({'heldAmount': 5});
    expect((await repo.watchSummary('u1').first).heldVnd, 5);
  });

  test('watchAccount reads the masked view', () async {
    expect(await repo.watchAccount('u1').first, isNull);
    await db.collection('payoutAccounts').doc('u1').set({
      'accountId': 'a1',
      'bankCode': 'VCB',
      'accountLast4': '3456',
      'holderName': 'AN',
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
    });
    final v = await repo.watchAccount('u1').first;
    expect(v!.accountLast4, '3456');
  });

  group('parsing', () {
    test(
      'earningItemFrom reads fee, tax, net, rates, estimated and milestones',
      () {
        final i = earningItemFrom('pay1', {
          'state': 'paid_out',
          'day': '2026-10-01',
          'amount': 1500000,
          'platformFee': 15000,
          'taxWithheld': 105000,
          'netAmount': 1380000,
          'feeRateBp': 100,
          'taxRateBp': 700,
          'estimated': false,
          'milestonesDone': 1,
          'milestonesTotal': 2,
        })!;
        expect(i.amountVnd, 1500000);
        expect(i.feeVnd, 15000);
        expect(i.taxVnd, 105000);
        expect(i.netVnd, 1380000);
        expect(i.feeRateBp, 100);
        expect(i.taxRateBp, 700);
        expect(i.estimated, isFalse);
        expect(i.milestonesDone, 1);
        expect(i.milestonesTotal, 2);
      },
    );

    test(
      'an old item reads net = amount, tax 0, estimated true, milestones null',
      () {
        final i = earningItemFrom('old', {'state': 'held', 'amount': 450000})!;
        expect(i.netVnd, 450000);
        expect(i.taxVnd, 0);
        expect(i.feeVnd, 0);
        expect(i.taxRateBp, 0);
        expect(i.feeRateBp, 0);
        expect(i.estimated, isTrue);
        expect(i.milestonesDone, isNull);
        expect(i.milestonesTotal, isNull);
      },
    );

    test('payoutAccountViewFrom reads activeFrom and nameStatus; '
        'an old view is matched and active', () {
      final updated = DateTime.utc(2026, 10, 1);
      final from = DateTime.utc(2026, 10, 4, 3, 15);
      final base = {
        'accountId': 'a1',
        'bankCode': 'VCB',
        'accountLast4': '3456',
        'holderName': 'NGUYEN VAN AN',
        'updatedAt': Timestamp.fromDate(updated),
      };
      final v = payoutAccountViewFrom({
        ...base,
        'nameStatus': 'pending_review',
        'activeFrom': Timestamp.fromDate(from),
      })!;
      expect(v.activeFrom, from);
      expect(v.nameStatus, PayoutNameStatus.pendingReview);
      expect(v.pendingAt(DateTime.utc(2026, 10, 2)), isTrue);
      expect(v.pendingAt(from), isFalse);
      expect(
        payoutAccountViewFrom({...base, 'nameStatus': 'staff_confirmed'})!
            .nameStatus,
        PayoutNameStatus.staffConfirmed,
      );

      final old = payoutAccountViewFrom(base)!;
      expect(old.nameStatus, PayoutNameStatus.matched);
      expect(old.activeFrom, updated);
      expect(old.pendingAt(updated), isFalse);
      expect(
        payoutAccountViewFrom({...base, 'nameStatus': 'mystery'})!.nameStatus,
        PayoutNameStatus.matched,
      );
    });
  });

  HttpsCallable stubCall(String name, Object? data) {
    final c = _MockCallable();
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => c.call<Object?>(any())).thenAnswer((_) async => result);
    when(() => functions.httpsCallable(name, options: any(named: 'options')))
        .thenReturn(c);
    return c;
  }

  test('lookupAccountName calls lookupPayoutAccountName and maps each decision code', () async {
    const codes = {
      'matched': PayoutNameDecision.matched,
      'mismatch': PayoutNameDecision.mismatch,
      'review': PayoutNameDecision.review,
      'not_found': PayoutNameDecision.notFound,
      'unverifiable': PayoutNameDecision.unverifiable,
      'mystery': PayoutNameDecision.review,
    };
    for (final MapEntry(key: code, value: decision) in codes.entries) {
      final c = stubCall('lookupPayoutAccountName', {
        'decision': code,
        'holderName': 'TRAN VAN B',
        'verifiedName': 'Nguyễn Văn An',
      });
      final r = await repo.lookupAccountName(
        bankCode: 'MB',
        accountNumber: '0987654321',
      );
      expect(r.decision, decision, reason: code);
      expect(r.holderName, 'TRAN VAN B');
      expect(r.verifiedName, 'Nguyễn Văn An');
      verify(
        () =>
            c.call<Object?>({'bankCode': 'MB', 'accountNumber': '0987654321'}),
      ).called(1);
    }
    stubCall('lookupPayoutAccountName', {
      'decision': 'review',
      'holderName': null,
      'verifiedName': null,
    });
    final none = await repo.lookupAccountName(
      bankCode: 'MB',
      accountNumber: '0123459999',
    );
    expect(none.holderName, isNull);
    expect(none.verifiedName, isNull);
  });

  test(
    'requestAccountOtp calls requestPayoutOtp and reads the ticket',
    () async {
      final c = stubCall('requestPayoutOtp', {
        'phoneLast4': '0001',
        'expiresInSeconds': 300,
        'resendInSeconds': 60,
      });
      final t = await repo.requestAccountOtp(
        bankCode: 'MB',
        accountNumber: '0123451234',
      );
      expect(t.phoneLast4, '0001');
      expect(t.expiresInSeconds, 300);
      expect(t.resendInSeconds, 60);
      verify(
        () =>
            c.call<Object?>({'bankCode': 'MB', 'accountNumber': '0123451234'}),
      ).called(1);
    },
  );

  test(
    'saveAccount sends otpCode only when given and returns activeFrom',
    () async {
      final c = stubCall('savePayoutAccount', {
        'accountId': 'a1',
        'accountLast4': '6789',
        'activeFrom': '2026-10-11T03:15:00.000Z',
        'nameStatus': 'matched',
      });
      final r = await repo.saveAccount(
        bankCode: 'VCB',
        accountNumber: '0123456789',
      );
      expect(r.accountId, 'a1');
      expect(r.accountLast4, '6789');
      expect(r.activeFrom, DateTime.utc(2026, 10, 11, 3, 15));
      verify(
        () =>
            c.call<Object?>({'bankCode': 'VCB', 'accountNumber': '0123456789'}),
      ).called(1);

      await repo.saveAccount(
        bankCode: 'VCB',
        accountNumber: '0123456789',
        otpCode: '123456',
      );
      verify(
        () => c.call<Object?>({
          'bankCode': 'VCB',
          'accountNumber': '0123456789',
          'otpCode': '123456',
        }),
      ).called(1);
    },
  );

  Future<String> failWith(Object error) async {
    when(() => callable.call<Object?>(any())).thenThrow(error);
    try {
      await repo.saveAccount(bankCode: 'VCB', accountNumber: '0123456789');
    } on PayoutAccountError catch (e) {
      return e.code;
    }
    return 'none';
  }

  FirebaseFunctionsException refusal(String code, String transport) =>
      FirebaseFunctionsException(
        message: code,
        code: transport,
        details: {'code': code},
      );

  test('callable errors map to PayoutAccountError codes (name_mismatch, '
      'otp_invalid, otp_expired, otp_required, limit_exceeded, '
      'phone_required, not_eligible, not_found)', () async {
    const cases = {
      'name_mismatch': 'failed-precondition',
      'otp_invalid': 'failed-precondition',
      'otp_expired': 'failed-precondition',
      'otp_required': 'failed-precondition',
      'limit_exceeded': 'resource-exhausted',
      'phone_required': 'failed-precondition',
      'not_eligible': 'failed-precondition',
      'not_found': 'not-found',
      'conflict': 'aborted',
      'permission_denied': 'permission-denied',
      'invalid_argument': 'invalid-argument',
    };
    for (final MapEntry(key: code, value: transport) in cases.entries) {
      expect(await failWith(refusal(code, transport)), code);
    }
    // Lookup and OTP requests map the same way.
    when(() => callable.call<Object?>(any()))
        .thenThrow(refusal('limit_exceeded', 'resource-exhausted'));
    await expectLater(
      repo.lookupAccountName(bankCode: 'MB', accountNumber: '0123451234'),
      throwsA(
        isA<PayoutAccountError>().having(
          (e) => e.code,
          'code',
          'limit_exceeded',
        ),
      ),
    );
    when(() => callable.call<Object?>(any()))
        .thenThrow(refusal('phone_required', 'failed-precondition'));
    await expectLater(
      repo.requestAccountOtp(bankCode: 'MB', accountNumber: '0123451234'),
      throwsA(
        isA<PayoutAccountError>().having(
          (e) => e.code,
          'code',
          'phone_required',
        ),
      ),
    );
  });

  test('no argument appears in the error\'s toString', () async {
    when(() => callable.call<Object?>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'bad 0123456789',
        code: 'invalid-argument',
        details: {'code': 'invalid_argument', 'accountNumber': '0123456789'},
      ),
    );
    Object? caught;
    try {
      await repo.saveAccount(
        bankCode: 'VCB',
        accountNumber: '0123456789',
        otpCode: '654321',
      );
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<PayoutAccountError>());
    final text = caught.toString();
    expect(text.contains('0123456789'), isFalse);
    expect(text.contains('6789'), isFalse);
    expect(text.contains('654321'), isFalse);
    expect(text.contains('VCB'), isFalse);
  });

  test('saveAccount maps a network failure', () async {
    expect(
      await failWith(
        FirebaseFunctionsException(message: 'x', code: 'unavailable'),
      ),
      'network',
    );
    expect(
      await failWith(
        FirebaseFunctionsException(message: 'x', code: 'deadline-exceeded'),
      ),
      'network',
    );
  });

  test('an unexpected failure is unknown', () async {
    expect(await failWith(StateError('boom')), 'unknown');
    expect(
      await failWith(
        FirebaseFunctionsException(
          message: 'internal',
          code: 'internal',
          details: {'code': 'internal'},
        ),
      ),
      'unknown',
    );
  });
}
