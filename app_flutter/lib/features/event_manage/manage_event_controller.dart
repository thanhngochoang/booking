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
import 'package:photobooking/features/event_manage/checkin_sheet.dart';

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

/// "Quét mã check‑in" is on from when the event is published until
/// `endAt + 2 h`, and never for a cancelled or unpublished event.
bool manageCanScan(EventDetail e, DateTime now) {
  final open = switch (e.summary.status) {
    EventStatus.open ||
    EventStatus.full ||
    EventStatus.closed ||
    EventStatus.completed => true,
    _ => false,
  };
  return open && now.isBefore(e.endsAt.add(checkinGrace));
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

  /// Money from paid tickets still held (not cancelled or refunded).
  final int revenueVnd;
  final int daysLeft;

  /// Seats taken by active registrations.
  final int tickets;

  /// What cancelling the event gives back: every paid ticket in full.
  final int refundVnd;
  final int checkedIn;

  static ManageStats of(
    EventDetail e,
    List<EventRegistration> regs,
    DateTime now,
  ) {
    var revenue = 0;
    var tickets = 0;
    var checkedIn = 0;
    for (final r in regs) {
      if (!r.isActive) {
        continue;
      }
      tickets += r.quantity;
      if (r.status == RegistrationStatus.paid) {
        revenue += r.amount;
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
      refundVnd: revenue,
      checkedIn: checkedIn,
    );
  }
}

/// Maps what the server said to what the host reads after a scan.
CheckinOutcome checkinOutcomeOf(Object error) => switch (eventErrorCodeOf(
  error,
)) {
  'not_found' || 'not_eligible' || 'invalid_argument' => CheckinOutcome.invalid,
  'conflict' => CheckinOutcome.used,
  _ => CheckinOutcome.failed,
};

final manageEventControllerProvider = NotifierProvider.autoDispose
    .family<ManageEventController, ManageEventState, String>(
      ManageEventController.new,
    );

@immutable
class ManageEventState {
  const ManageEventState({this.busy = false});
  final bool busy;
}

/// The writes of S12.03: check-in, cancelling the event, answering the
/// invitation of a staff-created event (O1).
class ManageEventController extends Notifier<ManageEventState> {
  ManageEventController(this.eventId);
  final String eventId;

  @override
  ManageEventState build() => const ManageEventState();

  EventRepository get _repo => ref.read(eventRepositoryProvider);

  Future<CheckinResult> checkIn(String code) async {
    try {
      final r = await _repo.checkIn(eventId, code);
      return CheckinResult(
        CheckinOutcome.ok,
        name: r.name,
        quantity: r.quantity,
      );
    } catch (e) {
      return CheckinResult(checkinOutcomeOf(e));
    }
  }

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
