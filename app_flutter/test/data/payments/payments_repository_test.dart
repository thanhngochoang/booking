import 'dart:io' show SocketException;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payments_repository.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T> {}

void main() {
  late MockFirebaseFunctions functions;
  late MockHttpsCallable callable;
  late FirebasePaymentsRepository repo;

  setUp(() {
    functions = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    repo = FirebasePaymentsRepository(functions: functions);
  });

  void answer(Map<String, dynamic> data) {
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => result);
  }

  /// The S22.04 callables are read as `Object?` (pendingRefund answers null).
  void answerAny(Object? data) {
    final result = MockHttpsCallableResult<Object?>();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
  }

  group('FirebasePaymentsRepository', () {
    test('confirmFake sends {paymentId, kind: "wrong_content"} and returns outcome', () async {
      answer({'outcome': 'needs_review'});

      final outcome = await repo.confirmFake(
        'pay_1',
        kind: FakeTransferKind.wrongContent,
      );

      expect(outcome, 'needs_review');
      verify(() => functions.httpsCallable('confirmFakePayment')).called(1);
      verify(
        () => callable.call<Map<String, dynamic>>({
          'paymentId': 'pay_1',
          'kind': 'wrong_content',
        }),
      ).called(1);
    });

    test('confirmFake default kind is exact', () async {
      answer({'outcome': 'paid'});

      final outcome = await repo.confirmFake('pay_2');

      expect(outcome, 'paid');
      verify(
        () => callable.call<Map<String, dynamic>>({
          'paymentId': 'pay_2',
          'kind': 'exact',
        }),
      ).called(1);
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
      verify(() => callable.call<Map<String, dynamic>>({'paymentId': 'pay_1'}))
          .called(1);
    });

    test(
      'instructions returns null when server answers null instructions',
      () async {
        answer({'instructions': null});

        final ins = await repo.instructions('pay_1');

        expect(ins, isNull);
      },
    );

    test(
      'error maps FirebaseFunctionsException details to BookingException',
      () async {
        when(() => callable.call<Map<String, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(
            message: 'Not found',
            code: 'not-found',
            details: {'code': 'not_found'},
          ),
        );

        expect(
          () => repo.instructions('pay_1'),
          throwsA(
            isA<BookingException>().having((e) => e.code, 'code', 'not_found'),
          ),
        );
      },
    );

    test(
      'BookingRefund and TicketRefund send their ids to pendingRefund',
      () async {
        answerAny(null);

        expect(await repo.pendingRefund(const BookingRefund('b1')), isNull);
        await repo.pendingRefund(const TicketRefund('e1', 'reg1'));

        verify(() => functions.httpsCallable('pendingRefund')).called(2);
        verify(() => callable.call<Object?>({'bookingId': 'b1'})).called(1);
        verify(
          () => callable.call<Object?>({
            'eventId': 'e1',
            'registrationId': 'reg1',
          }),
        ).called(1);
      },
    );

    test('DisputeRefund sends {disputeId} to pendingRefund', () async {
      answerAny(<Object?, Object?>{
        'refundId': 'r1',
        'amount': 500000,
        'payer': <Object?, Object?>{
          'bankName': 'Vietcombank',
          'accountLast4': '6789',
          'holderName': 'NGUYEN THANH HA',
        },
        'confirmBy': '2026-10-11T03:00:00.000Z',
      });

      final p = await repo.pendingRefund(const DisputeRefund('d1'));

      expect(p?.refundId, 'r1');
      expect(p?.payer?.accountLast4, '6789');
      verify(() => functions.httpsCallable('pendingRefund')).called(1);
      verify(() => callable.call<Object?>({'disputeId': 'd1'})).called(1);
    });

    test('lookupRefundAccount sends {refundId, bankCode, accountNumber} and reads the masked answer', () async {
      answerAny(<Object?, Object?>{
        'holderName': 'TRAN VAN B',
        'bankName': 'Techcombank',
        'accountLast4': '4321',
      });

      final r = await repo.lookupRefundAccount(
        refundId: 'r1',
        bankCode: 'TCB',
        accountNumber: '190000004321',
      );

      expect(r.holderName, 'TRAN VAN B');
      expect(r.bankName, 'Techcombank');
      expect(r.accountLast4, '4321');
      verify(() => functions.httpsCallable('lookupRefundAccount')).called(1);
      verify(
        () => callable.call<Object?>({
          'refundId': 'r1',
          'bankCode': 'TCB',
          'accountNumber': '190000004321',
        }),
      ).called(1);
    });

    test(
      'chooseRefundAccount sends {refundId, use} and returns the status',
      () async {
        answerAny(<Object?, Object?>{'status': 'pending'});

        final status = await repo.chooseRefundAccount(
          refundId: 'r1',
          use: RefundAccountChoice.candidate,
        );

        expect(status, 'pending');
        verify(() => functions.httpsCallable('chooseRefundAccount')).called(1);
        verify(
          () => callable.call<Object?>({'refundId': 'r1', 'use': 'candidate'}),
        ).called(1);
      },
    );

    Matcher code(String c) =>
        throwsA(isA<BookingException>().having((e) => e.code, 'code', c));

    test('network failures read "network"', () async {
      when(
        () => callable.call<Object?>(any()),
      ).thenThrow(const SocketException('no route'));
      await expectLater(
        repo.pendingRefund(const BookingRefund('b1')),
        code('network'),
      );

      for (final transport in ['unavailable', 'deadline-exceeded']) {
        when(() => callable.call<Object?>(any())).thenThrow(
          FirebaseFunctionsException(message: transport, code: transport),
        );
        await expectLater(
          repo.pendingRefund(const BookingRefund('b1')),
          code('network'),
        );
      }
    });

    test('a refusal without details.code reads its transport code in snake_case', () async {
      const cases = {
        'not-found': 'not_found',
        'permission-denied': 'permission_denied',
        'unauthenticated': 'permission_denied',
        'invalid-argument': 'invalid_argument',
        'resource-exhausted': 'limit_exceeded',
        'aborted': 'conflict',
        'failed-precondition': 'failed_precondition',
      };
      for (final e in cases.entries) {
        when(() => callable.call<Object?>(any())).thenThrow(
          FirebaseFunctionsException(message: 'refused', code: e.key),
        );
        await expectLater(
          repo.chooseRefundAccount(
            refundId: 'r1',
            use: RefundAccountChoice.payer,
          ),
          code(e.value),
          reason: e.key,
        );
      }
    });

    test('any other failure is rethrown as it is, with its stack trace', () async {
      final boom = StateError('bug');
      when(() => callable.call<Object?>(any())).thenThrow(boom);
      await expectLater(
        repo.pendingRefund(const DisputeRefund('d1')),
        throwsA(same(boom)),
      );
    });

    test('a malformed lookup or choose answer reads "unknown"', () async {
      answerAny(<Object?, Object?>{'holderName': 'TRAN VAN B'});
      await expectLater(
        repo.lookupRefundAccount(
          refundId: 'r1',
          bankCode: 'TCB',
          accountNumber: '190000004321',
        ),
        code('unknown'),
      );

      answerAny(null);
      await expectLater(
        repo.chooseRefundAccount(
          refundId: 'r1',
          use: RefundAccountChoice.payer,
        ),
        code('unknown'),
      );
      answerAny(<Object?, Object?>{'status': 3});
      await expectLater(
        repo.chooseRefundAccount(
          refundId: 'r1',
          use: RefundAccountChoice.payer,
        ),
        code('unknown'),
      );
    });

    test('the lookup cap and an unsupported bank keep their codes', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'limit_exceeded',
          code: 'resource-exhausted',
          details: {'code': 'limit_exceeded'},
        ),
      );
      await expectLater(
        repo.lookupRefundAccount(
          refundId: 'r1',
          bankCode: 'TCB',
          accountNumber: '1',
        ),
        throwsA(
          isA<BookingException>().having(
            (e) => e.code,
            'code',
            'limit_exceeded',
          ),
        ),
      );

      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'not_eligible',
          code: 'failed-precondition',
          details: {'code': 'not_eligible'},
        ),
      );
      await expectLater(
        repo.lookupRefundAccount(
          refundId: 'r1',
          bankCode: 'TCB',
          accountNumber: '1',
        ),
        throwsA(
          isA<BookingException>().having((e) => e.code, 'code', 'not_eligible'),
        ),
      );
    });
  });
}
