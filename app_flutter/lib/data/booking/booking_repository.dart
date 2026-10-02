import 'package:photobooking/data/booking/booking.dart';

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
