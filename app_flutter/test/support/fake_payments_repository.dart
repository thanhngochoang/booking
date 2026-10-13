import 'package:photobooking/data/booking/booking_repository.dart' show BookingException;
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/payments/payments_repository.dart';

class FakePaymentsRepository implements PaymentsRepository {
  final List<(String, FakeTransferKind)> confirms = [];
  final Map<String, PaymentInstructions?> instructionsById = {};
  Future<void> Function(String paymentId, FakeTransferKind kind)? onConfirm;
  Object? nextError;

  @override
  Future<String> confirmFake(
    String paymentId, {
    FakeTransferKind kind = FakeTransferKind.exact,
  }) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      if (err is String) throw BookingException(err);
      throw err;
    }
    confirms.add((paymentId, kind));
    if (onConfirm != null) {
      await onConfirm!(paymentId, kind);
    }
    return switch (kind) {
      FakeTransferKind.exact => 'paid',
      FakeTransferKind.under => 'partial',
      FakeTransferKind.over => 'paid_with_refund',
      FakeTransferKind.wrongContent => 'needs_review',
    };
  }

  @override
  Future<PaymentInstructions?> instructions(String paymentId) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      if (err is String) throw BookingException(err);
      throw err;
    }
    return instructionsById[paymentId];
  }
}
