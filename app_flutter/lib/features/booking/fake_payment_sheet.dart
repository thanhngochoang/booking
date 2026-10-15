// lib/features/booking/fake_payment_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/payments_mode.dart';

/// S04.04's "Giả lập chuyển khoản" text button: opens [FakePaymentSheet] on
/// test builds and draws nothing when real payments are on.
class FakeTransferButton extends ConsumerWidget {
  const FakeTransferButton({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(realPaymentsProvider)) return const SizedBox.shrink();
    return AppButton.text(
      context.l10n.fakeTransferOpen,
      size: AppButtonSize.small,
      onPressed: () => showAppSheet<void>(
        context,
        builder: (_) => FakePaymentSheet(paymentId: paymentId),
      ),
    );
  }
}

/// Test-only sheet that makes the fake bank send one of four transfers to a
/// payment: exact, short, over, or with content that matches nothing. The
/// server decides what each one does; this screen only watches the booking.
class FakePaymentSheet extends ConsumerStatefulWidget {
  const FakePaymentSheet({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<FakePaymentSheet> createState() => _FakePaymentSheetState();
}

class _FakePaymentSheetState extends ConsumerState<FakePaymentSheet> {
  FakeTransferKind? _sending;

  Future<void> _send(FakeTransferKind kind) async {
    if (_sending != null) return;
    setState(() => _sending = kind);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .confirmFakePayment(paymentId: widget.paymentId, kind: kind);
    } catch (_) {
      // Ignored here: S04.04 shows the real status.
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final busy = _sending != null;

    Widget outline(String label, FakeTransferKind kind) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2),
      child: AppButton.outline(
        label,
        loading: _sending == kind,
        onPressed: busy ? null : () => _send(kind),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.fakeTransferTitle,
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
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l10n.fakeTransferExact,
            loading: _sending == FakeTransferKind.exact,
            onPressed: busy ? null : () => _send(FakeTransferKind.exact),
          ),
          outline(l10n.fakeTransferUnder, FakeTransferKind.under),
          outline(l10n.fakeTransferOver, FakeTransferKind.over),
          outline(l10n.fakeTransferWrong, FakeTransferKind.wrongContent),
        ],
      ),
    );
  }
}
