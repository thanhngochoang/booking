import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';

class FirestoreBookingRepository implements BookingRepository {
  FirestoreBookingRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _customFunctions = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions? _customFunctions;

  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  CollectionReference<Map<String, dynamic>> get _bookingsCol =>
      _db.collection('bookings');

  @override
  Stream<Booking?> watchBooking(String id) {
    return _bookingsCol.doc(id).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return bookingFromFirestore(snap.id, data);
    });
  }

  @override
  Future<Booking?> getBooking(String id) async {
    final snap = await _bookingsCol.doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    return bookingFromFirestore(snap.id, data);
  }

  @override
  Stream<List<Booking>> watchCustomerBookings(String customerId) {
    return _bookingsCol
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map(
          (qs) => qs.docs
              .map((d) => bookingFromFirestore(d.id, d.data()))
              .whereType<Booking>()
              .where((b) => b.status != BookingStatus.draft)
              .toList(),
        );
  }

  @override
  Stream<List<Booking>> watchPhotographerBookings(String photographerId) {
    return _bookingsCol
        .where('photographerId', isEqualTo: photographerId)
        .snapshots()
        .map(
          (qs) => qs.docs
              .map((d) => bookingFromFirestore(d.id, d.data()))
              .whereType<Booking>()
              .where((b) => b.status != BookingStatus.draft)
              .toList(),
        );
  }

  @override
  Stream<BookingContactSnapshot?> watchBookingContact(String bookingId) {
    return _bookingsCol
        .doc(bookingId)
        .collection('private')
        .doc('contact')
        .snapshots()
        .map((snap) => bookingContactFromFirestore(snap.data()));
  }

  @override
  Stream<List<BookingEventRecord>> watchEvents(String bookingId) {
    return _bookingsCol
        .doc(bookingId)
        .collection('events')
        .orderBy('at')
        .snapshots()
        .map(
          (qs) => qs.docs
              .map((d) => bookingEventRecordFromFirestore(d.id, bookingId, d.data()))
              .whereType<BookingEventRecord>()
              .toList(),
        );
  }

  Future<T> _call<T>(
    String name,
    Map<String, dynamic> data,
    T Function(dynamic) parse,
  ) async {
    try {
      final res = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>(data);
      return parse(res.data);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : e.message ?? e.code;
      throw BookingException(code);
    }
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
    return _call(
      'createBooking',
      {
        'photographerId': photographerId,
        'serviceId': serviceId,
        'day': day,
        'start': start,
        'place': {
          'name': place.name,
          if (place.lat != null && place.lng != null)
            'point': {'lat': place.lat, 'lng': place.lng},
        },
        'note': ?note,
        'expectedPrice': ?expectedPrice,
      },
      (raw) {
        final map = (raw as Map).cast<String, dynamic>();
        final booking = bookingFromFirestore(map['id'] as String, map);
        if (booking == null) throw const BookingException('invalid_response');
        return booking;
      },
    );
  }

  @override
  Future<CreateDepositResponse> createDeposit({
    required String bookingId,
    required String provider,
    String? returnUrl,
  }) async {
    return _call(
      'createDeposit',
      {
        'bookingId': bookingId,
        'provider': provider,
        'returnUrl': ?returnUrl,
      },
      (raw) {
        final map = (raw as Map).cast<String, dynamic>();
        return CreateDepositResponse(
          paymentId: map['paymentId'] as String,
          payUrl: map['payUrl'] as String,
          provider: map['provider'] as String,
        );
      },
    );
  }

  @override
  Future<ConfirmPaymentResponse> confirmFakePayment({
    required String paymentId,
  }) async {
    return _call('confirmFakePayment', {'paymentId': paymentId}, (raw) {
      final map = (raw as Map).cast<String, dynamic>();
      final payMap = (map['payment'] as Map).cast<String, dynamic>();
      final bookingMap = map['booking'] != null
          ? (map['booking'] as Map).cast<String, dynamic>()
          : null;
      return ConfirmPaymentResponse(
        paymentId: payMap['id'] as String,
        status: payMap['status'] as String,
        booking: bookingMap != null
            ? bookingFromFirestore(bookingMap['id'] as String, bookingMap)
            : null,
      );
    });
  }

  @override
  Future<CheckDepositResponse> checkDeposit({required String bookingId}) async {
    return _call('checkDeposit', {'bookingId': bookingId}, (raw) {
      final map = (raw as Map).cast<String, dynamic>();
      final bookingMap = map['booking'] != null
          ? (map['booking'] as Map).cast<String, dynamic>()
          : null;
      return CheckDepositResponse(
        paid: map['paid'] as bool,
        booking: bookingMap != null
            ? bookingFromFirestore(bookingMap['id'] as String, bookingMap)
            : null,
      );
    });
  }

  @override
  Future<Booking> transitionBooking({
    required String bookingId,
    required String action,
    String? reason,
  }) async {
    return _call(
      'transitionBooking',
      {
        'bookingId': bookingId,
        'action': action,
        'reason': ?reason,
      },
      (raw) {
        final map = (raw as Map).cast<String, dynamic>();
        final booking = bookingFromFirestore(map['id'] as String, map);
        if (booking == null) throw const BookingException('invalid_response');
        return booking;
      },
    );
  }

  @override
  Future<Booking> openDispute({
    required String bookingId,
    required String reason,
  }) async {
    return _call('openDispute', {'bookingId': bookingId, 'reason': reason}, (
      raw,
    ) {
      final map = (raw as Map).cast<String, dynamic>();
      final booking = bookingFromFirestore(map['id'] as String, map);
      if (booking == null) throw const BookingException('invalid_response');
      return booking;
    });
  }
}
