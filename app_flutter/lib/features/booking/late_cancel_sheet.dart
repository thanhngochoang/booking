// S05.08: confirmation sheet for cancelling the delivery part when the
// provider is overdue (#207).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/features/booking/booking_errors.dart';

/// Result of S05.08 ([showLateCancelSheet], Decision 14).
enum LateCancelOutcome {
  cancelled,
  kept,
  alreadyDelivered,
  notLate,
  disputed,

  /// Refused for another reason (already `completed`, e.g. the first call
  /// committed but its response was lost; or no milestones): nothing left to
  /// cancel, so the sheet closes and S05.02 refreshes.
  notEligible,
  failed,
}

/// Opens the S05.08 confirmation sheet over [showAppSheet].
///
/// Terminal refusals ([LateCancelOutcome.alreadyDelivered],
/// [LateCancelOutcome.notLate], [LateCancelOutcome.disputed],
/// [LateCancelOutcome.notEligible]) close the sheet
/// so S05.02 can toast and refresh; transient errors keep the sheet open with
/// a SnackBar like [showConfirmSheet].
Future<LateCancelOutcome> showLateCancelSheet(
  BuildContext context, {
  required Booking booking,
  required String providerName,
  BookingMilestones? milestones,
}) {
  return showAppSheet<LateCancelOutcome>(
    context,
    builder: (_) => _LateCancelBody(
      booking: booking,
      providerName: providerName,
      milestones: milestones,
    ),
  ).then((v) => v ?? LateCancelOutcome.kept);
}

class _LateCancelBody extends ConsumerStatefulWidget {
  const _LateCancelBody({
    required this.booking,
    required this.providerName,
    this.milestones,
  });

  final Booking booking;
  final String providerName;
  final BookingMilestones? milestones;

  @override
  ConsumerState<_LateCancelBody> createState() => _LateCancelBodyState();
}

class _LateCancelBodyState extends ConsumerState<_LateCancelBody> {
  bool _running = false;

  void _handleKeep() {
    if (_running) return;
    Navigator.of(context).pop(LateCancelOutcome.kept);
  }

  Future<void> _handleConfirm() async {
    if (_running) return;
    setState(() => _running = true);
    final l10n = context.l10n;
    try {
      await ref
          .read(bookingRepositoryProvider)
          .cancelLateDelivery(bookingId: widget.booking.id);
      if (mounted) {
        Navigator.of(context).pop(LateCancelOutcome.cancelled);
      }
    } catch (e) {
      if (!mounted) return;
      final err = bookingErrorOf(e);
      switch (err) {
        case BookingErrorCode.alreadyDelivered:
          Navigator.of(context).pop(LateCancelOutcome.alreadyDelivered);
        case BookingErrorCode.notLate:
          Navigator.of(context).pop(LateCancelOutcome.notLate);
        case BookingErrorCode.conflict:
          Navigator.of(context).pop(LateCancelOutcome.disputed);
        case BookingErrorCode.notEligible:
          Navigator.of(context).pop(LateCancelOutcome.notEligible);
        default:
          setState(() => _running = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(bookingErrorText(e, l10n))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final name = widget.providerName.isEmpty
        ? l10n.earningsCustomerFallback
        : widget.providerName;

    final ms =
        widget.milestones ??
        ref.watch(bookingMilestonesProvider(widget.booking.id)).value;
    final net = (widget.booking.deposit - (widget.booking.depositRefunded ?? 0))
        .clamp(0, widget.booking.deposit);
    final shootAmount = ms?.shootAmount ?? (net ~/ 2);
    final deliveryAmount = ms?.deliveryAmount ?? (net - (net ~/ 2));

    return ScreenCode(
      ScreenCodes.cancelLateDelivery,
      child: PopScope(
        canPop: !_running,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _running ? (_) {} : null,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s4,
              ),
              child: Column(
                key: const Key('late-cancel-sheet'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.lateCancelTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s3),
                  PolicyTable(
                    rows: [
                      PolicyRow(
                        when: l10n.lateCancelRefundRow,
                        outcome: formatMoney(deliveryAmount),
                      ),
                      PolicyRow(
                        when: l10n.lateCancelKeepRow(name),
                        outcome: formatMoney(shootAmount),
                      ),
                    ],
                    activeIndex: 0,
                  ),
                  const SizedBox(height: AppSpace.s3),
                  Text(
                    l10n.lateCancelNote(name),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.outline(
                          l10n.lateCancelWait,
                          key: const Key('late-cancel-wait'),
                          onPressed: _running ? null : _handleKeep,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(
                        child: AppButton.danger(
                          l10n.lateCancelConfirm,
                          key: const Key('late-cancel-confirm'),
                          loading: _running,
                          onPressed: _running ? null : _handleConfirm,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
