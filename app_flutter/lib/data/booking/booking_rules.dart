import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';

/// Client-side mirror of booking domain policies and math (matches booking_policy.ts).
class BookingRules {
  const BookingRules._();

  static const int depositPercent = 30;
  static const int disputeWindowHours = 24;
  static const int draftExpiryMinutes = 30;
  static const int maxBookingDaysAhead = 365;

  /// Computes deposit and remaining for a service price (integer VND).
  static ({int deposit, int remaining}) computeDeposit(int price) {
    final deposit = (price * 0.3).floor();
    final remaining = price - deposit;
    return (deposit: deposit, remaining: remaining);
  }

  /// Parses day (YYYY-MM-DD) and time (HH:mm) in Asia/Ho_Chi_Minh timezone (UTC+7).
  static DateTime parseBookingDateTime(String day, String time) {
    final parts = day.split('-');
    final timeParts = time.split(':');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    final hr = int.parse(timeParts[0]);
    final min = int.parse(timeParts[1]);
    return DateTime.utc(y, m, d, hr - 7, min);
  }

  /// Calculates refund percentage based on cancellation policy:
  /// - Photographer or system cancel: 100%
  /// - Customer cancel >= 48h before start: 100%
  /// - Customer cancel 24h..48h before start: 50%
  /// - Customer cancel < 24h before start: 0%
  static int computeRefundPercent({
    required DateTime startsAt,
    required DateTime cancelledAt,
    required String actorRole,
  }) {
    if (actorRole == 'photographer' || actorRole == 'system') {
      return 100;
    }

    final diffSeconds = startsAt.difference(cancelledAt).inSeconds;
    final hoursBefore = diffSeconds / 3600.0;

    if (hoursBefore >= 48.0) {
      return 100;
    } else if (hoursBefore >= 24.0) {
      return 50;
    } else {
      return 0;
    }
  }

  /// Determines which S05.01 tab a booking belongs to.
  /// Draft bookings are excluded from all tabs (returns null).
  static BookingTab? tabForBooking(Booking booking) {
    return switch (booking.status) {
      BookingStatus.draft => null,
      BookingStatus.requested => BookingTab.pending,
      BookingStatus.accepted || BookingStatus.upcoming => BookingTab.upcoming,
      BookingStatus.completed ||
      BookingStatus.reviewed ||
      BookingStatus.declined ||
      BookingStatus.expired ||
      BookingStatus.cancelled => BookingTab.history,
    };
  }

  /// Groups bookings into S05.01 tabs and sorts them:
  /// - upcoming: nearest shoot date first
  /// - pending: newest request first
  /// - history: newest update first
  static Map<BookingTab, List<Booking>> groupBookingsByTab(
    List<Booking> bookings,
  ) {
    final map = <BookingTab, List<Booking>>{
      BookingTab.upcoming: [],
      BookingTab.pending: [],
      BookingTab.history: [],
    };

    for (final b in bookings) {
      final tab = tabForBooking(b);
      if (tab != null) {
        map[tab]!.add(b);
      }
    }

    // Sort upcoming: nearest shoot day/start first
    map[BookingTab.upcoming]!.sort((a, b) {
      final cmp = a.day.compareTo(b.day);
      if (cmp != 0) return cmp;
      return a.start.compareTo(b.start);
    });

    // Sort pending: newest createdAt first
    map[BookingTab.pending]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Sort history: newest updatedAt first
    map[BookingTab.history]!.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return map;
  }

  /// Checks if customer can cancel the booking.
  static bool canCustomerCancel(Booking booking) {
    return booking.status == BookingStatus.requested ||
        booking.status == BookingStatus.accepted ||
        booking.status == BookingStatus.upcoming;
  }

  /// Checks if photographer can accept the booking.
  static bool canPhotographerAccept(Booking booking) {
    return booking.status == BookingStatus.requested;
  }

  /// Checks if photographer can decline the booking.
  static bool canPhotographerDecline(Booking booking) {
    return booking.status == BookingStatus.requested;
  }

  /// Checks if photographer can complete the booking (after shoot ends).
  static bool canPhotographerComplete(Booking booking, DateTime now) {
    if (booking.status != BookingStatus.upcoming &&
        booking.status != BookingStatus.accepted) {
      return false;
    }
    final endsAt = parseBookingDateTime(booking.day, booking.end);
    return now.isAfter(endsAt) || now.isAtSameMomentAs(endsAt);
  }

  /// Checks if customer can open a dispute within 24h after completion.
  static bool canCustomerDispute(Booking booking, DateTime now) {
    if (booking.status != BookingStatus.upcoming &&
        booking.status != BookingStatus.completed) {
      return false;
    }
    if (booking.escrowStatus != EscrowStatus.held &&
        booking.escrowStatus != EscrowStatus.partiallyRefunded) {
      return false;
    }
    if (booking.completedAt != null) {
      final diff = now.difference(booking.completedAt!).inHours;
      if (diff > disputeWindowHours) {
        return false;
      }
    }
    return true;
  }
}

/// S05.01 tab categories.
enum BookingTab {
  /// Sắp tới: accepted, upcoming
  upcoming,

  /// Đang chờ: requested
  pending,

  /// Đã xong: completed, reviewed, declined, expired, cancelled
  history,
}

/// Calculates time slots every 30 minutes from 06:00 to 20:00 minus durationMinutes.
List<String> daySlots(int durationMinutes) {
  const startMinute = 6 * 60; // 06:00 = 360
  const endMinute = 20 * 60; // 20:00 = 1200
  final latestStart = endMinute - durationMinutes;

  final slots = <String>[];
  for (var m = startMinute; m <= latestStart; m += 30) {
    final hours = m ~/ 60;
    final mins = m % 60;
    slots.add(
      '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}',
    );
  }
  return slots;
}

/// Adds durationMinutes to HH:mm string and returns HH:mm.
String endTimeFor(String start, int durationMinutes) {
  final parts = start.split(':');
  if (parts.length != 2) throw ArgumentError('Invalid start time: $start');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final total = h * 60 + m + durationMinutes;
  final newH = (total ~/ 60) % 24;
  final newM = total % 60;
  return '${newH.toString().padLeft(2, '0')}:${newM.toString().padLeft(2, '0')}';
}

const int kNoteMaxLength = 300;
const int kPlaceMinLength = 3;
const int kPlaceMaxLength = 120;

/// Calculates deposit and remaining from price.
({int deposit, int remaining}) depositFor(int price) =>
    BookingRules.computeDeposit(price);
