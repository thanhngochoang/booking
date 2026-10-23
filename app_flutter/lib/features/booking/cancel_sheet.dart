// S05.03: cancel a booking (customer), its photographer variant and the
// customer's 100% cancel after a studio fault.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/features/booking/booking_errors.dart';
import 'package:photobooking/features/booking/booking_features.dart';

/// Longest reason text sent with a cancel.
const cancelReasonMaxLength = 200;

/// Opens the cancel confirmation for [booking] over core's [showConfirmSheet].
/// Returns true after the server accepted the cancel.
///
/// The refund shown follows the clock while the sheet is open; the server
/// computes the real refund from its own time when the cancel arrives.
Future<bool?> showCancelSheet(
  BuildContext context, {
  required Booking booking,
  required BookingRole role,
  required String counterpartName,
}) {
  final l10n = context.l10n;
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(bookingRepositoryProvider);
  // Written by the content, read when the red button is tapped. No listener
  // is ever attached, so it needs no dispose.
  final reason = ValueNotifier<String?>(null);
  return showConfirmSheet(
    context,
    title: role == BookingRole.customer
        ? l10n.cancelTitle
        : l10n.cancelTitlePhotographer(counterpartName),
    content: _CancelContent(
      booking: booking,
      role: role,
      counterpartName: counterpartName,
      reason: reason,
    ),
    confirmLabel: l10n.cancelConfirm,
    keepLabel: l10n.cancelKeep,
    danger: true,
    onConfirm: () => withBookingErrorText(
      l10n,
      () => repo.transitionBooking(
        bookingId: booking.id,
        action: BookingAction.cancel.code,
        reason: reason.value,
      ),
    ),
  );
}

/// The `studioFault` mode of S05.03 (mock S05.02-studio-late): the customer
/// cancels a studio booking the studio let down (Decision 12) and gets back
/// everything paid — one highlighted line "Hoàn 100% số đã trả", the
/// amount, a red "Huỷ và hoàn 100%" and "Giữ lịch". The server decides the
/// right again (`cancel_studio_fault`) and refunds from the held money.
/// Returns true after the server accepted the cancel.
Future<bool?> showStudioFaultCancelSheet(
  BuildContext context, {
  required Booking booking,
}) {
  final l10n = context.l10n;
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(bookingRepositoryProvider);
  return showConfirmSheet(
    context,
    title: l10n.cancelStudioFaultTitle,
    body: l10n.cancelStudioFaultBody,
    content: ScreenCode(
      ScreenCodes.cancelBooking,
      child: Column(
        key: const Key('studio-fault-cancel'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PolicyTable(
            rows: [
              PolicyRow(
                when: l10n.cancelStudioFaultLine,
                outcome: l10n.cancelRefund100,
              ),
            ],
            activeIndex: 0,
          ),
          const SizedBox(height: AppSpace.s3),
          MoneyBreakdown(
            lines: [
              MoneyLine(
                label: l10n.cancelYouGetBack,
                vnd: booking.deposit,
                style: MoneyLineStyle.strong,
              ),
            ],
          ),
        ],
      ),
    ),
    confirmLabel: l10n.cancelStudioFaultConfirm,
    keepLabel: l10n.cancelStudioFaultKeep,
    danger: true,
    onConfirm: () => withBookingErrorText(
      l10n,
      () => repo.transitionBooking(
        bookingId: booking.id,
        action: BookingAction.cancelStudioFault.code,
      ),
    ),
  );
}

/// What the cancel sheet shows above its two buttons.
class _CancelContent extends ConsumerStatefulWidget {
  const _CancelContent({
    required this.booking,
    required this.role,
    required this.counterpartName,
    required this.reason,
  });

  final Booking booking;
  final BookingRole role;
  final String counterpartName;
  final ValueNotifier<String?> reason;

  @override
  ConsumerState<_CancelContent> createState() => _CancelContentState();
}

class _CancelContentState extends ConsumerState<_CancelContent> {
  static const _tick = Duration(minutes: 1);

  int? _selected;
  String _otherText = '';

  List<String> _reasons() {
    final l10n = context.l10n;
    return widget.role == BookingRole.customer
        ? [
            l10n.cancelReasonPlans,
            l10n.cancelReasonFound,
            l10n.cancelReasonOther,
          ]
        : [
            l10n.cancelReasonSick,
            l10n.cancelReasonGear,
            l10n.cancelReasonOther,
          ];
  }

  /// The fixed reason's label, or the typed text for "Lý do khác" (trimmed,
  /// capped); null when nothing usable was chosen. A reason is optional.
  void _publish() {
    final reasons = _reasons();
    final i = _selected;
    String? value;
    if (i != null) {
      final label = reasons[i];
      if (label == context.l10n.cancelReasonOther) {
        final typed = _otherText.trim();
        value = typed.isEmpty
            ? null
            : typed.length > cancelReasonMaxLength
            ? typed.substring(0, cancelReasonMaxLength).trimRight()
            : typed;
      } else {
        value = label;
      }
    }
    widget.reason.value = value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = widget.booking;
    final customer = widget.role == BookingRole.customer;
    final now =
        ref.watch(nowTickerProvider(_tick)).value ?? ref.read(clockProvider)();

    final percent = refundPercentAt(b, now);
    final when = '${formatDayMonth(DateTime.parse(b.day))} ${b.start}';

    return ScreenCode(
      ScreenCodes.cancelBooking,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (customer) ...[
          PolicyTable(
            rows: [
              PolicyRow(
                when: l10n.cancelRow100(when),
                outcome: l10n.cancelRefund100,
              ),
              PolicyRow(when: l10n.cancelRow50, outcome: l10n.cancelRefund50),
              PolicyRow(when: l10n.cancelRow0, outcome: l10n.cancelRefund0),
            ],
            activeIndex: switch (percent) {
              100 => 0,
              50 => 1,
              _ => 2,
            },
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        MoneyBreakdown(
          lines: [
            customer
                ? MoneyLine(
                    label: l10n.cancelYouGetBack,
                    vnd: refundAmountAt(b, now),
                    style: MoneyLineStyle.strong,
                  )
                : MoneyLine(
                    label: l10n.cancelRefundPhotographer(
                      widget.counterpartName,
                    ),
                    vnd: b.deposit,
                    style: MoneyLineStyle.strong,
                  ),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        ReasonPicker(
          reasons: _reasons(),
          selected: _selected,
          style: ReasonPickerStyle.chips,
          otherLabel: l10n.cancelReasonOther,
          otherMaxLength: cancelReasonMaxLength,
          onSelected: (i) {
            setState(() => _selected = i);
            _publish();
          },
          onOtherText: (text) {
            _otherText = text;
            _publish();
          },
        ),
      ],
    ),
  );
}
}
