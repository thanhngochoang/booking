import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';

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
  });
}
