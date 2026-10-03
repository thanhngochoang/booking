import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';

import '../../support/fake_booking_repository.dart';

void main() {
  group('FakeBookingRepository', () {
    test('nextError throws once', () async {
      final repo = FakeBookingRepository();
      repo.nextError = BookingErrorCode.dayTaken;

      expect(
        () => repo.createBooking(
          photographerId: 'p1',
          serviceId: 's1',
          day: '2026-10-15',
          start: '09:00',
          place: const BookingPlace(name: 'Công viên'),
        ),
        throwsA(
          isA<BookingException>().having(
            (e) => e.code,
            'code',
            'day_taken',
          ),
        ),
      );

      // Next call should succeed because nextError resets to null
      expect(repo.nextError, isNull);
      final booking = await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-15',
        start: '09:00',
        place: const BookingPlace(name: 'Công viên'),
      );
      expect(booking.id, isNotEmpty);
    });

    test('remove emits null', () async {
      final repo = FakeBookingRepository();
      final booking = await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-15',
        start: '09:00',
        place: const BookingPlace(name: 'Công viên'),
      );

      final emissions = <Booking?>[];
      final sub = repo.watchBooking(booking.id).listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last?.id, booking.id);

      repo.remove(booking.id);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, isNull);
      await sub.cancel();
    });

    test('calls are recorded', () async {
      final repo = FakeBookingRepository();

      await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-15',
        start: '09:00',
        place: const BookingPlace(name: 'Công viên'),
        note: 'Ghi chú',
        expectedPrice: 1000000,
      );

      expect(repo.createCalls.length, 1);
      final createCall = repo.createCalls.first;
      expect(createCall.photographerId, 'p1');
      expect(createCall.serviceId, 's1');
      expect(createCall.day, '2026-10-15');
      expect(createCall.start, '09:00');
      expect(createCall.placeName, 'Công viên');
      expect(createCall.note, 'Ghi chú');
      expect(createCall.expectedPrice, 1000000);

      await repo.createDeposit(bookingId: 'b1', provider: 'momo');
      expect(repo.depositCalls.length, 1);
      expect(repo.depositCalls.first.bookingId, 'b1');
      expect(repo.depositCalls.first.provider, 'momo');

      await repo.confirmFakePayment(paymentId: 'pay_b1');
      expect(repo.fakeConfirms, ['pay_b1']);

      await repo.checkDeposit(bookingId: 'b1');
      expect(repo.checkCalls, ['b1']);
    });

    test('watchEvents emits seeded and added events', () async {
      final repo = FakeBookingRepository();
      final ev1 = BookingEventRecord(
        id: 'ev1',
        bookingId: 'b1',
        status: BookingStatus.requested,
        at: DateTime.utc(2026, 10, 1, 10, 0),
        actorId: 'c1',
      );
      repo.seedEvents('b1', [ev1]);

      final emissions = <List<BookingEventRecord>>[];
      final sub = repo.watchEvents('b1').listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.length, 1);
      expect(emissions.last.first.id, 'ev1');

      final ev2 = BookingEventRecord(
        id: 'ev2',
        bookingId: 'b1',
        status: BookingStatus.accepted,
        at: DateTime.utc(2026, 10, 1, 11, 0),
        actorId: 'p1',
      );
      repo.addEvent(ev2);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.length, 2);
      expect(emissions.last[1].id, 'ev2');
      await sub.cancel();
    });
  });
}
