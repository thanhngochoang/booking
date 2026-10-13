import 'dart:io' show SocketException;

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/payments/payments_repository.dart';

export 'package:photobooking/data/payments/payments_repository.dart'
    show FakeTransferKind;

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
  notAcceptingOrders,
  blocked,
  deadlinePassed,
  conflict,
  permissionDenied,
  notFound,
  invalidArgument,
  paymentAttemptsExceeded,
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
    case 'not_accepting_orders':
      return BookingErrorCode.notAcceptingOrders;
    case 'blocked':
      return BookingErrorCode.blocked;
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
    case 'payment_attempts_exceeded':
      return BookingErrorCode.paymentAttemptsExceeded;
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network':
      return BookingErrorCode.network;
    default:
      return BookingErrorCode.unknown;
  }
}

/// Answer of `checkPayment`: whether the booking is paid and its current state.
class CheckPaymentResponse {
  const CheckPaymentResponse({required this.paid, this.booking});

  final bool paid;
  final Booking? booking;
}

enum BookingRole { customer, photographer }

enum BookingAction {
  accept,
  decline,
  cancel,
  complete;

  String get code => name;
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

  /// Watches bookings a studio assigned to [uid] (`assigneeId == uid`),
  /// drafts dropped. The studio stays the booking's `photographerId`.
  Stream<List<Booking>> watchAssignedBookings(String uid);

  /// Watches the private contact snapshot for a booking.
  Stream<BookingContactSnapshot?> watchBookingContact(String bookingId);

  /// `bookings/{id}/events`, oldest first (4a writes them; the read rule is added in Task 1).
  Stream<List<BookingEventRecord>> watchEvents(String bookingId);

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

  /// Starts (or restarts, "Tạo QR mới") the payment of a draft booking. The
  /// booking's `checkout` mirrors the answer. At most 3 per booking, then
  /// [BookingErrorCode.paymentAttemptsExceeded].
  Future<BookingCheckout> createPayment({
    required String bookingId,
    required PayMethod method,
  });

  /// Asks the server to check the current payment with the provider
  /// ("Kiểm tra lại"); never creates one.
  Future<CheckPaymentResponse> checkPayment({required String bookingId});

  /// Simulates a bank transfer to [paymentId] (dev/test only, refused by the
  /// server elsewhere) and returns the outcome code (`paid`, `partial`,
  /// `paid_with_refund`, `needs_review`, ...).
  Future<String> confirmFakePayment({
    required String paymentId,
    FakeTransferKind kind = FakeTransferKind.exact,
  });

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
