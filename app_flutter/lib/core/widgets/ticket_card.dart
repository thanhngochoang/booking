import 'package:flutter/material.dart';
import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/glass_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum TicketState { upcoming, pendingPayment, past, cancelled }

@immutable
class TicketCardData {
  const TicketCardData({
    required this.ticketCode,
    required this.eventTitle,
    required this.typeTag,
    required this.startsAt,
    required this.quantity,
    required this.state,
    this.placeName,
  });

  final String ticketCode;
  final String eventTitle;
  final String typeTag;
  final DateTime startsAt;
  final int quantity;
  final TicketState state;
  final String? placeName;
}

class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    this.onCancel,
    this.onDirections,
    this.onAddToCalendar,
    this.onPay,
  });

  final TicketCardData ticket;
  final VoidCallback? onCancel;
  final VoidCallback? onDirections;
  final VoidCallback? onAddToCalendar;
  final VoidCallback? onPay;

  static Widget skeleton() => const _TicketCardSkeleton();

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final l = context.l10n;

    final (statusBg, statusFg, statusLabel) = switch (ticket.state) {
      TicketState.upcoming => (
        AppColors.bookingAccepted,
        AppColors.foregroundInverse,
        l.ticketUpcoming,
      ),
      TicketState.pendingPayment => (
        AppColors.bookingOpened,
        AppColors.foreground,
        l.ticketPendingPayment,
      ),
      TicketState.past => (
        AppColors.bookingClosed,
        AppColors.foregroundInverse,
        l.ticketPast,
      ),
      TicketState.cancelled => (
        AppColors.bookingDenied,
        AppColors.foregroundInverse,
        l.ticketCancelled,
      ),
    };

    final isUpcoming = ticket.state == TicketState.upcoming;
    final isPending = ticket.state == TicketState.pendingPayment;
    final isDimmed =
        ticket.state == TicketState.past || ticket.state == TicketState.cancelled;

    Widget cardContent = GlassCard(
      highlight: isUpcoming,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top tag & status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${ticket.typeTag}',
                  style: TextStyle(
                    fontSize: AppText.xs,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                      vertical: AppSpace.s1,
                    ),
                    child: Text(
                      statusLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: AppText.xs,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: statusFg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            // Title
            Text(
              ticket.eventTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            // Date / Time · Quantity
            Text(
              '${formatDay(ticket.startsAt)} · ${_two(ticket.startsAt.hour)}:${_two(ticket.startsAt.minute)} · ${l.ticketCount(ticket.quantity)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppText.sm,
                color: fgSec,
              ),
            ),
            if (ticket.placeName != null && ticket.placeName!.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s1),
              Text(
                ticket.placeName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppText.sm,
                  color: fgSec,
                ),
              ),
            ],
            if (isUpcoming) ...[
              const SizedBox(height: AppSpace.s4),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: QrImageView(
                    data: ticket.ticketCode,
                    size: 112,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    semanticsLabel: l.ticketCodeSemantics(ticket.ticketCode),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(AppSpace.s2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Center(
                child: SelectableText(
                  ticket.ticketCode,
                  style: TextStyle(
                    fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: AppText.md,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton.outline(
                    l.ticketDirections,
                    onPressed: onDirections,
                    size: AppButtonSize.small,
                  ),
                  AppButton.outline(
                    l.ticketAddToCalendar,
                    onPressed: onAddToCalendar,
                    size: AppButtonSize.small,
                  ),
                  AppButton.text(
                    l.ticketCancel,
                    onPressed: onCancel,
                    size: AppButtonSize.small,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ),
            ] else if (isPending) ...[
              const SizedBox(height: AppSpace.s4),
              AppButton.primary(
                l.ticketPay,
                onPressed: onPay,
                size: AppButtonSize.small,
              ),
            ],
          ],
        ),
      ),
    );

    if (isDimmed) {
      return Opacity(
        opacity: 0.55,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

class _TicketCardSkeleton extends StatelessWidget {
  const _TicketCardSkeleton()
      : super(key: const ValueKey('ticket_card_skeleton'));

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeleton.line(width: 64, height: 14),
                AppSkeleton.box(width: 80, height: 22, radius: AppRadius.sm),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            AppSkeleton.line(height: 26),
            const SizedBox(height: AppSpace.s2),
            AppSkeleton.line(width: 200, height: 17),
            const SizedBox(height: AppSpace.s1),
            AppSkeleton.line(width: 140, height: 17),
            const SizedBox(height: AppSpace.s4),
            Center(
              child: AppSkeleton.box(
                width: 112,
                height: 112,
                radius: AppRadius.md,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Center(
              child: AppSkeleton.line(width: 110, height: 23),
            ),
            const SizedBox(height: AppSpace.s4),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  height: 48,
                  child: Center(
                    child: AppSkeleton.box(
                      width: 86,
                      height: 38,
                      radius: AppRadius.control,
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Center(
                    child: AppSkeleton.box(
                      width: 114,
                      height: 38,
                      radius: AppRadius.control,
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Center(
                    child: AppSkeleton.box(
                      width: 68,
                      height: 38,
                      radius: AppRadius.control,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
