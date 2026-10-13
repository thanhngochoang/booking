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

/// Route path for [subject].
String payPathOf(PaySubject s) => switch (s) {
  BookingPay(:final bookingId) => '/b/$bookingId/pay',
  TicketPay(:final eventId, :final registrationId) =>
    '/e/$eventId/pay/$registrationId',
};
