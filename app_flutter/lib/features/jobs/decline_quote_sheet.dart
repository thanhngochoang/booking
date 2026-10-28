// lib/features/jobs/decline_quote_sheet.dart
//
// Confirmation bottom sheet to decline a quote (Task 8, S15.04).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job_providers.dart';

Future<bool> showDeclineQuoteSheet(
  BuildContext context, {
  required String jobId,
  required String photographerId,
}) async {
  final l = context.l10n;
  final reasonNotifier = ValueNotifier<String>('');

  final confirmed = await showConfirmSheet(
    context,
    title: l.quoteDeclineTitle,
    content: _DeclineReasonField(reasonNotifier: reasonNotifier),
    confirmLabel: l.quoteDeclineConfirm,
    keepLabel: l.actionCancel,
    danger: true,
    onConfirm: () async {
      final container = ProviderScope.containerOf(context, listen: false);
      final repo = container.read(jobRepositoryProvider);
      final reasonText = reasonNotifier.value.trim();
      await repo.declineQuote(
        jobId,
        photographerId,
        reason: reasonText.isNotEmpty ? reasonText : null,
      );
    },
  );

  if (confirmed && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.quoteDeclinedToast)),
    );
  }

  return confirmed;
}

class _DeclineReasonField extends StatefulWidget {
  const _DeclineReasonField({required this.reasonNotifier});

  final ValueNotifier<String> reasonNotifier;

  @override
  State<_DeclineReasonField> createState() => _DeclineReasonFieldState();
}

class _DeclineReasonFieldState extends State<_DeclineReasonField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.reasonNotifier.value);
    _controller.addListener(() {
      widget.reasonNotifier.value = _controller.text;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: TextField(
        key: const Key('quote-decline-reason-field'),
        controller: _controller,
        maxLines: 3,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: l.quoteDeclineReason,
          hintText: l.quoteDeclineReason,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }
}
