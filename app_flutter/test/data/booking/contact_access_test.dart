// test/data/booking/contact_access_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/contact_access.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);

  test('open from the deposit until the booking is over', () {
    for (final s in [
      BookingStatus.requested,
      BookingStatus.accepted,
      BookingStatus.upcoming,
    ]) {
      expect(
        contactAccessForBooking(s, now: now),
        ContactAccess.unlocked,
        reason: s.name,
      );
    }
  });

  test('closed for drafts and for bookings that fell through', () {
    for (final s in [
      BookingStatus.draft,
      BookingStatus.declined,
      BookingStatus.expired,
      BookingStatus.cancelled,
    ]) {
      expect(
        contactAccessForBooking(s, now: now),
        ContactAccess.locked,
        reason: s.name,
      );
    }
  });

  test('completed and reviewed bookings stay open for 30 days', () {
    for (final s in [BookingStatus.completed, BookingStatus.reviewed]) {
      expect(
        contactAccessForBooking(
          s,
          completedAt: now.subtract(const Duration(days: 29)),
          now: now,
        ),
        ContactAccess.unlocked,
      );
      expect(
        contactAccessForBooking(
          s,
          completedAt: now.subtract(const Duration(days: 30)),
          now: now,
        ),
        ContactAccess.unlocked,
      );
      expect(
        contactAccessForBooking(
          s,
          completedAt: now.subtract(const Duration(days: 30, seconds: 1)),
          now: now,
        ),
        ContactAccess.locked,
      );
      expect(
        contactAccessForBooking(s, now: now),
        ContactAccess.locked,
      ); // unknown date: stay closed
    }
  });

  test('time zones do not matter', () {
    final local = DateTime.parse(
      '2026-09-30T20:00:00+07:00',
    ); // = 13:00 UTC on the 30th, within 30 days
    expect(
      contactAccessForBooking(
        BookingStatus.completed,
        completedAt: local,
        now: now,
      ),
      ContactAccess.unlocked,
    );
  });
}
