// lib/features/payment/pay_subject.dart
import 'package:flutter/foundation.dart';

/// The subject of a payment in PhotoBooking.
sealed class PaySubject {
  const PaySubject();
}

/// A draft booking payment.
@immutable
final class BookingPay extends PaySubject {
  const BookingPay(this.bookingId);

  final String bookingId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingPay &&
          runtimeType == other.runtimeType &&
          bookingId == other.bookingId;

  @override
  int get hashCode => bookingId.hashCode;
}

/// A held event ticket registration payment.
@immutable
final class TicketPay extends PaySubject {
  const TicketPay(this.eventId, this.registrationId);

  final String eventId;
  final String registrationId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicketPay &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId &&
          registrationId == other.registrationId;

  @override
  int get hashCode => Object.hash(eventId, registrationId);
}

/// The signed-in provider's verification fee (S21.02-fee, #203); the
/// payment belongs to the caller, so the subject carries no id.
@immutable
final class VerificationFeePay extends PaySubject {
  const VerificationFeePay();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VerificationFeePay;

  @override
  int get hashCode => (VerificationFeePay).hashCode;
}

/// A Chụp ngay request's first-round payment (#202): S04.04 for the request
/// waiting in `pending_payment`.
@immutable
final class InstantPay extends PaySubject {
  const InstantPay(this.requestId);

  final String requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstantPay &&
          runtimeType == other.runtimeType &&
          requestId == other.requestId;

  @override
  int get hashCode => requestId.hashCode;
}

/// Route path for [subject].
String payPathOf(PaySubject s) => switch (s) {
  BookingPay(:final bookingId) => '/b/$bookingId/pay',
  TicketPay(:final eventId, :final registrationId) =>
    '/e/$eventId/pay/$registrationId',
  VerificationFeePay() => '/verify/start/fee/pay',
  InstantPay(:final requestId) => '/instant/$requestId/pay',
};
