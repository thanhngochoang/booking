import 'package:flutter/material.dart';
import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/vn_time.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/widgets/date_block.dart';
import 'package:photobooking/core/widgets/event_card.dart';
import 'package:photobooking/core/widgets/glass_card.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum TicketState { upcoming, pendingPayment, past, attended, cancelled }

@immutable
class TicketCardData {
  const TicketCardData({
    required this.ticketCode,
    required this.eventTitle,
    required this.typeLabel,
    required this.startsAt,
    required this.quantity,
    required this.state,
    this.placeName,
  });

  final String ticketCode;
  final String eventTitle;

  /// The event type as words ("Photo walk"), shown in the tag pill.
  final String typeLabel;

  /// Vietnam wall-clock time of the start (`toVn` of the instant).
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
    this.onOpenChat,
    this.onQrTap,
    this.qrHeroTag,
    this.highlighted,
    this.statusLabel,
    this.cancelLabel,
    this.payLabel,
    this.compact = false,
  });

  final TicketCardData ticket;

  /// The mock's S11.04 row for every ticket but the upcoming one: date block,
  /// title, "n vé · place" and the badge; [onPay] adds a small "Thanh toán
  /// tiếp" under the text of a pending ticket. No QR, no other buttons.
  final bool compact;
  final VoidCallback? onCancel;
  final VoidCallback? onDirections;
  final VoidCallback? onAddToCalendar;
  final VoidCallback? onPay;

  /// "Vào nhóm chat" under the buttons of an upcoming ticket (spec S11.06
  /// entry point); hidden when null.
  final VoidCallback? onOpenChat;

  /// Tapping the QR (to show it full screen); the QR is not tappable when null.
  final VoidCallback? onQrTap;

  /// `Hero` tag shared with the full-screen QR.
  final Object? qrHeroTag;

  /// The bright border; defaults to true for an upcoming ticket. Pass false
  /// for all but the soonest ticket of a list.
  final bool? highlighted;

  /// Replaces the badge text (e.g. "Đã hoàn tiền" on a cancelled ticket).
  final String? statusLabel;

  /// Replaces "Huỷ vé" (e.g. "Huỷ vé · hoàn 100%").
  final String? cancelLabel;

  /// Replaces "Thanh toán" on a pending ticket (e.g. "Thanh toán tiếp").
  final String? payLabel;

  static Widget skeleton() => const _TicketCardSkeleton();

  Widget _qr(AppLocalizations l) {
    final qr = ClipRRect(
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
    );
    final hero = qrHeroTag == null ? qr : Hero(tag: qrHeroTag!, child: qr);
    if (onQrTap == null) {
      return hero;
    }
    return InkWell(
      key: const Key('ticket-qr'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onQrTap,
      child: hero,
    );
  }

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

    final (statusBg, statusFg, defaultLabel) = switch (ticket.state) {
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
      TicketState.attended => (
        AppColors.bookingClosed,
        AppColors.foregroundInverse,
        l.ticketAttended,
      ),
      TicketState.cancelled => (
        AppColors.bookingDenied,
        AppColors.foregroundInverse,
        l.ticketCancelled,
      ),
    };

    final isUpcoming = ticket.state == TicketState.upcoming;
    final isPending = ticket.state == TicketState.pendingPayment;
    final badgeLabel = statusLabel ?? defaultLabel;
    final isDimmed =
        ticket.state == TicketState.past ||
        ticket.state == TicketState.attended ||
        ticket.state == TicketState.cancelled;

    final badge = DecoratedBox(
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
          badgeLabel.toUpperCase(),
          key: const Key('ticket-badge'),
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            fontSize: AppText.xs,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: statusFg,
          ),
        ),
      ),
    );

    if (compact) {
      final place = ticket.placeName;
      final meta = place == null || place.isEmpty
          ? l.ticketCount(ticket.quantity)
          : '${l.ticketCount(ticket.quantity)} · $place';
      final row = GlassCard(
        key: const Key('ticket-compact'),
        highlight: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            children: [
              DateBlock(day: fromVnWallClock(ticket.startsAt)),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.eventTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppText.md,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppText.sm, color: fgSec),
                    ),
                    if (isPending && onPay != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      AppButton.primary(
                        payLabel ?? l.ticketPay,
                        key: const Key('ticket-pay'),
                        onPressed: onPay,
                        size: AppButtonSize.small,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: badge,
              ),
            ],
          ),
        ),
      );
      return isDimmed ? Opacity(opacity: 0.55, child: row) : row;
    }

    final meta =
        '${formatDay(ticket.startsAt)} · ${_two(ticket.startsAt.hour)}:${_two(ticket.startsAt.minute)} · ${l.ticketCount(ticket.quantity)}';
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: EventTypeTag(
                  ticket.typeLabel,
                  key: const Key('ticket-type'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ticket.eventTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: fg,
                ),
              ),
              const SizedBox(height: AppSpace.s1),
              Text(
                meta,
                key: const Key('ticket-meta'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppText.sm,
                  color: fgSec,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: badge,
        ),
      ],
    );

    // Mock S11.04: QR left; on its right the hint, a blank line, the code.
    final qrRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _qr(l),
        const SizedBox(width: AppSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.ticketShowHint,
                key: const Key('ticket-hint'),
                style: TextStyle(fontSize: AppText.sm, color: fgSec),
              ),
              const SizedBox(height: AppSpace.s3),
              SelectableText(
                ticket.ticketCode,
                style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // "Chỉ đường" outline, "Thêm vào lịch" secondary (mock `.btn.sec`:
    // glass-hi fill, hairline); stacked when large text would not fit.
    final directions = AppButton.outline(
      l.ticketDirections,
      key: const Key('ticket-directions'),
      onPressed: onDirections,
      size: AppButtonSize.small,
    );
    final calendar = AppButton.outline(
      l.ticketAddToCalendar,
      key: const Key('ticket-calendar'),
      onPressed: onAddToCalendar,
      size: AppButtonSize.small,
      style: OutlinedButton.styleFrom(
        backgroundColor: dark
            ? AppColorsDark.secondaryPressed
            : AppColors.surface,
        side: BorderSide(color: dark ? AppColorsDark.border : AppColors.border),
      ),
    );
    final buttons = LayoutBuilder(
      builder: (context, box) {
        final scale =
            MediaQuery.textScalerOf(context).scale(AppText.sm) / AppText.sm;
        if (box.maxWidth >= 240 * scale) {
          return Row(
            children: [
              Expanded(child: directions),
              const SizedBox(width: AppSpace.s2),
              Expanded(child: calendar),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [directions, calendar],
        );
      },
    );

    final cardContent = GlassCard(
      highlight: highlighted ?? isUpcoming,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (isUpcoming) ...[
              const SizedBox(height: AppSpace.s3),
              qrRow,
              const SizedBox(height: AppSpace.s3),
              buttons,
              if (onOpenChat != null)
                AppButton.outline(
                  l.registerOpenChat,
                  key: const Key('ticket-chat'),
                  icon: const AppIcon(AppIcons.chat, size: 16),
                  onPressed: onOpenChat,
                  size: AppButtonSize.small,
                ),
            ] else if (isPending && onPay != null) ...[
              const SizedBox(height: AppSpace.s3),
              AppButton.primary(
                payLabel ?? l.ticketPay,
                key: const Key('ticket-pay'),
                onPressed: onPay,
                size: AppButtonSize.small,
              ),
            ],
          ],
        ),
      ),
    );

    if (isDimmed) {
      return Opacity(opacity: 0.55, child: cardContent);
    }
    if (!isUpcoming || onCancel == null) {
      return cardContent;
    }
    // Mock: the cancel is a red text button under the card.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cardContent,
        AppButton.text(
          cancelLabel ?? l.ticketCancel,
          key: const Key('ticket-cancel'),
          onPressed: onCancel,
          size: AppButtonSize.small,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
        ),
      ],
    );
  }
}

class _TicketCardSkeleton extends StatelessWidget {
  const _TicketCardSkeleton()
    : super(key: const ValueKey('ticket_card_skeleton'));

  @override
  Widget build(BuildContext context) {
    Widget button() => Expanded(
      child: SizedBox(
        height: 48,
        child: Center(
          child: AppSkeleton.box(
            width: double.infinity,
            height: 38,
            radius: AppRadius.control,
          ),
        ),
      ),
    );
    // Same boxes as the upcoming card: tag, title, meta and badge; the QR row;
    // the two buttons; then the cancel line under the card.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          highlight: false,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppSkeleton.box(
                            width: 72,
                            height: 20,
                            radius: AppRadius.full,
                          ),
                          const SizedBox(height: 6),
                          AppSkeleton.line(widthFactor: 0.7, height: 22),
                          const SizedBox(height: AppSpace.s1),
                          AppSkeleton.line(widthFactor: 0.5, height: 17),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    AppSkeleton.box(
                      width: 80,
                      height: 14,
                      radius: AppRadius.sm,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: [
                    AppSkeleton.box(
                      width: 112,
                      height: 112,
                      radius: AppRadius.md,
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppSkeleton.line(widthFactor: 0.9, height: 14),
                          const SizedBox(height: AppSpace.s1),
                          AppSkeleton.line(widthFactor: 0.6, height: 14),
                          const SizedBox(height: AppSpace.s3),
                          AppSkeleton.line(widthFactor: 0.5, height: 17),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: [
                    button(),
                    const SizedBox(width: AppSpace.s2),
                    button(),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: Center(child: AppSkeleton.line(width: 120, height: 14)),
        ),
      ],
    );
  }
}
