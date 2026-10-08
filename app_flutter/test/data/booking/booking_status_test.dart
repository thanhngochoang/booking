import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking_status.dart';

void main() {
  test("bookingStatusFromCode('upcoming') is BookingStatus.upcoming", () {
    expect(bookingStatusFromCode('upcoming'), BookingStatus.upcoming);
    for (final s in BookingStatus.values) {
      expect(bookingStatusFromCode(s.name), s);
    }
  });

  test('an unknown or missing code is null', () {
    expect(bookingStatusFromCode('unknown'), isNull);
    expect(bookingStatusFromCode(''), isNull);
    expect(bookingStatusFromCode(null), isNull);
  });
}
