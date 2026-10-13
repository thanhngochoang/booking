// lib/features/payment/wallet_waiting_view.dart


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/features/payment/fake_transfer_sheet.dart';
import 'package:photobooking/features/payment/payment_controller.dart';

/// S04.04 while the customer pays in a wallet app (MoMo, ZaloPay): the
/// vibration loader with "Đang chờ xác nhận", "Mở lại {ví}" for the wallet
/// link and "Kiểm tra lại" to ask the server. The subject's stream, not the
/// wallet's redirect, is what moves the screen on once the money arrives.
class WalletWaitingView extends ConsumerWidget {
  const WalletWaitingView({
    super.key,
    required this.instructions,
    required this.who,
    required this.checking,
    required this.onCheck,
  });

  final PaymentInstructions instructions;
  final PayWho who;
  final bool checking;
  final VoidCallback onCheck;

  Future<void> _reopen(WidgetRef ref, String url) async {
    await ref.read(externalLauncherProvider).open(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final checkout = instructions;
    final payUrl = checkout.payUrl;
    final walletName = checkout.method == PayMethod.zaloPay
        ? l10n.payMethodZaloPay
        : l10n.payMethodMomo;

    final whoText = who.detail.isNotEmpty
        ? l10n.payQrWho(who.name, who.detail)
        : who.name;

    final check = AppButton.outline(
      l10n.payCheckAgain,
      size: payUrl == null ? AppButtonSize.regular : AppButtonSize.small,
      loading: checking,
      onPressed: checking ? null : onCheck,
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
                    if (whoText.isNotEmpty)
                      Text(
                        whoText,
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
                        onPressed: () => _reopen(ref, payUrl),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
