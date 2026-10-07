// lib/features/events/tickets_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/features/events/event_links.dart';
import 'package:photobooking/features/events/ticket_payment_sheet.dart';
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
  final refund = r.isFree
      ? null
      : (r.event.startsAt.difference(now) >=
                const Duration(hours: _fullRefundHours)
            ? 100
            : 0);
  // The event was cancelled with this ticket's money held: refund on its way.
  if (r.refundDue && r.status != RegistrationStatus.refunded) {
    return (
      state: TicketState.cancelled,
      statusLabel: l.ticketRefunding,
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
          statusLabel: null,
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

String _typeTag(EventRegistration r) => r.event.type.code.replaceAll('_', '');

/// S11.04: the customer's event tickets, inside S05.01 "Vé sự kiện".
class EventTicketsTab extends ConsumerWidget {
  const EventTicketsTab({super.key, this.highlightId});

  /// A ticket to emphasise (the one just bought), else the soonest upcoming.
  final String? highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tickets = ref.watch(myTicketsProvider);
    final now = ref.watch(clockProvider)();
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
        data: (_, all) => _list(context, ref, all, now),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
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

    final hint = upcoming.isNotEmpty ? 1 : 0;
    return ListView.separated(
      key: const PageStorageKey('event-tickets'),
      padding: const EdgeInsets.all(AppSpace.s4),
      itemCount: ordered.length + hint,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
      itemBuilder: (context, index) {
        if (hint == 1 && index == 0) {
          return Text(
            l.ticketShowHint,
            key: const Key('tickets-hint'),
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        final i = index - hint;
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
            ),
          );
        }
        return _TicketTile(
          key: ValueKey(r.id),
          registration: r,
          view: views[r.id]!,
          highlighted: r.id == emphasised,
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
  });

  final EventRegistration registration;
  final TicketView view;
  final bool highlighted;

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
    }
  }

  /// "Thanh toán tiếp": the same hold's payment step. Asks the server first
  /// (the gateway may already have it); then the fake sheet, or with real
  /// payments the gateway's pay URL for the same hold.
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
      var paymentId = r.paymentId;
      String? payUrl;
      if (ref.read(realPaymentsProvider)) {
        // No provider: the server keeps the one of the hold's payment (the
        // method the customer chose on S11.03).
        final again = await repo.register(
          r.eventId,
          quantity: r.quantity,
          name: r.userName,
        );
        paymentId = again.paymentId ?? paymentId;
        payUrl = again.payUrl;
      }
      if (paymentId == null || !context.mounted) {
        return;
      }
      await openTicketPayment(
        context,
        ref,
        paymentId: paymentId,
        amountVnd: r.amount,
        payUrl: payUrl,
      );
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
    final card = TicketCard(
      ticket: TicketCardData(
        ticketCode: r.ticketCode,
        eventTitle: r.event.title,
        typeTag: _typeTag(r),
        startsAt: toVn(r.event.startsAt),
        quantity: r.quantity,
        state: view.state,
        placeName: r.event.locationName,
      ),
      highlighted: highlighted,
      // Mock S11.04: only the upcoming ticket is the big card; the others
      // (pending, expired, past, cancelled, refunded) are compact rows.
      compact: view.state != TicketState.upcoming,
      statusLabel: view.statusLabel,
      cancelLabel: pct == null
          ? null
          : (pct == 0 ? l.ticketCancelNoRefund : l.ticketCancelRefund(pct)),
      qrHeroTag: 'ticket-qr-${r.id}',
      onQrTap: () => _showQr(context, r),
      onCancel: () => _cancel(context, ref),
      onPay: pending ? () => _continuePayment(context, ref) : null,
      payLabel: l.ticketPayContinue,
      // The group chat opens once the ticket is paid (a free ticket is paid at once).
      onOpenChat: r.status == RegistrationStatus.paid
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

  void _showQr(BuildContext context, EventRegistration r) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        pageBuilder: (_, _, _) =>
            _QrFullScreen(code: r.ticketCode, heroTag: 'ticket-qr-${r.id}'),
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

/// The QR alone, big, on white: easy to scan from across a table. The system
/// brightness is not touched (no plugin; ledgered).
class _QrFullScreen extends StatelessWidget {
  const _QrFullScreen({required this.code, required this.heroTag});

  final String code;
  final String heroTag;

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
