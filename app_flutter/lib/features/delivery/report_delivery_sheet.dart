import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The server's minimum description length (graphemes, after trim).
const _minDescription = 10;

/// S05.06 "Báo vấn đề với ảnh gốc": opens a dispute on the booking's delivery
/// milestone (the server picks it from the `approved` state). Interim UI until
/// S18.01 (Task 11) replaces it through `/b/:id/dispute?from=delivery`.
Future<bool?> showReportDeliverySheet(
  BuildContext context, {
  required Booking booking,
}) {
  final l10n = context.l10n;
  final container = ProviderScope.containerOf(context, listen: false);

  // Minted once per sheet: a retry re-sends the same id and the server
  // answers with the same dispute.
  final disputeId = newUlid();
  final selected = ValueNotifier<({DisputeReason reason, String text})?>(null);
  final isValid = ValueNotifier<bool>(false);

  return showConfirmSheet(
    context,
    title: l10n.deliveryReportSheetTitle,
    content: _ReportDeliveryContent(selected: selected, isValid: isValid),
    confirmLabel: l10n.deliveryReportButton,
    keepLabel: l10n.cancelKeep,
    danger: true,
    confirmEnabled: isValid,
    onConfirm: () async {
      final pick = selected.value;
      if (pick == null) return;
      try {
        await container
            .read(disputeRepositoryProvider)
            .open(
              DisputeDraft(
                disputeId: disputeId,
                subjectType: DisputeSubjectType.booking,
                subjectId: booking.id,
                reason: pick.reason,
                description: pick.text,
              ),
            );
      } catch (e) {
        throw _DisputeActionError(_disputeErrorText(e, l10n));
      }
    },
  );
}

String _disputeErrorText(Object error, AppLocalizations l10n) =>
    switch (error) {
      DisputeError(code: 'not_eligible') => l10n.disputeErrNotEligible,
      DisputeError(code: 'deadline_passed') => l10n.disputeErrDeadline,
      DisputeError(code: 'conflict') => l10n.disputeErrConflict,
      _ => l10n.disputeErrGeneric,
    };

/// Core's confirmation sheet shows `error.toString()` in its SnackBar.
class _DisputeActionError implements Exception {
  const _DisputeActionError(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ReportDeliveryContent extends StatefulWidget {
  const _ReportDeliveryContent({required this.selected, required this.isValid});

  final ValueNotifier<({DisputeReason reason, String text})?> selected;
  final ValueNotifier<bool> isValid;

  @override
  State<_ReportDeliveryContent> createState() => _ReportDeliveryContentState();
}

class _ReportDeliveryContentState extends State<_ReportDeliveryContent> {
  int? _selectedIndex;
  String _otherText = '';

  /// The chips in order, each with the dispute reason it sends; the label of
  /// a fixed reason is also its description.
  List<(DisputeReason, String)> _reasons() {
    final l10n = context.l10n;
    return [
      (DisputeReason.linkBroken, l10n.deliveryReportReasonBrokenLink),
      (DisputeReason.photosMissing, l10n.deliveryReportReasonMissingFiles),
      (DisputeReason.notAsSample, l10n.deliveryReportReasonWrongFiles),
      (DisputeReason.other, l10n.deliveryReportReasonOther),
    ];
  }

  void _update() {
    final index = _selectedIndex;
    if (index == null) {
      widget.selected.value = null;
      widget.isValid.value = false;
      return;
    }
    final (reason, label) = _reasons()[index];
    final text = reason == DisputeReason.other ? _otherText.trim() : label;
    final valid = text.characters.length >= _minDescription;
    widget.selected.value = valid ? (reason: reason, text: text) : null;
    widget.isValid.value = valid;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReasonPicker(
          reasons: [for (final (_, label) in _reasons()) label],
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
