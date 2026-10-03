// lib/features/booking/fake_payment_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_providers.dart';

class FakePaymentSheet extends ConsumerStatefulWidget {
  const FakePaymentSheet({
    super.key,
    required this.paymentId,
    required this.amountVnd,
  });

  final String paymentId;
  final int amountVnd;

  @override
  ConsumerState<FakePaymentSheet> createState() => _FakePaymentSheetState();
}

class _FakePaymentSheetState extends ConsumerState<FakePaymentSheet> {
  bool _loading = false;

  Future<void> _handleConfirm() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .confirmFakePayment(paymentId: widget.paymentId);
    } catch (_) {
      // Ignored here: S04.04 shows the real status
    } finally {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.fakePayTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l10n.fakePayBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          Center(
            child: Text(
              formatMoney(widget.amountVnd),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l10n.fakePayConfirm,
            loading: _loading,
            onPressed: _loading ? null : _handleConfirm,
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l10n.actionCancel,
            onPressed: _loading ? null : _handleCancel,
          ),
        ],
      ),
    );
  }
}
