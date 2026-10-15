// lib/features/events/event_join_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';

/// What the bottom bar of S11.02 offers the viewer.
enum EventJoinState {
  join,
  viewTicket,
  manage,
  soldOut,
  closed,
  cancelled,
  ended,
  paymentsSoon,
}

/// Paid tickets have their payment step since plan 10c Task 10 (Decision 27).
/// A build can still switch it off: a paid event then shows its price and a
/// disabled "Sắp mở thanh toán".
final eventPaymentsReadyProvider = Provider<bool>((_) => true);

/// Pure: which action the bar shows. A cancelled event wins over everything;
/// managers and ticket holders see their own action even when the event is
/// full or closed.
EventJoinState eventJoinState(
  EventDetail event,
  EventRegistration? registration, {
  required String uid,
  StaffRole? role,
  required DateTime now,
  required bool paymentsReady,
}) {
  final s = event.summary;
  if (s.status == EventStatus.cancelled) {
    return EventJoinState.cancelled;
  }
  if (event.isManagedBy(uid, role)) {
    return EventJoinState.manage;
  }
  // A lapsed hold no longer holds a seat: the viewer may register again.
  if (registration != null &&
      registration.isActive &&
      !registration.holdExpired(now)) {
    return EventJoinState.viewTicket;
  }
  if (s.status == EventStatus.completed || !now.isBefore(event.endsAt)) {
    return EventJoinState.ended;
  }
  if (s.status == EventStatus.full || s.seatsLeft == 0) {
    return EventJoinState.soldOut;
  }
  if (s.status == EventStatus.closed ||
      now.isAfter(event.registrationDeadline)) {
    return EventJoinState.closed;
  }
  if (!s.isFree && !paymentsReady) {
    return EventJoinState.paymentsSoon;
  }
  return EventJoinState.join;
}

/// Fixed bottom bar of S11.02: price (or the free tag) and the one action.
class EventJoinBar extends StatelessWidget {
  const EventJoinBar({
    super.key,
    required this.event,
    required this.state,
    required this.onJoin,
    required this.onViewTicket,
    required this.onManage,
    this.busy = false,
  });

  final EventDetail event;
  final EventJoinState state;
  final VoidCallback onJoin;
  final VoidCallback onViewTicket;
  final VoidCallback onManage;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.color;
    final free = event.summary.isFree;

    final Widget action = switch (state) {
      EventJoinState.join => AppButton.primary(
        l.eventJoin,
        key: const Key('event-join'),
        loading: busy,
        onPressed: busy ? null : onJoin,
      ),
      EventJoinState.paymentsSoon => AppButton.primary(
        l.eventPaymentsSoon,
        key: const Key('event-join'),
        onPressed: null,
      ),
      EventJoinState.viewTicket => AppButton.primary(
        l.eventViewTicket,
        key: const Key('event-view-ticket'),
        onPressed: onViewTicket,
      ),
      EventJoinState.manage => AppButton.primary(
        l.eventManage,
        key: const Key('event-manage'),
        onPressed: onManage,
      ),
      EventJoinState.soldOut => _StatusText(l.eventSoldOut),
      EventJoinState.closed => _StatusText(l.eventClosed),
      EventJoinState.ended => _StatusText(l.eventEnded),
      EventJoinState.cancelled => const SizedBox.shrink(),
    };

    return AppFooterBar(
      child: Row(
        children: [
          Flexible(
            flex: 34,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (free)
                  const Align(alignment: Alignment.centerLeft, child: FreeTag())
                else ...[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatMoney(event.summary.priceVnd),
                      key: const Key('event-price'),
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    l.eventPerPerson,
                    style: TextStyle(fontSize: AppText.xs, color: secondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Flexible(flex: 66, child: action),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      text,
      key: const Key('event-status-text'),
      textAlign: TextAlign.end,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}
