import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/payments/payments_repository.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  late MockFirebaseFunctions functions;
  late MockHttpsCallable callable;
  late FunctionsPaymentsRepository repo;

  setUp(() {
    functions = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    repo = FunctionsPaymentsRepository(functions: functions);
  });

  void answer(Map<String, dynamic> data) {
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => result);
  }

  group('FunctionsPaymentsRepository', () {
    test('confirmFake sends {paymentId, kind: "wrong_content"} and returns outcome', () async {
      answer({'outcome': 'needs_review'});

      final outcome = await repo.confirmFake(
        'pay_1',
        kind: FakeTransferKind.wrongContent,
      );

      expect(outcome, 'needs_review');
      verify(() => functions.httpsCallable('confirmFakePayment')).called(1);
      verify(() => callable.call<Map<String, dynamic>>({
            'paymentId': 'pay_1',
            'kind': 'wrong_content',
          })).called(1);
    });

    test('confirmFake default kind is exact', () async {
      answer({'outcome': 'paid'});

      final outcome = await repo.confirmFake('pay_2');

      expect(outcome, 'paid');
      verify(() => callable.call<Map<String, dynamic>>({
            'paymentId': 'pay_2',
            'kind': 'exact',
          })).called(1);
    });

    test('instructions sends {paymentId} and parses instructions', () async {
      answer({
        'instructions': {
          'paymentId': 'pay_1',
          'method': 'bank_qr',
          'amount': 200000,
          'transferCode': 'PB 123456',
          'expiresAt': '2026-10-10T03:00:00.000Z',
        },
      });

      final ins = await repo.instructions('pay_1');

      expect(ins, isNotNull);
      expect(ins!.paymentId, 'pay_1');
      expect(ins.method, PayMethod.bankQr);
      expect(ins.amount, 200000);
      expect(ins.transferCode, 'PB 123456');
      expect(ins.expiresAt, DateTime.utc(2026, 10, 10, 3));
      verify(() => functions.httpsCallable('getPaymentInstructions')).called(1);
      verify(() => callable.call<Map<String, dynamic>>({
            'paymentId': 'pay_1',
          })).called(1);
    });

    test('instructions returns null when server answers null instructions', () async {
      answer({'instructions': null});

      final ins = await repo.instructions('pay_1');

      expect(ins, isNull);
    });

    test('error maps FirebaseFunctionsException details to BookingException', () async {
      when(() => callable.call<Map<String, dynamic>>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'Not found',
          code: 'not-found',
          details: {'code': 'not_found'},
        ),
      );

      expect(
        () => repo.instructions('pay_1'),
        throwsA(isA<BookingException>().having((e) => e.code, 'code', 'not_found')),
      );
    });
  });
}
