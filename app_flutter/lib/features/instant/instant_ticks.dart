// When the customer's screen asks the server to settle its timers
// (`tickInstantRequest`, Decision 6). Pure: the flow screen schedules them.
import 'package:photobooking/data/instant/instant_models.dart';

/// The grace after the last pending offer expires, so the server sees it
/// expired.
const kInstantOfferTickGrace = Duration(seconds: 1);

/// The latest `expiresAt` of [r]'s pending invites (S13.03 counts down to
/// it); null when nobody is still looking.
DateTime? latestPendingExpiry(InstantRequest r) {
  DateTime? latest;
  for (final o in r.offers) {
    final at = o.expiresAt;
    if (o.outcome != OfferOutcome.pending || at == null) continue;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
}

/// The instants at which [r] needs a tick, soonest first:
/// - `searching`: 1 s after the latest pending offer's `expiresAt`, and
///   `searchDeadlineAt`;
/// - `choosing` once committed (offers went out at least once):
///   `searchDeadlineAt`;
/// - `in_progress`: `shootEndsAt`.
///
/// Everything else has no deadline of its own (the 15-minute clock and app
/// resume settle it).
List<DateTime> instantTickDeadlines(InstantRequest r) {
  final out = <DateTime>[];
  void add(DateTime? at) {
    if (at != null) out.add(at);
  }

  switch (r.status) {
    case InstantStatus.searching:
      add(latestPendingExpiry(r)?.add(kInstantOfferTickGrace));
      add(r.searchDeadlineAt);
    case InstantStatus.choosing when r.committed:
      add(r.searchDeadlineAt);
    case InstantStatus.inProgress:
      add(r.shootEndsAt);
    default:
      break;
  }
  return out..sort();
}

/// How long until [r]'s next tick: null without a deadline, [Duration.zero]
/// when it has passed.
Duration? nextTickDelay(InstantRequest r, DateTime now) {
  final deadlines = instantTickDeadlines(r);
  if (deadlines.isEmpty) return null;
  final d = deadlines.first.difference(now);
  return d.isNegative ? Duration.zero : d;
}
