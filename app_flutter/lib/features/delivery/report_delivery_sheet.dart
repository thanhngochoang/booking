import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/features/booking/booking_errors.dart';

Future<bool?> showReportDeliverySheet(
  BuildContext context, {
  required Booking booking,
}) {
  final l10n = context.l10n;
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(bookingRepositoryProvider);

  final selectedReason = ValueNotifier<String?>(null);
  final isValid = ValueNotifier<bool>(false);

  return showConfirmSheet(
    context,
    title: l10n.deliveryReportSheetTitle,
    content: _ReportDeliveryContent(
      selectedReason: selectedReason,
      isValid: isValid,
    ),
    confirmLabel: l10n.deliveryReportButton,
    keepLabel: l10n.cancelKeep,
    danger: true,
    confirmEnabled: isValid,
    onConfirm: () async {
      final reason = selectedReason.value;
      if (reason == null || reason.isEmpty) return;
      await withBookingErrorText(
        l10n,
        () => repo.openDispute(
          bookingId: booking.id,
          reason: reason,
        ),
      );
    },
  );
}

class _ReportDeliveryContent extends StatefulWidget {
  const _ReportDeliveryContent({
    required this.selectedReason,
    required this.isValid,
  });

  final ValueNotifier<String?> selectedReason;
  final ValueNotifier<bool> isValid;

  @override
  State<_ReportDeliveryContent> createState() => _ReportDeliveryContentState();
}

class _ReportDeliveryContentState extends State<_ReportDeliveryContent> {
  int? _selectedIndex;
  String _otherText = '';

  List<String> _reasons() {
    final l10n = context.l10n;
    return [
      l10n.deliveryReportReasonBrokenLink,
      l10n.deliveryReportReasonMissingFiles,
      l10n.deliveryReportReasonWrongFiles,
      l10n.deliveryReportReasonOther,
    ];
  }

  void _update() {
    final reasons = _reasons();
    final otherLabel = context.l10n.deliveryReportReasonOther;

    if (_selectedIndex == null) {
      widget.selectedReason.value = null;
      widget.isValid.value = false;
      return;
    }

    final reason = reasons[_selectedIndex!];
    if (reason == otherLabel) {
      final typed = _otherText.trim();
      if (typed.isEmpty) {
        widget.selectedReason.value = null;
        widget.isValid.value = false;
      } else {
        widget.selectedReason.value = typed;
        widget.isValid.value = true;
      }
    } else {
      widget.selectedReason.value = reason;
      widget.isValid.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReasonPicker(
          reasons: _reasons(),
          selected: _selectedIndex,
          style: ReasonPickerStyle.radio,
          otherLabel: l10n.deliveryReportReasonOther,
          onSelected: (i) {
            setState(() => _selectedIndex = i);
            _update();
          },
          onOtherText: (text) {
            _otherText = text;
            _update();
          },
        ),
      ],
    );
  }
}
