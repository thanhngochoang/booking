import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/firestore_booking_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> _checkoutWire() => {
  'paymentId': 'pay_1',
  'method': 'bank_qr',
  'amount': 1000000,
  'expiresAt': '2026-10-07T03:15:00.000Z',
  'transferCode': 'PB 7F3K2Q',
  'attempt': 1,
  'qrPayload': '000201...',
  'bankName': 'BIDV',
  'accountMasked': '9624 •••• 3812',
  'bankAppsUrl': 'https://fake-pay.local/bank-apps',
};

Map<String, dynamic> _bookingWire(String status) => {
  'id': 'b1',
  'customerId': 'c1',
  'photographerId': 'p1',
  'serviceId': 's1',
  'serviceSnapshot': {'name': 'Gói', 'price': 1000000, 'durationMinutes': 120},
  'day': '2026-10-20',
  'start': '09:00',
  'end': '11:00',
  'place': {'name': 'Hà Nội'},
  'status': status,
  'deposit': 1000000,
  'remaining': 0,
  'createdAt': '2026-10-07T03:00:00.000Z',
  'updatedAt': '2026-10-07T03:00:00.000Z',
};

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreBookingRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreBookingRepository(
      firestore: FakeFirebaseFirestore(),
      functions: functions,
    );
  });

  void answer(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
  }

  test(
    'createPayment sends {bookingId, method} and parses the checkout',
    () async {
      answer({'paymentId': 'pay_1', 'checkout': _checkoutWire()});

      final c = await repo.createPayment(
        bookingId: 'b1',
        method: PayMethod.bankQr,
      );

      verify(
        () => functions.httpsCallable(
          'createPayment',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => callable.call<Object?>({'bookingId': 'b1', 'method': 'bank_qr'}),
      ).called(1);
      expect(c.paymentId, 'pay_1');
      expect(c.method, PayMethod.bankQr);
      expect(c.expiresAt, DateTime.utc(2026, 10, 7, 3, 15));
    },
  );

  test('createPayment sends the wallet code for ZaloPay', () async {
    answer({
      'paymentId': 'pay_1',
      'checkout': _checkoutWire()..['method'] = 'zalopay',
    });
    await repo.createPayment(bookingId: 'b1', method: PayMethod.zaloPay);
    verify(
      () => callable.call<Object?>({'bookingId': 'b1', 'method': 'zalopay'}),
    ).called(1);
  });

  test(
    'createPayment answers invalid_response when the checkout is malformed',
    () async {
      answer({
        'paymentId': 'pay_1',
        'checkout': {'paymentId': 'pay_1'},
      });
      await expectLater(
        repo.createPayment(bookingId: 'b1', method: PayMethod.bankQr),
        throwsA(
          isA<BookingException>().having(
            (e) => e.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    },
  );

  test(
    'payment_attempts_exceeded from the server becomes the typed error',
    () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'x',
          code: 'failed-precondition',
          details: {'code': 'payment_attempts_exceeded'},
        ),
      );
      Object? caught;
      try {
        await repo.createPayment(bookingId: 'b1', method: PayMethod.bankQr);
      } catch (e) {
        caught = e;
      }
      expect(bookingErrorOf(caught!), BookingErrorCode.paymentAttemptsExceeded);
    },
  );

  test('checkPayment sends {bookingId} and parses {paid, booking}', () async {
    answer({'paid': true, 'booking': _bookingWire('requested')});

    final res = await repo.checkPayment(bookingId: 'b1');

    verify(
      () => functions.httpsCallable(
        'checkPayment',
        options: any(named: 'options'),
      ),
    ).called(1);
    verify(() => callable.call<Object?>({'bookingId': 'b1'})).called(1);
    expect(res.paid, isTrue);
    expect(res.booking?.id, 'b1');
  });

  test('checkPayment tolerates a null booking', () async {
    answer({'paid': false, 'booking': null});
    final res = await repo.checkPayment(bookingId: 'b1');
    expect(res.paid, isFalse);
    expect(res.booking, isNull);
  });

  test(
    'confirmFakePayment sends {paymentId, kind} and returns the outcome',
    () async {
      answer({'outcome': 'needs_review'});

      final outcome = await repo.confirmFakePayment(
        paymentId: 'pay_1',
        kind: FakeTransferKind.wrongContent,
      );

      verify(
        () => functions.httpsCallable(
          'confirmFakePayment',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => callable.call<Object?>({
          'paymentId': 'pay_1',
          'kind': 'wrong_content',
        }),
      ).called(1);
      expect(outcome, 'needs_review');
    },
  );

  test('confirmFakePayment defaults to exact', () async {
    answer({'outcome': 'paid'});
    await repo.confirmFakePayment(paymentId: 'pay_1');
    verify(
      () => callable.call<Object?>({'paymentId': 'pay_1', 'kind': 'exact'}),
    ).called(1);
  });

  test('cancelLateDelivery calls the callable with {bookingId} and maps failed-precondition -> notEligible/alreadyDelivered/notLate, aborted -> conflict', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('bookings').doc('b1').set({
      ..._bookingWire('completed'),
      'deliveryCancel': {
        'at': '2026-10-21T10:00:00.000Z',
        'dueAt': '2026-10-20T10:00:00.000Z',
        'refundedAmount': 500000,
      },
    });
    final repoWithDb = FirestoreBookingRepository(
      firestore: db,
      functions: functions,
    );
    answer({'status': 'completed', 'refundedAmount': 500000});

    final b = await repoWithDb.cancelLateDelivery(bookingId: 'b1');
    verify(
      () => functions.httpsCallable(
        'cancelLateDelivery',
        options: any(named: 'options'),
      ),
    ).called(1);
    verify(() => callable.call<Object?>({'bookingId': 'b1'})).called(1);
    expect(b.deliveryCancel?.refundedAmount, 500000);

    when(() => callable.call<Object?>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'not_eligible',
        code: 'failed-precondition',
        details: {'code': 'not_eligible', 'field': 'delivered'},
      ),
    );
    Object? errDelivered;
    try {
      await repoWithDb.cancelLateDelivery(bookingId: 'b1');
    } catch (e) {
      errDelivered = e;
    }
    expect(bookingErrorOf(errDelivered!), BookingErrorCode.alreadyDelivered);

    when(() => callable.call<Object?>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'not_eligible',
        code: 'failed-precondition',
        details: {'code': 'not_eligible'},
      ),
    );
    Object? errNotEligible;
    try {
      await repoWithDb.cancelLateDelivery(bookingId: 'b1');
    } catch (e) {
      errNotEligible = e;
    }
    expect(bookingErrorOf(errNotEligible!), BookingErrorCode.notEligible);

    when(() => callable.call<Object?>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'conflict',
        code: 'aborted',
        details: {'code': 'conflict'},
      ),
    );
    Object? errConflict;
    try {
      await repoWithDb.cancelLateDelivery(bookingId: 'b1');
    } catch (e) {
      errConflict = e;
    }
    expect(bookingErrorOf(errConflict!), BookingErrorCode.conflict);
  });
}
