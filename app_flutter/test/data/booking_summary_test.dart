// test/data/booking_summary_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/booking_summary.dart';

void main() {
  test('bookingSummaryOf maps Booking correctly', () {
    final booking = Booking(
      id: 'b1',
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 's1',
      serviceSnapshot: const BookingServiceSnapshot(
        name: 'Chân dung 2 giờ',
        price: 1500000,
        durationMinutes: 120,
      ),
      day: '2026-10-12',
      start: '15:30',
      end: '17:30',
      place: const BookingPlace(name: 'Bến Bạch Đằng'),
      status: BookingStatus.requested,
      deposit: 450000,
      remaining: 1050000,
      createdAt: DateTime(2026, 10, 2),
      updatedAt: DateTime(2026, 10, 2),
    );

    final summary = bookingSummaryOf(
      booking,
      photographerName: 'Minh Trí',
      thumbUrl: 'https://example.com/thumb.jpg',
      statusLabel: 'Chờ cọc',
    );

    expect(summary.photographerName, 'Minh Trí');
    expect(summary.serviceName, 'Chân dung 2 giờ');
    expect(summary.thumbUrl, 'https://example.com/thumb.jpg');
    expect(summary.day, '2026-10-12');
    expect(summary.start, '15:30');
    expect(summary.end, '17:30');
    expect(summary.placeName, 'Bến Bạch Đằng');
    expect(summary.status, BookingStatus.requested);
    expect(summary.statusLabel, 'Chờ cọc');
  });
}
