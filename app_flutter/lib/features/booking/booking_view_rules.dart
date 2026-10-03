// Pure presentation rules for S05.01, S05.02 and S06.01. No widgets, no
// providers: the screens call these and only render the result.
import 'package:flutter/foundation.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "#A1F3": the last 4 characters of the booking id, upper-cased.
String bookingCode(String id) =>
    (id.length <= 4 ? id : id.substring(id.length - 4)).toUpperCase();

/// Everything S05.02 can offer; the list order is the display order.
enum DetailAction {
  message,
  contact,
  reschedule,
  directions,
  accept,
  decline,
  complete,
  cancel,
  bookAgain,
  review,
  viewReview,
}

bool _isActive(BookingStatus s) =>
    s == BookingStatus.accepted || s == BookingStatus.upcoming;

bool _isStopped(BookingStatus s) =>
    s == BookingStatus.declined ||
    s == BookingStatus.expired ||
    s == BookingStatus.cancelled;

/// True on the booking's Vietnamese day and the day before (Decision 3).
bool _inDirectionsWindow(Booking b, DateTime now) {
  final day = parseDayKey(b.day);
  if (day == null) return false;
  final today = parseDayKey(vnDateKey(now))!;
  final diff = day.difference(today).inDays;
  return diff == 0 || diff == 1;
}

/// Actions shown on S05.02 for [role] at [now], already filtered by
/// [features] and Decision 3's day window.
List<DetailAction> detailActions(
  Booking b,
  BookingRole role,
  DateTime now,
  BookingFeatures features,
) {
  final s = b.status;
  if (s == BookingStatus.draft) return const [];

  final beforeStart = now.isBefore(startsAtOf(b));
  final out = <DetailAction>[];

  if (features.chat && b.chatId != null) out.add(DetailAction.message);

  if (role == BookingRole.customer) {
    if (s == BookingStatus.requested || _isActive(s)) {
      out.add(DetailAction.contact);
    }
    if (_isActive(s) && features.reschedule && beforeStart) {
      out.add(DetailAction.reschedule);
    }
    if (_isActive(s) && _inDirectionsWindow(b, now)) {
      out.add(DetailAction.directions);
    }
    if ((s == BookingStatus.requested || _isActive(s)) && beforeStart) {
      out.add(DetailAction.cancel);
    }
    if (_isStopped(s)) out.add(DetailAction.bookAgain);
    if (s == BookingStatus.completed && features.review) {
      out.add(DetailAction.review);
    }
    if (s == BookingStatus.reviewed && features.review) {
      out.add(DetailAction.viewReview);
    }
    return out;
  }

  // Photographer.
  if (s == BookingStatus.requested) {
    final deadline = b.acceptDeadline;
    if (deadline == null || now.isBefore(deadline)) {
      out
        ..add(DetailAction.accept)
        ..add(DetailAction.decline);
    }
    return out;
  }
  if (_isActive(s)) {
    out.add(DetailAction.contact);
    if (features.reschedule && beforeStart) out.add(DetailAction.reschedule);
    if (BookingRules.canPhotographerComplete(b, now)) {
      out.add(DetailAction.complete);
    }
    if (beforeStart) out.add(DetailAction.cancel);
  }
  return out;
}

String _two(int n) => n.toString().padLeft(2, '0');

String _hm(DateTime instant) {
  final v = toVn(instant);
  return '${_two(v.hour)}:${_two(v.minute)}';
}

/// "Hôm nay 09:41" on the same Vietnamese day as [now], else "05/10 09:41".
String _when(DateTime instant, DateTime now, AppLocalizations l) {
  return vnDateKey(instant) == vnDateKey(now)
      ? l.timelineToday(_hm(instant))
      : '${formatDayMonth(toVn(instant))} ${_hm(instant)}';
}

DateTime? _eventAt(List<BookingEventRecord> events, BookingStatus status) {
  for (final e in events) {
    if (e.status == status) return e.at;
  }
  return null;
}

/// The amount given back on a cancelled booking: the server's figure when it
/// is set, else the refund percent recorded on the cancel.
int _refunded(Booking b) =>
    b.depositRefunded ??
    (b.cancel == null ? 0 : b.deposit * b.cancel!.refundPercent ~/ 100);

/// The 7 (or fewer + stopped) steps of Decision 2. Text comes from [l];
/// times from [events].
List<TimelineStep> timelineSteps(
  Booking b,
  List<BookingEventRecord> events,
  DateTime now,
  AppLocalizations l, {
  required String photographerName,
}) {
  const done = TimelineStepState.done;
  const current = TimelineStepState.current;
  const upcoming = TimelineStepState.upcoming;

  final s = b.status;
  final sentAt =
      _eventAt(events, BookingStatus.requested) ??
      b.depositPaidAt ??
      b.createdAt;
  final acceptedAt = _eventAt(events, BookingStatus.accepted);
  final day = parseDayKey(b.day);

  final step1 = TimelineStep(
    title: l.timelineSent,
    subtitle: l.timelineSentDetail(
      _when(sentAt, now, l),
      formatMoney(b.deposit),
    ),
    state: done,
  );
  TimelineStep step2(TimelineStepState st) => TimelineStep(
    title: l.timelineWaiting(photographerName),
    subtitle: st == done ? null : l.timelineWaitingHint,
    state: st,
  );
  TimelineStep step3(TimelineStepState st) => TimelineStep(
    title: l.timelineConfirmed,
    subtitle: st == done && acceptedAt != null
        ? _when(acceptedAt, now, l)
        : l.timelineConfirmedHint,
    state: st,
  );
  TimelineStep step4(TimelineStepState st) => TimelineStep(
    title: l.timelineUpcoming(day == null ? b.day : formatDay(day)),
    subtitle: l.timelineUpcomingHint,
    state: st,
  );
  TimelineStep step5(TimelineStepState st) =>
      TimelineStep(title: l.timelineShoot, state: st);
  TimelineStep step6(TimelineStepState st) => TimelineStep(
    title: l.timelineDone,
    subtitle: st == done && b.completedAt != null
        ? _when(b.completedAt!, now, l)
        : l.timelinePayAtShoot(formatMoney(b.remaining)),
    state: st,
  );
  TimelineStep step7(TimelineStepState st) =>
      TimelineStep(title: l.timelineReview, state: st);

  if (_isStopped(s)) {
    final reachedUpcoming = _eventAt(events, BookingStatus.upcoming) != null;
    final reachedAccepted =
        reachedUpcoming || _eventAt(events, BookingStatus.accepted) != null;
    final stopped = TimelineStep(
      title: switch (s) {
        BookingStatus.declined => l.timelineDeclined,
        BookingStatus.expired => l.timelineExpired,
        _ => l.timelineCancelled(formatMoney(_refunded(b))),
      },
      state: TimelineStepState.stopped,
    );
    return [
      step1,
      if (reachedAccepted) ...[step2(done), step3(done)],
      if (reachedUpcoming) step4(done),
      stopped,
    ];
  }

  switch (s) {
    case BookingStatus.draft:
    case BookingStatus.requested:
      return [
        step1,
        step2(current),
        step3(upcoming),
        step4(upcoming),
        step5(upcoming),
        step6(upcoming),
        step7(upcoming),
      ];
    case BookingStatus.accepted:
    case BookingStatus.upcoming:
      final started = !now.isBefore(startsAtOf(b));
      final TimelineStepState st4 = started
          ? done
          : (s == BookingStatus.upcoming ? current : upcoming);
      return [
        step1,
        step2(done),
        step3(done),
        step4(st4),
        step5(started ? current : upcoming),
        step6(upcoming),
        step7(upcoming),
      ];
    case BookingStatus.completed:
    case BookingStatus.reviewed:
      final reviewed = s == BookingStatus.reviewed;
      return [
        step1,
        step2(done),
        step3(done),
        step4(done),
        step5(done),
        step6(done),
        step7(reviewed ? done : upcoming),
      ];
    case BookingStatus.declined:
    case BookingStatus.expired:
    case BookingStatus.cancelled:
      return const []; // handled above
  }
}

/// S05.01: bookings of one group, drafts removed, sorted per 4a
/// Assumption 15 ("Sắp tới" and "Đang chờ" by start, nearest first;
/// "Đã xong" newest update first).
List<Booking> bucket(List<Booking> all, BookingTab tab) {
  final list = List.of(BookingRules.groupBookingsByTab(all)[tab]!);
  switch (tab) {
    case BookingTab.upcoming:
    case BookingTab.pending:
      list.sort((a, b) => startsAtOf(a).compareTo(startsAtOf(b)));
    case BookingTab.history:
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  return list;
}

/// S06.01 numbers (Decision 6).
@immutable
class WorkDashboard {
  const WorkDashboard({
    required this.today,
    required this.requests,
    required this.monthRevenueVnd,
    required this.heldVnd,
    required this.upcomingCount,
  });

  /// accepted/upcoming on today's Vietnamese date, earliest start.
  final Booking? today;

  /// requested and still within the deadline, soonest deadline first.
  final List<Booking> requests;

  final int monthRevenueVnd;
  final int heldVnd;
  final int upcomingCount;

  /// No shoot today, no requests and nothing upcoming.
  bool get isEmpty => today == null && requests.isEmpty && upcomingCount == 0;
}

const _heldEscrow = {
  EscrowStatus.held,
  EscrowStatus.partiallyRefunded,
  EscrowStatus.disputed,
};

WorkDashboard workDashboard(List<Booking> mine, DateTime now) {
  final todayKey = vnDateKey(now);
  final vnNow = toVn(now);

  final active = [
    for (final b in mine)
      if (_isActive(b.status)) b,
  ];
  final todays = [
    for (final b in active)
      if (b.day == todayKey) b,
  ]..sort((a, b) => startsAtOf(a).compareTo(startsAtOf(b)));

  final requests =
      [
        for (final b in mine)
          if (b.status == BookingStatus.requested &&
              (b.acceptDeadline == null || now.isBefore(b.acceptDeadline!)))
            b,
      ]..sort((a, b) {
        final da = a.acceptDeadline, db = b.acceptDeadline;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

  var month = 0;
  var held = 0;
  for (final b in mine) {
    if (b.status == BookingStatus.draft) continue;
    final done = b.completedAt;
    if ((b.status == BookingStatus.completed ||
            b.status == BookingStatus.reviewed) &&
        done != null) {
      final v = toVn(done);
      if (v.year == vnNow.year && v.month == vnNow.month) {
        month += b.serviceSnapshot.price;
      }
    }
    if (_heldEscrow.contains(b.escrowStatus)) {
      held += b.deposit - (b.depositRefunded ?? 0);
    }
  }

  return WorkDashboard(
    today: todays.isEmpty ? null : todays.first,
    requests: requests,
    monthRevenueVnd: month,
    heldVnd: held,
    upcomingCount: active.length,
  );
}

/// "22 giờ" / "45 phút" / "59 giây" for "Nhận · còn {time}"; null when zero
/// or negative. Called from core's `CountdownText(builder: …)`, which owns
/// the ticking.
String? countdownLabel(Duration left, AppLocalizations l) {
  if (left <= Duration.zero) return null;
  if (left.inHours >= 1) return l.countdownHours(left.inHours);
  if (left.inMinutes >= 1) return l.countdownMinutes(left.inMinutes);
  return l.countdownSeconds(left.inSeconds);
}
