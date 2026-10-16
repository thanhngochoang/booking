// lib/features/verification/widgets/verify_timeline.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/l10n/app_localizations.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// `9:12` in Vietnam (mock S21.02 writes the hour without a leading zero).
String verifyClock(DateTime instant) {
  final v = toVn(instant);
  return '${v.hour}:${_two(v.minute)}';
}

/// "9:12 hôm nay", "9:12 ngày mai", else "9:12 ngày 16/10", on the Vietnamese
/// calendar seen from [now] (mock `#S21.02-pending`, `-rejected`, `-approved`).
String verifyAt(DateTime instant, DateTime now, AppLocalizations l) {
  final time = verifyClock(instant);
  final day = vnDateKey(instant);
  if (day == vnDateKey(now)) {
    return l.verifyAtToday(time);
  }
  if (day == vnDateKey(now.add(const Duration(days: 1)))) {
    return l.verifyAtTomorrow(time);
  }
  return l.verifyAtDate(time, formatDayMonth(toVn(instant)));
}

/// "Hôm nay 9:12" on today's Vietnamese date, else "05/10 9:12" (timeline
/// rows, as the booking timeline).
String verifyWhen(DateTime instant, DateTime now, AppLocalizations l) {
  final time = verifyClock(instant);
  return vnDateKey(instant) == vnDateKey(now)
      ? l.timelineToday(time)
      : '${formatDayMonth(toVn(instant))} $time';
}

/// The S21.02-pending timeline: identity checked (method · masked name),
/// sent for review (time · rules accepted), then "Staff duyệt" as the current
/// step. The fee row ("Đã trả phí xác minh") is #203's (Decision 24).
class VerifyTimeline extends StatelessWidget {
  const VerifyTimeline({super.key, required this.state, required this.now});

  final VerificationState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final method = switch (state.identityMethod) {
      IdentityMethod.nfc => l.verifyMethodNfc,
      IdentityMethod.vneid || null => l.verifyMethodVneid,
    };
    final name = state.maskedName;
    final sent = state.submittedAt;
    return StatusTimeline(
      key: const Key('verify-timeline'),
      steps: [
        TimelineStep(
          title: l.verifyTlIdentity,
          subtitle: name == null
              ? method
              : l.verifyTlIdentityBody(method, name),
          state: TimelineStepState.done,
        ),
        TimelineStep(
          title: l.verifyTlSubmitted,
          subtitle: sent == null
              ? null
              : l.verifyTlSubmittedBody(verifyWhen(sent, now, l)),
          state: TimelineStepState.done,
        ),
        TimelineStep(
          title: l.verifyTlReview,
          subtitle: l.verifyTlReviewBody,
          state: TimelineStepState.current,
        ),
      ],
    );
  }
}
