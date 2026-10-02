// lib/data/booking/contact_access.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';

/// Client-side mirror of the server's `contact_unlocked` for bookings
/// (domain-model.md): from the deposit (`requested`) on, and for 30 days after
/// `completed`. It only decides which button to draw; `getContactLink` checks
/// again on the server. Event tickets (`paid`, until 7 days after the event)
/// get their own mapping when the registration model exists.
ContactAccess contactAccessForBooking(
  BookingStatus status, {
  DateTime? completedAt,
  required DateTime now,
}) {
  switch (status) {
    case BookingStatus.requested:
    case BookingStatus.accepted:
    case BookingStatus.upcoming:
      return ContactAccess.unlocked;
    case BookingStatus.completed:
    case BookingStatus.reviewed:
      if (completedAt == null) return ContactAccess.locked;
      final age = now.toUtc().difference(completedAt.toUtc());
      return age <= const Duration(days: 30)
          ? ContactAccess.unlocked
          : ContactAccess.locked;
    case BookingStatus.draft:
    case BookingStatus.declined:
    case BookingStatus.expired:
    case BookingStatus.cancelled:
      return ContactAccess.locked;
  }
}
