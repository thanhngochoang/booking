// Pure presentation rules for S05.01, S05.02 and S06.01. No widgets, no
// providers: the screens call these and only render the result.
import 'package:flutter/foundation.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/studio/studio_common.dart' show studioDeadlineText;
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
  markShot,
  deliver,
  answerExtraRound,
  viewDelivery,
  complete,
  cancel,
  bookAgain,
  review,
  viewReview,

  /// The studio names or changes who shoots (S26.04).
  assign,

  /// "Huỷ và hoàn 100%": the customer's cancel after a studio fault
  /// (Decision 12); replaces [cancel] while the right lasts.
  cancelStudioFault,

  /// "Trả việc": the assignee hands the job back before the start
  /// (Decision 14), once.
  returnJob,
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
  BookingFeatures features, {
  bool assignee = false,
}) {
  final s = b.status;
  if (s == BookingStatus.draft) return const [];

  final beforeStart = now.isBefore(startsAtOf(b));
  // A studio booking cannot be moved (the reschedule callable refuses it).
  final canReschedule = features.reschedule && beforeStart && b.studio == null;
  final out = <DetailAction>[];

  if (features.chat && b.chatId != null) out.add(DetailAction.message);

  if (role == BookingRole.customer) {
    if (s == BookingStatus.requested ||
        _isActive(s) ||
        s == BookingStatus.shot ||
        s == BookingStatus.delivered ||
        s == BookingStatus.revisionRequested ||
        s == BookingStatus.approved) {
      out.add(DetailAction.contact);
    }
    if (_isActive(s) && canReschedule) {
      out.add(DetailAction.reschedule);
    }
    if (_isActive(s) && _inDirectionsWindow(b, now)) {
      out.add(DetailAction.directions);
    }
    if ((s == BookingStatus.requested || _isActive(s)) && beforeStart) {
      out.add(
        studioFaultOf(b, now) == null
            ? DetailAction.cancel
            : DetailAction.cancelStudioFault,
      );
    }
    if (s == BookingStatus.delivered ||
        s == BookingStatus.revisionRequested ||
        s == BookingStatus.approved) {
      out.add(DetailAction.viewDelivery);
    }
    if (_isStopped(s)) out.add(DetailAction.bookAgain);
    // A studio booking is reviewed with who shot it: none, no review.
    if (BookingRules.canReview(b) &&
        features.review &&
        (b.studio == null || b.studio!.assigneeId != null)) {
      out.add(DetailAction.review);
    }
    if (BookingRules.isReviewed(b) && features.review) {
      out.add(DetailAction.viewReview);
    }
    return out;
  }

  // The member a studio assigned (Decisions 14, 15, 17): messages, the
  // customer's contact, "Đã chụp" and, before the start, "Trả việc" (as on
  // S06.01); the studio answers, moves, cancels and delivers (no S06.07
  // entry).
  if (assignee) {
    if (_isActive(s) || s == BookingStatus.shot) out.add(DetailAction.contact);
    if (_isActive(s) && BookingRules.canPhotographerComplete(b, now)) {
      out.add(DetailAction.markShot);
    }
    if (_isActive(s) && beforeStart && !(b.studio?.isReturned ?? false)) {
      out.add(DetailAction.returnJob);
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
    if (canReschedule) out.add(DetailAction.reschedule);
    if (b.studio != null && beforeStart) out.add(DetailAction.assign);
    if (BookingRules.canPhotographerComplete(b, now)) {
      out.add(DetailAction.markShot);
    }
    if (beforeStart) out.add(DetailAction.cancel);
    return out;
  }
  if (s == BookingStatus.shot || s == BookingStatus.revisionRequested) {
    out.add(DetailAction.contact);
    out.add(DetailAction.deliver);
    return out;
  }
  if (s == BookingStatus.delivered) {
    out.add(DetailAction.contact);
    if (b.extraRound?.status == 'pending') {
      out.add(DetailAction.answerExtraRound);
    }
    return out;
  }
  if (s == BookingStatus.approved) {
    out.add(DetailAction.contact);
    return out;
  }
  return out;
}

/// Which of [actions] S05.02 draws as its gradient (primary) button; the
/// screen keeps one. "Xem ảnh bàn giao" is primary until the delivery is
/// approved or a review is due; a customer's "Nhắn studio" is primary only
/// when none of these is on screen.
Set<DetailAction> primaryActions(Booking b, List<DetailAction> actions) => {
  for (final a in actions)
    if (switch (a) {
      DetailAction.accept ||
      DetailAction.complete ||
      DetailAction.markShot ||
      DetailAction.deliver ||
      DetailAction.bookAgain ||
      DetailAction.review => true,
      DetailAction.viewDelivery =>
        b.status != BookingStatus.approved &&
            !actions.contains(DetailAction.review),
      _ => false,
    })
      a,
};

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
  bool studioRows = false,
  String assigneeName = '',
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

  final isCustomer = photographerName != l.detailYou;
  final roundNum = b.deliveryRound > 0 ? b.deliveryRound : 1;
  String? deliverySubtitle;
  switch (s) {
    case BookingStatus.shot:
      deliverySubtitle = isCustomer
          ? l.timelineDeliveryWaitCustomer(photographerName)
          : l.timelineDeliveryWaitProvider;
    case BookingStatus.delivered:
      deliverySubtitle = isCustomer
          ? l.timelineDeliveryReviewCustomer(roundNum)
          : l.timelineDeliveryReviewProvider(roundNum);
    case BookingStatus.revisionRequested:
      deliverySubtitle = isCustomer
          ? l.timelineDeliveryRevisingCustomer(photographerName, roundNum)
          : l.timelineDeliveryRevisingProvider(roundNum);
    case BookingStatus.approved:
    case BookingStatus.completed:
    case BookingStatus.reviewed:
      deliverySubtitle = b.approvedAt != null
          ? l.timelineDeliveryApproved(_when(b.approvedAt!, now, l))
          : null;
    default:
      deliverySubtitle = null;
  }

  TimelineStep stepDelivery(TimelineStepState st) => TimelineStep(
    title: l.timelineDelivery,
    subtitle: deliverySubtitle,
    state: st,
  );

  TimelineStep step6(TimelineStepState st) => TimelineStep(
    title: l.timelineDone,
    subtitle: st == done && b.completedAt != null
        ? _when(b.completedAt!, now, l)
        : (st == current && s == BookingStatus.approved
            ? l.timelineCheck
            : (b.remaining > 0
                ? l.timelinePayAtShoot(formatMoney(b.remaining))
                : null)),
    state: st,
  );
  TimelineStep step7(TimelineStepState st) =>
      TimelineStep(title: l.timelineReview, state: st);

  // A studio booking, for the customer (mock S05.02-studio): who shoots, or
  // the wait for it after the studio confirmed; overdue once the deadline
  // passed unassigned.
  final studio = studioRows ? b.studio : null;
  List<TimelineStep> assignStep() {
    if (studio == null) return const [];
    if (studio.assignStatus == StudioAssignStatus.assigned) {
      return [
        TimelineStep(
          title: l.timelineAssigned,
          subtitle: assigneeName.isEmpty
              ? null
              : l.timelineAssignedBody(assigneeName),
          state: done,
        ),
      ];
    }
    final overdue = !now.isBefore(studio.assignDeadline);
    return [
      TimelineStep(
        title: l.timelineAwaitAssign,
        subtitle: overdue
            ? l.timelineAwaitAssignBody(studioDeadlineText(studio.assignDeadline))
            : null,
        state: current,
      ),
    ];
  }

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
        stepDelivery(upcoming),
        step6(upcoming),
        step7(upcoming),
      ];
    case BookingStatus.accepted:
    case BookingStatus.upcoming:
      final started = !now.isBefore(startsAtOf(b));
      final TimelineStepState st4 = started
          ? done
          : (s == BookingStatus.upcoming ? current : upcoming);
      final waitingForAssign =
          studio != null && studio.assignStatus != StudioAssignStatus.assigned;
      return [
        step1,
        step2(done),
        step3(done),
        ...assignStep(),
        step4(waitingForAssign && st4 == current ? upcoming : st4),
        step5(started ? current : upcoming),
        stepDelivery(upcoming),
        step6(upcoming),
        step7(upcoming),
      ];
    case BookingStatus.shot:
    case BookingStatus.delivered:
    case BookingStatus.revisionRequested:
      return [
        step1,
        step2(done),
        step3(done),
        ...assignStep(),
        step4(done),
        step5(done),
        stepDelivery(current),
        step6(upcoming),
        step7(upcoming),
      ];
    case BookingStatus.approved:
      return [
        step1,
        step2(done),
        step3(done),
        ...assignStep(),
        step4(done),
        step5(done),
        stepDelivery(done),
        step6(current),
        step7(upcoming),
      ];
    case BookingStatus.completed:
    case BookingStatus.reviewed:
      final reviewed = BookingRules.isReviewed(b);
      return [
        step1,
        step2(done),
        step3(done),
        ...assignStep(),
        step4(done),
        step5(done),
        stepDelivery(done),
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
    this.toDeliver = const [],
    this.studioJobs = const [],
    this.assignedJobs = const [],
  });

  /// accepted/upcoming on today's Vietnamese date, earliest start.
  final Booking? today;

  /// requested and still within the deadline, soonest deadline first.
  final List<Booking> requests;

  final int monthRevenueVnd;
  final int heldVnd;
  final int upcomingCount;

  /// Bookings waiting for delivery actions (shot, revisionRequested, or delivered with pending extra round).
  final List<Booking> toDeliver;

  /// A studio's own accepted bookings before their start, earliest first,
  /// except today's (S06.01-studio: "Giao thợ", deadline, change request).
  final List<Booking> studioJobs;

  /// Accepted bookings a studio gave this photographer, before their start,
  /// earliest first, except today's (S06.01-member: "Trả việc").
  final List<Booking> assignedJobs;

  /// No shoot today, no requests, nothing to deliver and nothing upcoming.
  bool get isEmpty =>
      today == null &&
      requests.isEmpty &&
      toDeliver.isEmpty &&
      studioJobs.isEmpty &&
      assignedJobs.isEmpty &&
      upcomingCount == 0;
}

const _heldEscrow = {
  EscrowStatus.held,
  EscrowStatus.partiallyRefunded,
  EscrowStatus.disputed,
};

/// [mine] holds the photographer's own bookings and the ones a studio
/// assigned to [uid] (Decision 18): those (`photographerId != uid`) count for
/// "Hôm nay" and "Buổi sắp tới" only; the money and the answer are the
/// studio's, so they never reach requests, "Tháng này" or "Đang giữ".
WorkDashboard workDashboard(
  List<Booking> mine,
  DateTime now, {
  required String uid,
}) {
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

  final own = [
    for (final b in mine)
      if (b.photographerId == uid) b,
  ];

  final requests =
      [
        for (final b in own)
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

  final toDeliver = [
    for (final b in own)
      if (b.status == BookingStatus.shot ||
          b.status == BookingStatus.revisionRequested ||
          (b.status == BookingStatus.delivered &&
              b.extraRound?.status == 'pending'))
        b,
  ]..sort((a, b) => startsAtOf(a).compareTo(startsAtOf(b)));

  var month = 0;
  var held = 0;
  for (final b in own) {
    if (b.status == BookingStatus.draft) continue;
    final done = b.completedAt;
    if ((b.status == BookingStatus.completed ||
            b.status == BookingStatus.reviewed) &&
        done != null) {
      final v = toVn(done);
      if (v.year == vnNow.year && v.month == vnNow.month) {
        month += b.totalVnd;
      }
    }
    if (_heldEscrow.contains(b.escrowStatus)) {
      held += b.deposit - (b.depositRefunded ?? 0);
    }
  }

  final today = todays.isEmpty ? null : todays.first;
  List<Booking> ahead(bool Function(Booking) where) => [
    for (final b in active)
      if (b.studio != null &&
          b.id != today?.id &&
          now.isBefore(startsAtOf(b)) &&
          where(b))
        b,
  ]..sort((a, b) => startsAtOf(a).compareTo(startsAtOf(b)));

  return WorkDashboard(
    today: today,
    requests: requests,
    monthRevenueVnd: month,
    heldVnd: held,
    upcomingCount: active.length,
    toDeliver: toDeliver,
    studioJobs: ahead((b) => b.photographerId == uid),
    assignedJobs: ahead(
      (b) => b.photographerId != uid && b.studio!.assigneeId == uid,
    ),
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

/// The viewer's side of [b], or null when [uid] is not one of its parties.
BookingRole? roleIn(Booking b, String? uid) {
  if (uid == null) return null;
  if (b.customerId == uid) return BookingRole.customer;
  if (b.photographerId == uid) return BookingRole.photographer;
  // The member a studio assigned works on the studio's side (Decision 16).
  if (isAssigneeOf(b, uid)) return BookingRole.photographer;
  return null;
}

/// True when [uid] shoots [b] for the studio that was booked (not the
/// studio itself).
bool isAssigneeOf(Booking b, String? uid) =>
    uid != null && b.photographerId != uid && b.studio?.assigneeId == uid;

/// [BookingCard] data with the day as the mock writes it ("T2 12/10").
/// [name] is the other party: the photographer for the customer and the
/// customer for the photographer.
BookingSummary bookingSummaryFor(
  Booking b, {
  required String name,
  String? thumbUrl,
  String? tag,
}) {
  final day = parseDayKey(b.day);
  return BookingSummary(
    photographerName: name,
    serviceName: b.serviceSnapshot.name,
    thumbUrl: thumbUrl,
    day: day == null ? b.day : formatDay(day),
    start: b.start,
    end: b.end,
    placeName: b.place.name,
    status: b.status,
    tag: tag,
  );
}

/// Google Maps search for the place (Decision 3: no coordinates in v1).
Uri directionsUri(Booking b) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': b.place.name,
});

/// Mirror of the domain's `studioFaultOf` (Decision 12): why the customer
/// may cancel [b] with a full refund at [now], or null. Set by the server
/// (`studioFault`), or the deadline passed with nobody assigned (even before
/// the sweep marked it); only before the start.
StudioFaultKind? studioFaultOf(Booking b, DateTime now) {
  final s = b.studio;
  if (s == null || !now.isBefore(startsAtOf(b))) return null;
  if (s.studioFault case final f?) return f.kind;
  if (s.assignStatus != StudioAssignStatus.assigned &&
      !now.isBefore(s.assignDeadline)) {
    return StudioFaultKind.assignOverdue;
  }
  return null;
}

/// What S05.02's "Thợ chụp cho bạn" shows the customer (mock
/// `#S05.02-studio`, `-late`, `-change`).
enum StudioBlockState {
  /// Nobody yet, the deadline still ahead: "Studio sẽ báo thợ chụp trước …".
  waiting,

  /// The member card with "Xin đổi thợ (1 lần)" while it can be used.
  assigned,

  /// The card with "Đã xin đổi · chờ studio" (disabled).
  changePending,

  /// Nobody past the deadline: "Quá hạn", the warning and the 100% cancel.
  /// Once the shoot has started the right is gone: the warning keeps its
  /// title only, without the refund line or the cancel.
  overdue,

  /// The card, then the studio's refusal and the 100% cancel.
  changeDeclined,

  /// The card, then "Studio chưa trả lời …" and the 100% cancel.
  changeExpired,

  /// The new member's card, then "Studio đã đổi thợ khi còn dưới 24 giờ".
  lateReassign,
}

/// The state of [b]'s studio block at [now]; null for an individual
/// booking. The fault states follow [studioFaultOf], so they end at the
/// start (the card stays).
StudioBlockState? studioBlockStateOf(Booking b, DateTime now) {
  final s = b.studio;
  if (s == null) return null;
  final fault = studioFaultOf(b, now);
  if (s.assignStatus != StudioAssignStatus.assigned) {
    return !now.isBefore(s.assignDeadline)
        ? StudioBlockState.overdue
        : StudioBlockState.waiting;
  }
  switch (fault) {
    case StudioFaultKind.changeDeclined:
      return StudioBlockState.changeDeclined;
    case StudioFaultKind.changeExpired:
      return StudioBlockState.changeExpired;
    case StudioFaultKind.lateReassign:
      return StudioBlockState.lateReassign;
    case StudioFaultKind.assignOverdue:
    case null:
      break;
  }
  return s.changeRequest?.status == ChangeRequestStatus.pending
      ? StudioBlockState.changePending
      : StudioBlockState.assigned;
}

/// Whether the customer may still ask once to change who shoots [b]
/// (Decision 13): assigned, confirmed, before the start, not asked yet.
bool canRequestAssigneeChange(Booking b, DateTime now) {
  final s = b.studio;
  return s != null &&
      s.assignStatus == StudioAssignStatus.assigned &&
      s.assigneeId != null &&
      _isActive(b.status) &&
      now.isBefore(startsAtOf(b)) &&
      s.changeRequest == null;
}
