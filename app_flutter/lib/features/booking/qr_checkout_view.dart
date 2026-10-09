// lib/features/booking/qr_checkout_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/fake_payment_sheet.dart';
import 'package:photobooking/features/booking/payment_snack.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// S04.04 for a bank transfer: the VietQR with its amount, a countdown, the
/// bank rows with "Sao chép" on the transfer content, and the footer. The
/// countdown follows the injected clock, so it also reaches zero while the
/// screen is open and before any server sweep has run.
class QrCheckoutView extends ConsumerStatefulWidget {
  const QrCheckoutView({
    super.key,
    required this.booking,
    required this.checkout,
  });

  final Booking booking;
  final BookingCheckout checkout;

  @override
  ConsumerState<QrCheckoutView> createState() => _QrCheckoutViewState();
}

class _QrCheckoutViewState extends ConsumerState<QrCheckoutView> {
  bool _creating = false;

  /// The checkout "Tạo QR mới" got back, until the booking stream shows it.
  BookingCheckout? _created;

  /// True once the screen shows [created] (or a later attempt).
  bool _shows(BookingCheckout created) =>
      widget.checkout.paymentId == created.paymentId ||
      widget.checkout.attempt >= created.attempt;

  @override
  void didUpdateWidget(covariant QrCheckoutView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The booking stream brought the new checkout: the button is live again.
    final created = _created;
    if (created != null && _shows(created)) {
      _created = null;
      _creating = false;
    }
  }

  void _doneCreating() {
    if (!mounted) return;
    setState(() {
      _creating = false;
      _created = null;
    });
  }

  /// "Tạo QR mới": same method, a fresh payment and a fresh 15 minutes. The
  /// booking stream brings the new checkout; nothing is navigated here. The
  /// button stays busy until that checkout is on screen (the callable can
  /// answer first, and the old, maybe expired QR would offer it again: a
  /// second tap would spend another of the 3 attempts). An error frees it.
  Future<void> _newQr() async {
    if (_creating) return;
    setState(() => _creating = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref
          .read(bookingRepositoryProvider)
          .createPayment(
            bookingId: widget.booking.id,
            method: widget.checkout.method,
          );
      if (!mounted) return;
      // The snapshot may already be on screen; else didUpdateWidget frees it.
      if (_shows(created)) {
        _doneCreating();
      } else {
        _created = created;
      }
    } catch (e) {
      _doneCreating();
      showPaymentSnack(messenger, switch (bookingErrorOf(e)) {
        BookingErrorCode.paymentAttemptsExceeded => l10n.payAttemptsExceeded,
        BookingErrorCode.blocked => l10n.bookingErrBlocked,
        _ => l10n.bookTryAgain,
      });
    }
  }

  Future<void> _copyCode() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: widget.checkout.transferCode));
    showPaymentSnack(messenger, l10n.payQrCopied);
  }

  Future<void> _openBankApps(String url) async {
    await ref.read(externalLauncherProvider).open(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final checkout = widget.checkout;
    final now =
        ref.watch(nowTickerProvider(const Duration(seconds: 1))).value ??
        ref.read(clockProvider)();
    final expired = checkout.isExpiredAt(now);
    final amount = formatMoney(checkout.amount);
    final photographerName =
        ref
            .watch(photographerProfileProvider(widget.booking.photographerId))
            .value
            ?.summary
            .displayName ??
        '';
    final bankAppsUrl = checkout.bankAppsUrl;

    final newQr = expired
        ? AppButton.primary(
            l10n.payQrNew,
            loading: _creating,
            onPressed: _creating ? null : _newQr,
          )
        : AppButton.outline(
            l10n.payQrNew,
            size: AppButtonSize.small,
            loading: _creating,
            onPressed: _creating ? null : _newQr,
          );

    final Widget footer;
    if (expired || bankAppsUrl == null) {
      footer = newQr;
    } else {
      footer = Row(
        children: [
          Expanded(flex: 38, child: newQr),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            flex: 62,
            child: AppButton.primary(
              l10n.payQrOpenBank,
              onPressed: () => _openBankApps(bankAppsUrl),
            ),
          ),
        ],
      );
    }

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
                    payload: checkout.qrPayload ?? '',
                    expired: expired,
                    semanticsLabel: l10n.payQrSemantics(
                      amount,
                      checkout.transferCode,
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
                const SizedBox(height: AppSpace.s2),
                Center(
                  child: CountdownPill(remaining: checkout.remainingAt(now)),
                ),
                const SizedBox(height: AppSpace.s4),
                _KeyValueBox(
                  rows: [
                    _KeyValueRow(
                      label: l10n.payQrBank,
                      value: checkout.bankName ?? '',
                      note: l10n.payQrBankNote,
                    ),
                    _KeyValueRow(
                      label: l10n.payQrAccount,
                      value: checkout.accountMasked ?? '',
                    ),
                    _KeyValueRow(
                      label: l10n.payQrContent,
                      value: checkout.transferCode,
                      // An expired code is no use to copy.
                      trailing: expired
                          ? null
                          : _CopyChip(label: l10n.payQrCopy, onTap: _copyCode),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s3),
                Text(l10n.payQrHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpace.s2),
                Center(
                  child: FakeTransferButton(paymentId: checkout.paymentId),
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

/// Bordered box of label/value rows (mock `.kv`).
class _KeyValueBox extends StatelessWidget {
  const _KeyValueBox({required this.rows});

  final List<_KeyValueRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.note,
    this.trailing,
  });

  final String label;
  final String value;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 78,
              child: Text(
                label,
                style: TextStyle(fontSize: AppText.xs2, color: muted),
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: AppText.sm + 0.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (note != null)
                    Text(
                      note!,
                      style: TextStyle(fontSize: AppText.xs2, color: muted),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.s2),
              trailing!,
            ],
          ],
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
