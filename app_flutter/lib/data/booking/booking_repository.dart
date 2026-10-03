import 'dart:io' show SocketException;

import 'package:photobooking/data/booking/booking.dart';

class BookingException implements Exception {
  const BookingException(this.code);
  final String code;

  @override
  String toString() => 'BookingException($code)';
}

enum BookingErrorCode {
  dayTaken,
  phoneRequired,
  priceChanged,
  notEligible,
  deadlinePassed,
  conflict,
  permissionDenied,
  notFound,
  invalidArgument,
  network,
  unknown,
}

BookingErrorCode bookingErrorOf(Object error) {
  if (error is SocketException) {
    return BookingErrorCode.network;
  }
  if (error is BookingException) {
    return _codeToBookingError(error.code);
  }
  final errType = error.runtimeType.toString();
  if (errType.contains('FunctionsException')) {
    dynamic dyn = error;
    try {
      final code = dyn.code;
      if (code == 'unavailable' || code == 'deadline-exceeded') {
        return BookingErrorCode.network;
      }
      final details = dyn.details;
      if (details is Map && details['code'] is String) {
        return _codeToBookingError(details['code'] as String);
      }
      if (dyn.message is String) {
        return _codeToBookingError(dyn.message as String);
      }
    } catch (_) {}
  }
  return BookingErrorCode.unknown;
}

BookingErrorCode _codeToBookingError(String code) {
  switch (code) {
    case 'day_taken':
      return BookingErrorCode.dayTaken;
    case 'phone_required':
      return BookingErrorCode.phoneRequired;
    case 'price_changed':
      return BookingErrorCode.priceChanged;
    case 'not_eligible':
      return BookingErrorCode.notEligible;
    case 'deadline_passed':
      return BookingErrorCode.deadlinePassed;
    case 'conflict':
      return BookingErrorCode.conflict;
    case 'permission_denied':
    case 'permission-denied':
      return BookingErrorCode.permissionDenied;
    case 'not_found':
    case 'not-found':
      return BookingErrorCode.notFound;
    case 'invalid_argument':
    case 'invalid-argument':
      return BookingErrorCode.invalidArgument;
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network':
      return BookingErrorCode.network;
    default:
      return BookingErrorCode.unknown;
  }
}

class CreateDepositResponse {
  const CreateDepositResponse({
    required this.paymentId,
    required this.payUrl,
    required this.provider,
  });

  final String paymentId;
  final String payUrl;
  final String provider;
}

class ConfirmPaymentResponse {
  const ConfirmPaymentResponse({
    required this.paymentId,
    required this.status,
    this.booking,
  });

  final String paymentId;
  final String status;
  final Booking? booking;
}

class CheckDepositResponse {
  const CheckDepositResponse({required this.paid, this.booking});

  final bool paid;
  final Booking? booking;
}

abstract class BookingRepository {
  /// Watches a single booking by id.
  Stream<Booking?> watchBooking(String id);

  /// Gets a single booking by id.
  Future<Booking?> getBooking(String id);

  /// Watches customer's bookings (party = customer).
  Stream<List<Booking>> watchCustomerBookings(String customerId);

  /// Watches photographer's bookings (party = photographer).
  Stream<List<Booking>> watchPhotographerBookings(String photographerId);

  /// Watches the private contact snapshot for a booking.
  Stream<BookingContactSnapshot?> watchBookingContact(String bookingId);

  /// Creates a draft booking.
  Future<Booking> createBooking({
    required String photographerId,
    required String serviceId,
    required String day,
    required String start,
    required BookingPlace place,
    String? note,
    int? expectedPrice,
  });

  /// Initiates deposit payment intent.
  Future<CreateDepositResponse> createDeposit({
    required String bookingId,
    required String provider,
    String? returnUrl,
  });

  /// Confirms fake payment (dev/test).
  Future<ConfirmPaymentResponse> confirmFakePayment({
    required String paymentId,
  });

  /// Checks deposit status.
  Future<CheckDepositResponse> checkDeposit({required String bookingId});

  /// Transitions booking lifecycle state.
  Future<Booking> transitionBooking({
    required String bookingId,
    required String action,
    String? reason,
  });

  /// Opens dispute on completed/upcoming booking.
  Future<Booking> openDispute({
    required String bookingId,
    required String reason,
  });
}
