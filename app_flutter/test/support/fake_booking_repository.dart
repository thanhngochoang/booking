import 'dart:async';

import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';

class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({this.customerId = 'c1'});

  final String customerId;
  final Map<String, Booking> bookings = {};
  final Map<String, BookingContactSnapshot> contacts = {};
  final Map<String, List<BookingEventRecord>> events = {};

  final _bookingChanges = StreamController<String>.broadcast();
  final _contactChanges = StreamController<String>.broadcast();
  final _eventChanges = StreamController<String>.broadcast();

  BookingErrorCode? nextError;
  final createCalls =
      <
        ({
          String photographerId,
          String serviceId,
          String day,
          String start,
          String placeName,
          String? note,
          int? expectedPrice,
        })
      >[];
  final depositCalls = <({String bookingId, String provider})>[];
  final fakeConfirms = <String>[];
  final checkCalls = <String>[];

  void remove(String id) {
    bookings.remove(id);
    _bookingChanges.add(id);
  }

  void _checkNextError() {
    final err = nextError;
    if (err != null) {
      nextError = null;
      throw BookingException(_serverCodeFor(err));
    }
  }

  static String _serverCodeFor(BookingErrorCode err) {
    return switch (err) {
      BookingErrorCode.dayTaken => 'day_taken',
      BookingErrorCode.phoneRequired => 'phone_required',
      BookingErrorCode.priceChanged => 'price_changed',
      BookingErrorCode.notEligible => 'not_eligible',
      BookingErrorCode.deadlinePassed => 'deadline_passed',
      BookingErrorCode.conflict => 'conflict',
      BookingErrorCode.permissionDenied => 'permission_denied',
      BookingErrorCode.notFound => 'not_found',
      BookingErrorCode.invalidArgument => 'invalid_argument',
      BookingErrorCode.network => 'unavailable',
      BookingErrorCode.unknown => 'unknown',
    };
  }

  void seedBooking(Booking booking) {
    bookings[booking.id] = booking;
    _bookingChanges.add(booking.id);
  }

  void seedContact(String bookingId, BookingContactSnapshot contact) {
    contacts[bookingId] = contact;
    _contactChanges.add(bookingId);
  }

  void seedEvents(String bookingId, List<BookingEventRecord> list) {
    events[bookingId] = List.of(list);
    _eventChanges.add(bookingId);
  }

  void addEvent(BookingEventRecord event) {
    final list = events.putIfAbsent(event.bookingId, () => []);
    list.add(event);
    _eventChanges.add(event.bookingId);
  }

  @override
  Stream<Booking?> watchBooking(String id) {
    return _bookingChanges.stream
        .where((changedId) => changedId == id)
        .map((_) => bookings[id])
        .startWith(bookings[id]);
  }

  @override
  Future<Booking?> getBooking(String id) async {
    return bookings[id];
  }

  @override
  Stream<List<Booking>> watchCustomerBookings(String customerId) {
    List<Booking> list() => bookings.values
        .where(
          (b) => b.customerId == customerId && b.status != BookingStatus.draft,
        )
        .toList();

    return _bookingChanges.stream.map((_) => list()).startWith(list());
  }

  @override
  Stream<List<Booking>> watchPhotographerBookings(String photographerId) {
    List<Booking> list() => bookings.values
        .where(
          (b) =>
              b.photographerId == photographerId &&
              b.status != BookingStatus.draft,
        )
        .toList();

    return _bookingChanges.stream.map((_) => list()).startWith(list());
  }

  @override
  Stream<BookingContactSnapshot?> watchBookingContact(String bookingId) {
    return _contactChanges.stream
        .where((changedId) => changedId == bookingId)
        .map((_) => contacts[bookingId])
        .startWith(contacts[bookingId]);
  }

  @override
  Stream<List<BookingEventRecord>> watchEvents(String bookingId) {
    List<BookingEventRecord> list() =>
        List.unmodifiable(events[bookingId] ?? const []);
    return _eventChanges.stream
        .where((id) => id == bookingId)
        .map((_) => list())
        .startWith(list());
  }

  @override
  Future<Booking> createBooking({
    required String photographerId,
    required String serviceId,
    required String day,
    required String start,
    required BookingPlace place,
    String? note,
    int? expectedPrice,
  }) async {
    _checkNextError();
    createCalls.add((
      photographerId: photographerId,
      serviceId: serviceId,
      day: day,
      start: start,
      placeName: place.name,
      note: note,
      expectedPrice: expectedPrice,
    ));
    final id = 'booking_${bookings.length + 1}';
    final now = DateTime.now().toUtc();
    final booking = Booking(
      id: id,
      customerId: customerId,
      photographerId: photographerId,
      serviceId: serviceId,
      serviceSnapshot: const BookingServiceSnapshot(
        name: 'Gói chụp',
        price: 1000000,
        durationMinutes: 120,
      ),
      day: day,
      start: start,
      end: '11:00',
      place: place,
      note: note,
      status: BookingStatus.draft,
      deposit: 300000,
      remaining: 700000,
      createdAt: now,
      updatedAt: now,
    );
    bookings[id] = booking;
    _bookingChanges.add(id);
    return booking;
  }

  @override
  Future<CreateDepositResponse> createDeposit({
    required String bookingId,
    required String provider,
    String? returnUrl,
  }) async {
    _checkNextError();
    depositCalls.add((bookingId: bookingId, provider: provider));
    return CreateDepositResponse(
      paymentId: 'pay_$bookingId',
      payUrl: 'https://fake-pay.test/$bookingId',
      provider: provider,
    );
  }

  @override
  Future<ConfirmPaymentResponse> confirmFakePayment({
    required String paymentId,
  }) async {
    _checkNextError();
    fakeConfirms.add(paymentId);
    final bookingId = paymentId.replaceFirst('pay_', '');
    final b = bookings[bookingId];
    if (b != null) {
      final updated = b.copyWith(
        status: BookingStatus.requested,
        escrowStatus: EscrowStatus.held,
        depositPaidAt: DateTime.now().toUtc(),
      );
      bookings[bookingId] = updated;
      _bookingChanges.add(bookingId);
      return ConfirmPaymentResponse(
        paymentId: paymentId,
        status: 'paid',
        booking: updated,
      );
    }
    return ConfirmPaymentResponse(paymentId: paymentId, status: 'paid');
  }

  @override
  Future<CheckDepositResponse> checkDeposit({required String bookingId}) async {
    _checkNextError();
    checkCalls.add(bookingId);
    final b = bookings[bookingId];
    return CheckDepositResponse(
      paid: b?.status != BookingStatus.draft,
      booking: b,
    );
  }

  @override
  Future<Booking> transitionBooking({
    required String bookingId,
    required String action,
    String? reason,
  }) async {
    _checkNextError();
    final b = bookings[bookingId];
    if (b == null) throw StateError('Booking not found');

    BookingStatus nextStatus;
    switch (action) {
      case 'accept':
        nextStatus = BookingStatus.accepted;
        break;
      case 'decline':
        nextStatus = BookingStatus.declined;
        break;
      case 'cancel':
        nextStatus = BookingStatus.cancelled;
        break;
      case 'upcoming':
        nextStatus = BookingStatus.upcoming;
        break;
      case 'complete':
        nextStatus = BookingStatus.completed;
        break;
      default:
        nextStatus = b.status;
    }

    final updated = b.copyWith(
      status: nextStatus,
      completedAt: nextStatus == BookingStatus.completed
          ? DateTime.now().toUtc()
          : b.completedAt,
      updatedAt: DateTime.now().toUtc(),
    );
    bookings[bookingId] = updated;
    _bookingChanges.add(bookingId);
    return updated;
  }

  @override
  Future<Booking> openDispute({
    required String bookingId,
    required String reason,
  }) async {
    _checkNextError();
    final b = bookings[bookingId];
    if (b == null) throw StateError('Booking not found');

    final updated = b.copyWith(
      escrowStatus: EscrowStatus.disputed,
      updatedAt: DateTime.now().toUtc(),
    );
    bookings[bookingId] = updated;
    _bookingChanges.add(bookingId);
    return updated;
  }
}

extension _StreamStartWith<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}

