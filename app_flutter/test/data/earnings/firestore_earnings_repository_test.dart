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

  test('saveAccount returns the id and last 4', () async {
    final result = _MockResult();
    when(() => result.data)
        .thenReturn({'accountId': 'a1', 'accountLast4': '6789'});
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
    final r = await repo.saveAccount(
      bankCode: 'VCB',
      accountNumber: '0123456789',
      holderName: 'AN',
    );
    expect(r.accountLast4, '6789');
    verify(
      () => callable.call<Object?>({
        'bankCode': 'VCB',
        'accountNumber': '0123456789',
        'holderName': 'AN',
      }),
    ).called(1);
  });

  Future<String> failWith(Object error) async {
    when(() => callable.call<Object?>(any())).thenThrow(error);
    try {
      await repo.saveAccount(
        bankCode: 'VCB',
        accountNumber: '0123456789',
        holderName: 'AN',
      );
    } on PayoutAccountError catch (e) {
      return e.code;
    }
    return 'none';
  }

  test('saveAccount maps reauth_required', () async {
    expect(
      await failWith(
        FirebaseFunctionsException(
          message: 'reauth_required',
          code: 'failed-precondition',
          details: {'code': 'reauth_required'},
        ),
      ),
      'reauth_required',
    );
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

  test('saveAccount maps conflict, invalid argument and the rest', () async {
    expect(
      await failWith(
        FirebaseFunctionsException(
          message: 'conflict',
          code: 'aborted',
          details: {'code': 'conflict'},
        ),
      ),
      'conflict',
    );
    expect(
      await failWith(
        FirebaseFunctionsException(
          message: 'invalid_argument',
          code: 'invalid-argument',
        ),
      ),
      'invalid_argument',
    );
    expect(await failWith(StateError('boom')), 'unknown');
  });
}
