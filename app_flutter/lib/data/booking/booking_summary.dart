// lib/data/booking/booking_summary.dart
import 'package:photobooking/core/widgets/booking_card.dart';
import 'package:photobooking/data/booking/booking.dart';

/// Adapts a data entity [Booking] into the presentation model [BookingSummary].
BookingSummary bookingSummaryOf(
  Booking b, {
  required String photographerName,
  String? thumbUrl,
  String? statusLabel,
}) {
  return BookingSummary(
    photographerName: photographerName,
    serviceName: b.serviceSnapshot.name,
    thumbUrl: thumbUrl,
    day: b.day,
    start: b.start,
    end: b.end,
    placeName: b.place.name,
    status: b.status,
    statusLabel: statusLabel,
  );
}
