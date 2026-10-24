// lib/features/payment/qr_checkout_view.dart


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/payment/fake_transfer_sheet.dart';
import 'package:photobooking/features/payment/payment_controller.dart';
import 'package:photobooking/features/payment/payment_snack.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// S04.04 for a bank transfer: the VietQR with its amount, a countdown, the
/// bank rows with "Sao chép" on the transfer content, and the footer. The
/// countdown follows the injected clock, so it also reaches zero while the
/// screen is open and before any server sweep has run.
class QrCheckoutView extends ConsumerWidget {
  const QrCheckoutView({
    super.key,
    required this.instructions,
    required this.who,
    required this.canRenew,
    required this.renewing,
    required this.onRenew,
    required this.onBack,
  });

  final PaymentInstructions instructions;
  final PayWho who;
  final bool canRenew;
  final bool renewing;
  final VoidCallback onRenew;
  final VoidCallback onBack;

  Future<void> _copyCode(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: instructions.transferCode));
    showPaymentSnack(messenger, l10n.payQrCopied);
  }

  Future<void> _openBankApps(WidgetRef ref, String url) async {
    await ref.read(externalLauncherProvider).open(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(nowTickerProvider(const Duration(seconds: 1))).value ??
        ref.read(clockProvider)();
    final expired = instructions.isExpiredAt(now);
    final amount = formatMoney(instructions.amount);
    final bankAppsUrl = instructions.bankAppsUrl;

    final Widget footer;
    if (expired && !canRenew) {
      footer = AppButton.primary(
        l10n.payBackToEvent,
        onPressed: onBack,
      );
    } else if (expired) {
      footer = AppButton.primary(
        l10n.payQrNew,
        loading: renewing,
        onPressed: renewing ? null : onRenew,
      );
    } else if (bankAppsUrl == null) {
      footer = AppButton.outline(
        l10n.payQrNew,
        size: AppButtonSize.small,
        loading: renewing,
        onPressed: renewing ? null : onRenew,
      );
    } else {
      footer = Row(
        children: [
          Expanded(
            flex: 38,
            child: AppButton.outline(
              l10n.payQrNew,
              size: AppButtonSize.small,
              loading: renewing,
              onPressed: renewing ? null : onRenew,
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            flex: 62,
            child: AppButton.primary(
              l10n.payQrOpenBank,
              onPressed: () => _openBankApps(ref, bankAppsUrl),
            ),
          ),
        ],
      );
    }

    final whoText = who.detail.isNotEmpty
        ? l10n.payQrWho(who.name, who.detail)
        : who.name;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _QrTile(
                    payload: instructions.qrPayload ?? '',
                    expired: expired,
                    semanticsLabel: l10n.payQrSemantics(
                      amount,
                      instructions.transferCode,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  amount,
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
                const SizedBox(height: AppSpace.s2),
                Center(
                  child: CountdownPill(remaining: instructions.remainingAt(now)),
                ),
                const SizedBox(height: AppSpace.s4),
                KeyValueBox(
                  rows: [
                    KeyValueRow(
                      label: l10n.payQrBank,
                      value: instructions.bankName ?? '',
                      note: l10n.payQrBankNote,
                    ),
                    KeyValueRow(
                      label: l10n.payQrAccount,
                      value: instructions.accountMasked ?? '',
                    ),
                    KeyValueRow(
                      label: l10n.payQrContent,
                      value: instructions.transferCode,
                      trailing: expired
                          ? null
                          : _CopyChip(
                              label: l10n.payQrCopy,
                              onTap: () => _copyCode(context),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s3),
                Text(l10n.payQrHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpace.s2),
                Center(
                  child: FakeTransferButton(paymentId: instructions.paymentId),
                ),
              ],
            ),
          ),
        ),
        AppFooterBar(child: footer),
      ],
    );
  }
}

/// The QR on a white rounded tile (mock `.qrb`). Scanners need a light
/// background, so the tile stays white in dark mode too, with near-black ink
/// (`AppColors.surface` and `AppColors.pillInk`, the light theme's tokens).
class _QrTile extends StatelessWidget {
  const _QrTile({
    required this.payload,
    required this.expired,
    required this.semanticsLabel,
  });

  final String payload;
  final bool expired;
  final String semanticsLabel;

  static const _outer = 156.0;
  static const _pad = 9.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final qr = ExcludeSemantics(
      child: QrImageView(
        key: ValueKey(payload),
        data: payload,
        size: _outer - 2 * _pad,
        padding: EdgeInsets.zero,
        backgroundColor: AppColors.surface,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.pillInk,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.pillInk,
        ),
      ),
    );

    return Semantics(
      image: true,
      label: expired ? l10n.payQrExpired : semanticsLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: SizedBox(
            width: _outer,
            height: _outer,
            child: Padding(
              padding: const EdgeInsets.all(_pad),
              child: expired
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(opacity: 0.15, child: qr),
                        Text(
                          l10n.payQrExpired,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: AppText.base,
                            fontWeight: FontWeight.w700,
                            color: AppColors.pillInk,
                          ),
                        ),
                      ],
                    )
                  : qr,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Sao chép": accent text on the soft accent fill (mock `.cpy`), with a
/// 48dp tap box around the visual pill.
class _CopyChip extends StatelessWidget {
  const _CopyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? AppColorsDark.accentSoft : AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s1,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppText.xs2,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
