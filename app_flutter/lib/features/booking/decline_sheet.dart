// S06.03: the photographer declines a new request.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/features/booking/booking_errors.dart';

/// Shortest "Lý do khác" text the red button accepts (spec S06.03).
const declineReasonMinLength = 5;

/// Longest reason text sent with a decline.
const declineReasonMaxLength = 200;

/// Opens the decline confirmation for [booking] over core's
/// [showConfirmSheet]. Returns true after the server accepted the decline.
///
/// A reason is required: the red button stays disabled until one of the
/// fixed reasons is chosen, or "Lý do khác" has at least
/// [declineReasonMinLength] characters. The customer gets the full deposit
/// back and sees the reason.
Future<bool?> showDeclineSheet(
  BuildContext context, {
  required Booking booking,
  required String customerName,
}) {
  final l10n = context.l10n;
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(bookingRepositoryProvider);
  // Written by the content, read by the sheet's button and its onConfirm.
  final reason = ValueNotifier<String?>(null);
  final valid = ValueNotifier<bool>(false);
  return showConfirmSheet(
    context,
    title: l10n.declineTitle(customerName),
    content: _DeclineContent(
      booking: booking,
      customerName: customerName,
      reason: reason,
      valid: valid,
    ),
    confirmLabel: l10n.declineConfirm,
    keepLabel: l10n.declineBack,
    danger: true,
    confirmEnabled: valid,
    onConfirm: () => withBookingErrorText(
      l10n,
      () => repo.transitionBooking(
        bookingId: booking.id,
        action: BookingAction.decline.code,
        reason: reason.value,
      ),
    ),
  );
}

/// What the decline sheet shows above its two buttons: the reasons (radio)
/// and the refund line.
class _DeclineContent extends StatefulWidget {
  const _DeclineContent({
    required this.booking,
    required this.customerName,
    required this.reason,
    required this.valid,
  });

  final Booking booking;
  final String customerName;
  final ValueNotifier<String?> reason;
  final ValueNotifier<bool> valid;

  @override
  State<_DeclineContent> createState() => _DeclineContentState();
}

class _DeclineContentState extends State<_DeclineContent> {
  int? _selected;
  String _otherText = '';

  List<String> _reasons() {
    final l10n = context.l10n;
    return [
      l10n.declineReasonBusy,
      l10n.declineReasonArea,
      l10n.declineReasonService,
      l10n.declineReasonOther,
    ];
  }

  /// The fixed reason's label, or the typed text for "Lý do khác" (trimmed,
  /// capped); null until a valid reason is chosen.
  void _publish() {
    final reasons = _reasons();
    final i = _selected;
    String? value;
    if (i != null) {
      final label = reasons[i];
      if (label == context.l10n.declineReasonOther) {
        final typed = _otherText.trim();
        value = typed.length < declineReasonMinLength
            ? null
            : typed.length > declineReasonMaxLength
            ? typed.substring(0, declineReasonMaxLength).trimRight()
            : typed;
      } else {
        value = label;
      }
    }
    widget.reason.value = value;
    widget.valid.value = value != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ScreenCode(
      ScreenCodes.declineRequest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReasonPicker(
            reasons: _reasons(),
            selected: _selected,
            style: ReasonPickerStyle.radio,
            otherLabel: l10n.declineReasonOther,
            otherMinLength: declineReasonMinLength,
            otherMaxLength: declineReasonMaxLength,
            onSelected: (i) {
              setState(() => _selected = i);
              _publish();
            },
            onOtherText: (text) {
              _otherText = text;
              _publish();
            },
          ),
          const SizedBox(height: AppSpace.s3),
          Text(
            l10n.declineRefundNote(
              widget.customerName,
              formatMoney(widget.booking.deposit),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: dark
                  ? AppColorsDark.foregroundSecondary
                  : AppColors.foregroundSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
