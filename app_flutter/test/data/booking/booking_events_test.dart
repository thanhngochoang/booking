import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/firestore_booking_repository.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_booking_repository.dart';

void main() {
  group('Booking events & providers (Plan 4c Task 1)', () {
    test('watchEvents maps bookings/{id}/events oldest first', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreBookingRepository(firestore: firestore);

      final t1 = DateTime.utc(2026, 10, 1, 10, 0);
      final t2 = DateTime.utc(2026, 10, 1, 11, 0);
      final t3 = DateTime.utc(2026, 10, 1, 12, 0);

      // Add events in non-chronological order
      await firestore
          .collection('bookings')
          .doc('b1')
          .collection('events')
          .doc('ev2')
          .set({
        'status': 'accepted',
        'at': Timestamp.fromDate(t2),
        'actorId': 'p1',
      });
      await firestore
          .collection('bookings')
          .doc('b1')
          .collection('events')
          .doc('ev1')
          .set({
        'status': 'requested',
        'at': Timestamp.fromDate(t1),
        'actorId': 'c1',
      });
      await firestore
          .collection('bookings')
          .doc('b1')
          .collection('events')
          .doc('ev3')
          .set({
        'status': 'completed',
        'at': Timestamp.fromDate(t3),
        'actorId': 'p1',
      });

      final events = await repo.watchEvents('b1').first;
      expect(events.length, 3);
      expect(events[0].id, 'ev1');
      expect(events[0].status, BookingStatus.requested);
      expect(events[0].actorId, 'c1');
      expect(events[0].at, t1);

      expect(events[1].id, 'ev2');
      expect(events[1].status, BookingStatus.accepted);
      expect(events[1].actorId, 'p1');
      expect(events[1].at, t2);

      expect(events[2].id, 'ev3');
      expect(events[2].status, BookingStatus.completed);
      expect(events[2].actorId, 'p1');
      expect(events[2].at, t3);
    });

    test('myBookingsProvider follows the role and the signed-in user', () async {
      final fakeRepo = FakeBookingRepository(customerId: 'c1');
      final b1 = makeTestBooking(id: 'b1', customerId: 'c1', photographerId: 'p1', status: BookingStatus.accepted);
      final b2 = makeTestBooking(id: 'b2', customerId: 'c2', photographerId: 'c1', status: BookingStatus.upcoming);
      fakeRepo.seedBooking(b1);
      fakeRepo.seedBooking(b2);

      // 1. Unauthenticated -> empty stream
      final unauthContainer = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(unauthContainer.dispose);

      final subU = unauthContainer.listen(myBookingsProvider(BookingRole.customer), (_, _) {});
      addTearDown(subU.close);
      await unauthContainer.read(authStateProvider.future);
      expect(unauthContainer.read(myBookingsProvider(BookingRole.customer)).value ?? [], isEmpty);

      // 2. Signed in as c1 -> customer role reads b1, photographer role reads b2
      const authUser = AuthUser(uid: 'c1', email: 'c1@test.vn');
      final authContainer = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          authStateProvider.overrideWith((ref) => Stream.value(authUser)),
        ],
      );
      addTearDown(authContainer.dispose);

      final subC = authContainer.listen(myBookingsProvider(BookingRole.customer), (_, _) {});
      addTearDown(subC.close);
      final subP = authContainer.listen(myBookingsProvider(BookingRole.photographer), (_, _) {});
      addTearDown(subP.close);

      await authContainer.read(authStateProvider.future);

      final customerList = await authContainer.read(myBookingsProvider(BookingRole.customer).future);
      expect(customerList.map((b) => b.id), ['b1']);

      final photographerList = await authContainer.read(myBookingsProvider(BookingRole.photographer).future);
      expect(photographerList.map((b) => b.id), ['b2']);
    });

    test('refundPercentAt at 48 h, 47 h 59 min, 24 h, 23 h 59 min', () {
      final b = makeTestBooking(
        day: '2026-10-20',
        start: '09:00',
        end: '11:00',
        deposit: 300000,
      );

      // startsAt is 2026-10-20 02:00:00Z
      final start = startsAtOf(b);
      expect(start, DateTime.utc(2026, 10, 20, 2, 0));
      expect(endsAtOf(b), DateTime.utc(2026, 10, 20, 4, 0));

      // 48 hours before start -> 100%
      final t48h = start.subtract(const Duration(hours: 48));
      expect(refundPercentAt(b, t48h), 100);
      expect(refundAmountAt(b, t48h), 300000);

      // 47 hours 59 minutes before start -> 50%
      final t47h59m = start.subtract(const Duration(hours: 47, minutes: 59));
      expect(refundPercentAt(b, t47h59m), 50);
      expect(refundAmountAt(b, t47h59m), 150000);

      // 24 hours before start -> 50%
      final t24h = start.subtract(const Duration(hours: 24));
      expect(refundPercentAt(b, t24h), 50);
      expect(refundAmountAt(b, t24h), 150000);

      // 23 hours 59 minutes before start -> 0%
      final t23h59m = start.subtract(const Duration(hours: 23, minutes: 59));
      expect(refundPercentAt(b, t23h59m), 0);
      expect(refundAmountAt(b, t23h59m), 0);
    });
  });
}
