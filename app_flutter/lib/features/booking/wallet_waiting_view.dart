// lib/features/booking/wallet_waiting_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/fake_payment_sheet.dart';
import 'package:photobooking/features/booking/payment_snack.dart';

/// S04.04 while the customer pays in a wallet app (MoMo, ZaloPay): the
/// vibration loader with "Đang chờ xác nhận", "Mở lại {ví}" for the wallet
/// link and "Kiểm tra lại" to ask the server. The booking stream, not the
/// wallet's redirect, is what moves the screen on once the money arrives.
class WalletWaitingView extends ConsumerStatefulWidget {
  const WalletWaitingView({
    super.key,
    required this.booking,
    required this.checkout,
  });

  final Booking booking;
  final BookingCheckout checkout;

  @override
  ConsumerState<WalletWaitingView> createState() => _WalletWaitingViewState();
}

class _WalletWaitingViewState extends ConsumerState<WalletWaitingView> {
  bool _checking = false;

  /// Asks the server to query the gateway. Never creates a payment.
  Future<void> _checkAgain() async {
    if (_checking) return;
    setState(() => _checking = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(bookingRepositoryProvider)
          .checkPayment(bookingId: widget.booking.id);
      if (!res.paid) showPaymentSnack(messenger, l10n.payNotYet);
    } catch (_) {
      showPaymentSnack(messenger, l10n.bookNetworkError);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _reopen(String url) async {
    await ref.read(externalLauncherProvider).open(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final checkout = widget.checkout;
    final payUrl = checkout.payUrl;
    final walletName = checkout.method == PayMethod.zaloPay
        ? l10n.payMethodZaloPay
        : l10n.payMethodMomo;
    final photographerName =
        ref
            .watch(photographerProfileProvider(widget.booking.photographerId))
            .value
            ?.summary
            .displayName ??
        '';

    final check = AppButton.outline(
      l10n.payCheckAgain,
      size: payUrl == null ? AppButtonSize.regular : AppButtonSize.small,
      loading: _checking,
      onPressed: _checking ? null : _checkAgain,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: SignatureLoader(
                    size: LoaderSize.screen,
                    wave: LoaderWave.vibration,
                  ),
                ),
                const SizedBox(height: AppSpace.s6),
                Text(
                  l10n.payWalletWaiting,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  formatMoney(checkout.amount),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: AppText.xl,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s1,
                  children: [
                    Text(
                      l10n.payQrWho(
                        photographerName,
                        widget.booking.serviceSnapshot.name,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    StatusBadge(
                      BookingStatus.draft,
                      label: l10n.payAwaitingDeposit,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),
                Center(
                  child: FakeTransferButton(paymentId: checkout.paymentId),
                ),
              ],
            ),
          ),
        ),
        AppFooterBar(
          child: payUrl == null
              ? check
              : Row(
                  children: [
                    Expanded(flex: 38, child: check),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      flex: 62,
                      child: AppButton.primary(
                        l10n.payWalletReopen(walletName),
                        onPressed: () => _reopen(payUrl),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
