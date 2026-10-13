import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/booking/booking_repository.dart' show BookingException;
import 'package:photobooking/data/payments/payment_instructions.dart';

/// Simulated transfer kind for fake gateway testing (emulator/dev only).
enum FakeTransferKind {
  exact('exact'),
  under('under'),
  over('over'),
  wrongContent('wrong_content');

  const FakeTransferKind(this.code);

  /// Wire code of the callable's `kind`.
  final String code;
}

class PaymentCheck {
  const PaymentCheck({required this.paid, this.instructions});

  final bool paid;
  final PaymentInstructions? instructions;
}

abstract class PaymentsRepository {
  /// confirmFakePayment {paymentId, kind}: returns the outcome code
  /// ('paid', 'partial', 'paid_with_refund', 'needs_review', …).
  Future<String> confirmFake(
    String paymentId, {
    FakeTransferKind kind = FakeTransferKind.exact,
  });

  /// getPaymentInstructions {paymentId}; null when the payment is no longer open.
  Future<PaymentInstructions?> instructions(String paymentId);
}

class FunctionsPaymentsRepository implements PaymentsRepository {
  FunctionsPaymentsRepository({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  @override
  Future<String> confirmFake(
    String paymentId, {
    FakeTransferKind kind = FakeTransferKind.exact,
  }) async {
    try {
      final callable = _functions.httpsCallable('confirmFakePayment');
      final res = await callable.call<Map<String, dynamic>>({
        'paymentId': paymentId,
        'kind': kind.code,
      });
      final outcome = res.data['outcome'];
      if (outcome is String) return outcome;
      return 'needs_review';
    } on FirebaseFunctionsException catch (e) {
      final code = (e.details is Map && (e.details as Map)['code'] is String)
          ? (e.details as Map)['code'] as String
          : e.code;
      throw BookingException(code);
    }
  }

  @override
  Future<PaymentInstructions?> instructions(String paymentId) async {
    try {
      final callable = _functions.httpsCallable('getPaymentInstructions');
      final res = await callable.call<Map<String, dynamic>>({
        'paymentId': paymentId,
      });
      final raw = res.data['instructions'];
      return paymentInstructionsFrom(raw);
    } on FirebaseFunctionsException catch (e) {
      final code = (e.details is Map && (e.details as Map)['code'] is String)
          ? (e.details as Map)['code'] as String
          : e.code;
      throw BookingException(code);
    }
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => FunctionsPaymentsRepository(),
);
