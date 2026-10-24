// lib/features/payments/payment_history_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/payments/payment_history.dart';

/// Rows asked from the server; "Xem thêm" adds one more page (Decision 1).
const int paymentsPageSize = 20;

class PaymentsLimit extends Notifier<int> {
  @override
  int build() => paymentsPageSize;

  void more() => state += paymentsPageSize;
}

final paymentsLimitProvider = NotifierProvider.autoDispose<PaymentsLimit, int>(
  PaymentsLimit.new,
);

/// The S22.04 subject of a row waiting for the customer's refund account: a
/// booking or a ticket. Chụp ngay and the S21 fee never wait for an account
/// (the server lists them as `refunding`), so they have none.
RefundSubject? refundSubjectOf(PayerPaymentRow row) {
  if (row.status != PayerRowStatus.refundAccountNeeded) return null;
  if (row.subjectId.isEmpty) return null;
  return switch (row.subjectType) {
    PayerSubjectType.booking => BookingRefund(row.subjectId),
    PayerSubjectType.eventRegistration when row.eventId != null => TicketRefund(
      row.eventId!,
      row.subjectId,
    ),
    _ => null,
  };
}
