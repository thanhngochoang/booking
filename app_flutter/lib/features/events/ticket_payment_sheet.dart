// lib/features/events/ticket_payment_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/payments/payments_repository.dart';

/// Opens the payment step of a held ticket: in fake mode (emulator, dev) the
/// [TicketPaymentSheet]; with real payments the gateway's [payUrl]. The
/// registration stream then decides what the screen shows (`paid`, expired).
/// Returns the status the fake confirmation reported, else null.
Future<RegistrationStatus?> openTicketPayment(
  BuildContext context,
  WidgetRef ref, {
  required String paymentId,
  required int amountVnd,
  String? payUrl,
}) async {
  if (ref.read(realPaymentsProvider)) {
    final url = payUrl;
    if (url != null && url.isNotEmpty) {
      await ref.read(externalLauncherProvider).open(Uri.parse(url));
    }
    return null;
  }
  return showAppSheet<RegistrationStatus>(
    context,
    builder: (_) => ScreenCode(
      ScreenCodes.eventRegister,
      label: 'pay',
      child: TicketPaymentSheet(paymentId: paymentId, amountVnd: amountVnd),
    ),
  );
}

/// Fake-gateway confirmation of a ticket payment (like the booking
/// `FakePaymentSheet`, but through `EventRepository.confirmFakeTicketPayment`).
/// Pops the registration status the server reported, or null when cancelled.
class TicketPaymentSheet extends ConsumerStatefulWidget {
  const TicketPaymentSheet({
    super.key,
    required this.paymentId,
    required this.amountVnd,
  });

  final String paymentId;
  final int amountVnd;

  @override
  ConsumerState<TicketPaymentSheet> createState() => _TicketPaymentSheetState();
}

class _TicketPaymentSheetState extends ConsumerState<TicketPaymentSheet> {
  bool _loading = false;

  Future<void> _confirm() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    RegistrationStatus? status;
    try {
      final outcome = await ref
          .read(paymentsRepositoryProvider)
          .confirmFake(widget.paymentId);
      status = outcome == 'paid' ? RegistrationStatus.paid : RegistrationStatus.held;
    } catch (e) {
      // The registration stream shows the real state (still held, expired);
      // the customer is told the payment did not go through.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              eventErrorCodeOf(e) == 'fake_payments_disabled'
                  ? l.ticketPayFakeDisabled
                  : l.ticketPayFailed,
            ),
          ),
        );
    }
    if (mounted) {
      Navigator.of(context).pop(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
              l.fakeTicketPayTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.fakePayBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          Center(
            child: Text(
              formatMoney(widget.amountVnd),
              key: const Key('ticket-pay-amount'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l.fakePayConfirm,
            key: const Key('ticket-pay-confirm'),
            loading: _loading,
            onPressed: _loading ? null : _confirm,
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l.actionCancel,
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
