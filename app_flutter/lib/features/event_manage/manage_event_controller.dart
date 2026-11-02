// lib/features/event_manage/manage_event_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';

/// Check-in stays open this long after the event ends (domain
/// `CHECKIN_GRACE_HOURS`).
const checkinGrace = Duration(hours: 2);

/// The attendee's phone for a manager: only a paid ticket has one (O3).
final registrationContactProvider = StreamProvider.autoDispose
    .family<BookingContactSnapshot?, ({String eventId, String registrationId})>(
      (ref, key) => ref
          .watch(eventRepositoryProvider)
          .watchRegistrationContact(key.eventId, key.registrationId),
    );

/// When the server starts taking check-ins: 00:00 in Việt Nam on the event
/// day (domain `checkInRegistration`: `parseVnDateTime(dayKey, '00:00')`).
DateTime checkinOpensAt(EventDetail e) =>
    calendarDay(toVn(e.summary.startsAt)).subtract(const Duration(hours: 7));

/// When the server stops taking check-ins: `endAt + CHECKIN_GRACE_HOURS`.
DateTime checkinClosesAt(EventDetail e) => e.endsAt.add(checkinGrace);

/// Where [now] sits against the check-in window of [e].
enum CheckinWindow { notYet, open, closed }

CheckinWindow checkinWindowOf(EventDetail e, DateTime now) {
  if (now.isBefore(checkinOpensAt(e))) {
    return CheckinWindow.notYet;
  }
  if (now.isAfter(checkinClosesAt(e))) {
    return CheckinWindow.closed;
  }
  return CheckinWindow.open;
}

/// "Quét mã check‑in" is on only while the server takes check-ins (event day
/// 00:00 VN → `endAt + 2 h`), and never for a cancelled or unpublished event.
bool manageCanScan(EventDetail e, DateTime now) {
  final published = switch (e.summary.status) {
    EventStatus.open ||
    EventStatus.full ||
    EventStatus.closed ||
    EventStatus.completed => true,
    _ => false,
  };
  return published && checkinWindowOf(e, now) == CheckinWindow.open;
}

/// The numbers S12.03 shows, from the event and its registrations.
@immutable
class ManageStats {
  const ManageStats({
    required this.registered,
    required this.capacity,
    required this.revenueVnd,
    required this.daysLeft,
    required this.tickets,
    required this.refundVnd,
    required this.checkedIn,
  });

  final int registered;
  final int capacity;

  /// Money from paid tickets (not held, cancelled, refunded or refund-due).
  final int revenueVnd;
  final int daysLeft;

  /// Seats taken by active registrations.
  final int tickets;

  /// What cancelling the event gives back: every paid ticket in full, and
  /// the held money of tickets cancelled late without a refund.
  final int refundVnd;
  final int checkedIn;

  static ManageStats of(
    EventDetail e,
    List<EventRegistration> regs,
    DateTime now,
  ) {
    var revenue = 0;
    var refund = 0;
    var tickets = 0;
    var checkedIn = 0;
    for (final r in regs) {
      // A ticket cancelled late keeps its money held for the host (O4); a
      // host cancel gives it back too, so it counts in the refund total.
      if (r.status == RegistrationStatus.cancelled &&
          r.amount > 0 &&
          r.refundPercent == 0) {
        refund += r.amount;
      }
      if (!r.isActive) {
        continue;
      }
      tickets += r.quantity;
      if (r.status == RegistrationStatus.paid) {
        if (!r.refundDue) {
          revenue += r.amount;
        }
        refund += r.amount;
        if (r.isCheckedIn) {
          checkedIn += r.quantity;
        }
      }
    }
    final today = vnToday(now);
    final day = calendarDay(toVn(e.summary.startsAt));
    final left = day.difference(today).inDays;
    return ManageStats(
      registered: e.summary.registeredCount,
      capacity: e.summary.capacity,
      revenueVnd: revenue,
      daysLeft: left < 0 ? 0 : left,
      tickets: tickets,
      refundVnd: refund,
      checkedIn: checkedIn,
    );
  }
}

final manageEventControllerProvider = NotifierProvider.autoDispose
    .family<ManageEventController, ManageEventState, String>(
      ManageEventController.new,
    );

@immutable
class ManageEventState {
  const ManageEventState({this.busy = false});
  final bool busy;
}

/// The writes of S12.03: cancelling the event, answering the
/// invitation of a staff-created event (O1).
class ManageEventController extends Notifier<ManageEventState> {
  ManageEventController(this.eventId);
  final String eventId;

  @override
  ManageEventState build() => const ManageEventState();

  EventRepository get _repo => ref.read(eventRepositoryProvider);

  /// True when the event was cancelled.
  Future<bool> cancelEvent() async {
    if (state.busy) {
      return false;
    }
    state = const ManageEventState(busy: true);
    try {
      await _repo.cancelEvent(eventId);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) {
        state = const ManageEventState();
      }
    }
  }

  /// True when the answer reached the server.
  Future<bool> respond({required bool accept}) async {
    if (state.busy) {
      return false;
    }
    state = const ManageEventState(busy: true);
    try {
      await _repo.respondToHostConsent(eventId, accept: accept);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) {
        state = const ManageEventState();
      }
    }
  }
}
