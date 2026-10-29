// lib/features/events/tickets_tab.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/passes/pass_providers.dart';
import 'package:photobooking/data/passes/pass_repository.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/disputes/dispute_entry.dart';
import 'package:photobooking/features/entry/entry_rules.dart';
import 'package:photobooking/features/events/event_links.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/payments/refund_account_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Hours before the start up to which cancelling a paid ticket refunds all of
/// it (plan 10c Decision 11).
const _fullRefundHours = 48;

typedef TicketView = ({
  TicketState state,
  String? statusLabel,
  int? refundPercentIfCancelled,
});

/// Pure: how one registration is drawn. `refundPercentIfCancelled` is null
/// for a free ticket (no percent is shown), else 100 or 0 (the server's
/// `ticketRefundPercent`, computed here for the label; the server decides).
TicketView ticketViewOf(
  EventRegistration r, {
  required DateTime now,
  required AppLocalizations l,
}) {
  // An entry ticket refunds all of it up to its visit day 00:00 minus the
  // cutoff (`entryRefundPercent`, 48 h by default; the snapshot carries no
  // other cutoff), nothing after.
  final refund = r.isFree
      ? null
      : r.isEntry
      ? (!now.isAfter(entryCutoffAt(r.visitDay!, _fullRefundHours)) ? 100 : 0)
      : (r.event.startsAt.difference(now) >=
                const Duration(hours: _fullRefundHours)
            ? 100
            : 0);
  // The event was cancelled with this ticket's money held: refund on its way.
  // An entry ticket's day was closed by its organizer (S11.04-entry).
  if (r.refundDue && r.status != RegistrationStatus.refunded) {
    return (
      state: TicketState.cancelled,
      statusLabel: r.isEntry ? l.s1104_dayClosed : l.ticketRefunding,
      refundPercentIfCancelled: null,
    );
  }
  switch (r.status) {
    case RegistrationStatus.held:
      if (r.holdExpired(now)) {
        return (
          state: TicketState.cancelled,
          statusLabel: l.ticketHoldExpired,
          refundPercentIfCancelled: null,
        );
      }
      return (
        state: TicketState.pendingPayment,
        statusLabel: null,
        refundPercentIfCancelled: refund,
      );
    case RegistrationStatus.paid:
      if (r.isCheckedIn) {
        return (
          state: TicketState.attended,
          statusLabel: r.isEntry
              ? l.s1104_checkedIn(formatHm(toVn(r.checkedInAt!)))
              : null,
          refundPercentIfCancelled: null,
        );
      }
      final over = !now.isBefore(r.event.endsAt);
      return (
        state: over ? TicketState.past : TicketState.upcoming,
        statusLabel: null,
        refundPercentIfCancelled: over ? null : refund,
      );
    case RegistrationStatus.cancelled:
      // A payment that came after the hold is refunded in full: say so.
      return (
        state: TicketState.cancelled,
        statusLabel: switch (r.refundStatus) {
          null => (r.refundPercent ?? 0) > 0 ? l.ticketRefunding : null,
          TicketRefundStatus.done => l.ticketCancelledRefunded,
          _ => l.ticketCancelledRefunding,
        },
        refundPercentIfCancelled: null,
      );
    case RegistrationStatus.refunded:
      // "Đang hoàn" until the gateway says done (a failed refund is with
      // staff: the money has not come back yet). No state: an older refund.
      final back =
          r.refundStatus == null || r.refundStatus == TicketRefundStatus.done;
      return (
        state: TicketState.cancelled,
        statusLabel: back ? l.ticketRefunded : l.ticketRefunding,
        refundPercentIfCancelled: null,
      );
  }
}

/// How often the tickets tab re-reads "now" (past state, "Báo vấn đề").
const ticketsTick = Duration(minutes: 1);

/// S11.04: the customer's event tickets, inside S05.01 "Vé sự kiện".
class EventTicketsTab extends ConsumerStatefulWidget {
  const EventTicketsTab({super.key, this.highlightId});

  /// A ticket to emphasise (the one just bought), else the soonest upcoming.
  /// Showing it as an upcoming ticket is also the moment S17.03 is offered.
  final String? highlightId;

  @override
  ConsumerState<EventTicketsTab> createState() => _EventTicketsTabState();
}

class _EventTicketsTabState extends ConsumerState<EventTicketsTab> {
  /// The highlight the primer was already requested for (once per highlight,
  /// not once per rebuild).
  String? _primerAskedFor;

  String? get highlightId => widget.highlightId;

  /// A paid ticket was cancelled with money back: a bank-transfer refund
  /// waits for the customer's account (S22.04). The registration does not
  /// carry the payment method, so the server decides: nothing waits for a
  /// wallet and no sheet opens. Opened from the tab, which outlives the
  /// ticket's row (a cancelled ticket moves down the list).
  void _afterRefundedCancel(EventRegistration r) {
    if (!mounted) return;
    unawaited(
      showRefundAccountSheet(context, ref, TicketRefund(r.eventId, r.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tickets = ref.watch(myTicketsProvider);
    // Ticks: a ticket turns past at its end, which opens "Báo vấn đề".
    final now =
        ref.watch(nowTickerProvider(ticketsTick)).value ??
        ref.read(clockProvider)();
    return ScreenCode(
      ScreenCodes.eventTickets,
      child: AsyncView<List<EventRegistration>>(
        value: tickets,
        skeleton: (_) => ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [TicketCard.skeleton()],
        ),
        onRetry: () => ref.invalidate(myTicketsProvider),
        isEmpty: (all) => all.isEmpty,
        empty: (_) => EmptyState(
          title: l.ticketsEmpty,
          body: '',
          actionLabel: l.ticketsBrowse,
          onAction: () => context.push('/events'),
        ),
        data: (_, all) => _list(context, all, now),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<EventRegistration> all,
    DateTime now,
  ) {
    final l = context.l10n;
    final views = {for (final r in all) r.id: ticketViewOf(r, now: now, l: l)};
    List<EventRegistration> of(bool Function(TicketView) f) => [
      for (final r in all)
        if (f(views[r.id]!)) r,
    ];
    final upcoming = of((v) => v.state == TicketState.upcoming)
      ..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
    final held = of((v) => v.state == TicketState.pendingPayment)
      ..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
    final rest = of(
      (v) =>
          v.state != TicketState.upcoming &&
          v.state != TicketState.pendingPayment,
    )..sort((a, b) => b.event.startsAt.compareTo(a.event.startsAt));
    final ordered = [...upcoming, ...held, ...rest];
    final emphasised = upcoming.any((r) => r.id == highlightId)
        ? highlightId
        : upcoming.firstOrNull?.id;

    // The ticket just bought is on screen: the meaningful action (spec
    // S17.03). Opening the tab without `highlight` asks nothing.
    final bought = highlightId == null
        ? null
        : upcoming.where((r) => r.id == highlightId).firstOrNull;
    if (bought != null && _primerAskedFor != highlightId) {
      _primerAskedFor = highlightId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            maybeAskForNotifications(
              context,
              ref,
              CustomerTicketPrimer(bought.event.title),
            ),
          );
        }
      });
    }

    return ListView.separated(
      key: const PageStorageKey('event-tickets'),
      padding: const EdgeInsets.all(AppSpace.s4),
      itemCount: ordered.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
      itemBuilder: (context, i) {
        final r = ordered[i];
        final expiresAt = r.holdExpiresAt;
        if (views[r.id]!.state == TicketState.pendingPayment &&
            expiresAt != null) {
          // "Thanh toán tiếp" while the hold runs, "Hết hạn" once it ends.
          return CountdownText(
            key: ValueKey(r.id),
            deadline: expiresAt,
            now: ref.read(clockProvider),
            builder: (context, left) => _TicketTile(
              registration: r,
              view: left > Duration.zero
                  ? views[r.id]!
                  : ticketViewOf(r, now: expiresAt, l: l),
              highlighted: r.id == emphasised,
              onRefundedCancel: _afterRefundedCancel,
            ),
          );
        }
        return _TicketTile(
          key: ValueKey(r.id),
          registration: r,
          view: views[r.id]!,
          highlighted: r.id == emphasised,
          onRefundedCancel: _afterRefundedCancel,
        );
      },
    );
  }
}

class _TicketTile extends ConsumerWidget {
  const _TicketTile({
    super.key,
    required this.registration,
    required this.view,
    required this.highlighted,
    required this.onRefundedCancel,
  });

  final EventRegistration registration;
  final TicketView view;
  final bool highlighted;

  /// Called after a cancel the server accepted with money back.
  final void Function(EventRegistration) onRefundedCancel;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final r = registration;
    final pct = view.refundPercentIfCancelled;
    final body = switch (pct) {
      null => l.ticketCancelFreeBody,
      0 => l.ticketNoRefund,
      _ => l.ticketRefundAmount(formatMoney(r.amount * pct ~/ 100)),
    };
    final done = await showConfirmSheet(
      context,
      title: l.ticketCancelConfirmTitle(r.event.title),
      body: body,
      confirmLabel: l.ticketCancel,
      keepLabel: l.ticketKeep,
      danger: true,
      onConfirm: () async {
        try {
          await ref
              .read(eventRepositoryProvider)
              .cancelRegistration(r.eventId, r.id);
        } catch (e) {
          throw _TicketError(
            eventErrorCodeOf(e) == 'conflict'
                ? l.ticketCancelUsed
                : l.registerError,
          );
        }
      },
    );
    if (done) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.ticketCancelDone)));
      if (pct != null && pct > 0) onRefundedCancel(r);
    }
  }

  /// S18.01 for a paid ticket inside its window; a sent dispute opens S18.02.
  Future<void> _reportProblem(BuildContext context, DateTime closesAt) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final r = registration;
    final starts = toVn(r.event.startsAt);
    final ends = toVn(r.event.endsAt);
    final id = await showOpenDisputeSheet(
      context,
      subject: DisputeSubject.ticket(eventId: r.eventId, registrationId: r.id),
      summary: DisputeSubjectSummary(
        title: r.event.title,
        subtitle:
            '${formatDay(starts)} · ${formatHm(starts)}–${formatHm(ends)}',
      ),
      closesAt: closesAt,
      origin: DisputeOrigin.ticket,
    );
    if (id == null || !context.mounted) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.disputeSent)));
    await context.push('/disputes/$id');
  }

  /// "Thanh toán tiếp": the same hold's payment step. Asks the server first
  /// (the gateway may already have it); then pushes S04.04 without extra, where
  /// it reads instructions with getPaymentInstructions.
  Future<void> _continuePayment(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final r = registration;
    final repo = ref.read(eventRepositoryProvider);
    try {
      final check = await repo.checkTicketPayment(r.eventId, r.id);
      if (check.paid || check.status != RegistrationStatus.held) {
        return; // the stream redraws the card
      }
      if (!context.mounted) {
        return;
      }
      context.push(payPathOf(TicketPay(r.eventId, r.id)));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.registerError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = registration;
    final pct = view.refundPercentIfCancelled;
    final launcher = ref.read(externalLauncherProvider);
    final pending = view.state == TicketState.pendingPayment;
    // A paid ticket from the end of its event until 24 h later (Decision 2).
    final disputeClosesAt = ticketDisputeClosesAt(r);
    // Like S05.02: the button appears at the end and goes 24 h later.
    final now =
        ref.watch(nowTickerProvider(ticketsTick)).value ??
        ref.read(clockProvider)();
    final canReport =
        disputeClosesAt != null &&
        !now.isBefore(r.event.endsAt) &&
        now.isBefore(disputeClosesAt);
    // The pass is private (Decision 8): read it for a ticket on screen
    // whose public legacy code is empty; it stays on the phone offline.
    final pass = r.ticketCode.isEmpty && view.state == TicketState.upcoming
        ? ref.watch(myPassProvider(PassRef.registration(r.eventId, r.id))).value
        : null;
    final code = r.ticketCode.isNotEmpty
        ? r.ticketCode
        : (pass == null ? '' : passDisplay(pass));
    final entry = r.isEntry;
    final starts = toVn(r.event.startsAt);
    final cutoff = entry ? entryCutoffLabel(r.visitDay!, _fullRefundHours) : '';
    final card = TicketCard(
      ticket: TicketCardData(
        ticketCode: code,
        eventTitle: r.event.title,
        typeLabel: r.event.type.label(l),
        startsAt: starts,
        quantity: r.quantity,
        state: view.state,
        placeName: r.event.locationName,
        metaLine: entry
            ? '${formatDay(starts)} · ${formatHm(starts)}–${formatHm(toVn(r.event.endsAt))} · ${l.ticketCount(r.quantity)}'
            : null,
        hint: entry ? l.s1104_gateHint : null,
        detail: entry && r.items.isNotEmpty ? entryItemsLine(r.items) : null,
      ),
      cancelEnabled: !(entry && pct == 0),
      highlighted: highlighted,
      // Mock S11.04: only the upcoming ticket is the big card; the others
      // (pending, expired, past, cancelled, refunded) are compact rows.
      compact: view.state != TicketState.upcoming,
      statusLabel: view.statusLabel,
      cancelLabel: pct == null
          ? null
          : entry
          ? (pct == 0 ? l.s1104_pastCutoff : l.s1104_cancelUntil(cutoff))
          : (pct == 0 ? l.ticketCancelNoRefund : l.ticketCancelRefund(pct)),
      qrHeroTag: 'ticket-qr-${r.id}',
      onQrTap: code.isEmpty ? null : () => _showQr(context, r, code),
      onCancel: () => _cancel(context, ref),
      onPay: pending ? () => _continuePayment(context, ref) : null,
      payLabel: l.ticketPayContinue,
      onReportProblem: canReport
          ? () => _reportProblem(context, disputeClosesAt)
          : null,
      // The group chat opens once the ticket is paid (a free ticket is paid
      // at once); an entry ticket has none.
      onOpenChat: r.status == RegistrationStatus.paid && !entry
          ? () => context.push('/e/${r.eventId}/chat')
          : null,
      onDirections: () => launcher.open(
        eventDirectionsUri(
          lat: r.event.lat,
          lng: r.event.lng,
          placeName: r.event.locationName,
        ),
      ),
      onAddToCalendar: () => launcher.open(
        eventCalendarUri(
          title: r.event.title,
          startsAt: r.event.startsAt,
          endsAt: r.event.endsAt,
          location: r.event.locationName,
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () => context.push('/e/${r.eventId}'),
      child: card,
    );
  }

  void _showQr(BuildContext context, EventRegistration r, String code) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        pageBuilder: (_, _, _) =>
            _QrFullScreen(code: code, heroTag: 'ticket-qr-${r.id}'),
      ),
    );
  }
}

/// Error whose text is already the friendly message (the confirm sheet shows
/// `toString()` in a SnackBar).
class _TicketError implements Exception {
  const _TicketError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The QR alone, big, on white: easy to scan from across a table, with the
/// screen at full brightness while it is open (S30 Decision 19).
class _QrFullScreen extends ConsumerStatefulWidget {
  const _QrFullScreen({required this.code, required this.heroTag});

  final String code;
  final String heroTag;

  @override
  ConsumerState<_QrFullScreen> createState() => _QrFullScreenState();
}

class _QrFullScreenState extends ConsumerState<_QrFullScreen> {
  late final ScreenBrightness _brightness = ref.read(screenBrightnessProvider);

  String get code => widget.code;
  String get heroTag => widget.heroTag;

  @override
  void initState() {
    super.initState();
    unawaited(_brightness.raise());
  }

  @override
  void dispose() {
    unawaited(_brightness.restore());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final side = (width - AppSpace.s8).clamp(160.0, 360.0);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: QrImageView(
                      key: const Key('ticket-qr-full'),
                      data: code,
                      size: side,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(AppSpace.s4),
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      semanticsLabel: l.ticketCodeSemantics(code),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                AppButton.outline(
                  l.ticketQrClose,
                  onPressed: () => Navigator.of(context).pop(),
                  size: AppButtonSize.small,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
