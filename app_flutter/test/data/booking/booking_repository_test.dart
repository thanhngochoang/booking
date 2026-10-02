import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_booking_repository.dart';

void main() {
  group('FakeBookingRepository', () {
    late FakeBookingRepository repo;

    setUp(() {
      repo = FakeBookingRepository(customerId: 'c1');
    });

    test('createBooking creates draft booking and emits on watch', () async {
      final b = await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-20',
        start: '09:00',
        place: const BookingPlace(name: 'Hà Nội'),
      );

      expect(b.status, BookingStatus.draft);
      expect(b.customerId, 'c1');
      expect(b.photographerId, 'p1');

      final loaded = await repo.getBooking(b.id);
      expect(loaded, isNotNull);
      expect(loaded?.id, b.id);
    });

    test('deposit payment flow moves draft to requested', () async {
      final draft = await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-20',
        start: '09:00',
        place: const BookingPlace(name: 'Hà Nội'),
      );

      final dep = await repo.createDeposit(
        bookingId: draft.id,
        provider: 'fake',
      );
      expect(dep.paymentId, 'pay_${draft.id}');

      final conf = await repo.confirmFakePayment(paymentId: dep.paymentId);
      expect(conf.booking?.status, BookingStatus.requested);
      expect(conf.booking?.escrowStatus, EscrowStatus.held);

      final check = await repo.checkDeposit(bookingId: draft.id);
      expect(check.paid, true);
    });

    test('lifecycle transitions update status', () async {
      final b = makeTestBooking(id: 'b1', status: BookingStatus.requested);
      repo.seedBooking(b);

      final accepted = await repo.transitionBooking(
        bookingId: 'b1',
        action: 'accept',
      );
      expect(accepted.status, BookingStatus.accepted);

      final completed = await repo.transitionBooking(
        bookingId: 'b1',
        action: 'complete',
      );
      expect(completed.status, BookingStatus.completed);
      expect(completed.completedAt, isNotNull);
    });

    test('dispute updates escrowStatus to disputed', () async {
      final b = makeTestBooking(id: 'b1', status: BookingStatus.completed);
      repo.seedBooking(b);

      final disputed = await repo.openDispute(
        bookingId: 'b1',
        reason: 'Chất lượng không tốt',
      );
      expect(disputed.escrowStatus, EscrowStatus.disputed);
    });

    test('watchCustomerBookings filters out drafts', () async {
      final b1 = makeTestBooking(id: 'b1', status: BookingStatus.requested);
      final b2 = makeTestBooking(id: 'b2', status: BookingStatus.draft);
      repo.seedBooking(b1);
      repo.seedBooking(b2);

      final list = await repo.watchCustomerBookings('c1').first;
      expect(list.length, 1);
      expect(list.first.id, 'b1');
    });
  });

  group('bookingFromFirestore mapper', () {
    test('maps valid Firestore document correctly', () {
      final docData = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {
          'name': 'Gói chụp chân dung',
          'price': 1500000,
          'durationMinutes': 120,
        },
        'day': '2026-10-20',
        'start': '08:00',
        'end': '10:00',
        'place': {
          'name': 'Hồ Gươm',
          'point': const GeoPoint(21.0285, 105.8542),
        },
        'note': 'Chụp sáng sớm',
        'status': 'accepted',
        'deposit': 450000,
        'remaining': 1050000,
        'escrowStatus': 'held',
        'depositProvider': 'fake',
        'depositPaidAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 8, 0)),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 7, 0)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 8, 0)),
      };

      final b = bookingFromFirestore('b_fs_1', docData);
      expect(b, isNotNull);
      expect(b?.id, 'b_fs_1');
      expect(b?.customerId, 'c1');
      expect(b?.status, BookingStatus.accepted);
      expect(b?.deposit, 450000);
      expect(b?.remaining, 1050000);
      expect(b?.place.lat, 21.0285);
      expect(b?.place.lng, 105.8542);
      expect(b?.escrowStatus, EscrowStatus.held);
    });

    test('returns null for missing required fields', () {
      expect(bookingFromFirestore('b_bad', {}), isNull);
      expect(bookingFromFirestore('b_bad', {'customerId': 'c1'}), isNull);
    });
  });
}
