// lib/core/widgets/pay_method_selector.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Radio list of the ways to pay a booking (mock S04.03): "Chuyển khoản QR"
/// on a full-width row with its sub-label, then MoMo and ZaloPay sharing the
/// row below. One option is always selected; the bank QR is the default the
/// caller passes in. [PayMethodPicker] stays for the ticket flow (S11.03).
class PayMethodSelector extends StatelessWidget {
  const PayMethodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final PayMethod value;
  final ValueChanged<PayMethod> onChanged;

  /// False while a payment is being created: taps are ignored.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    Widget option(PayMethod m, IconData icon, String label, {String? note}) =>
        _MethodOption(
          key: Key('pay-method-${m.code}'),
          icon: icon,
          label: label,
          note: note,
          selected: value == m,
          enabled: enabled,
          onTap: () => onChanged(m),
        );

    return Semantics(
      container: true,
      label: l.payMethodLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            PayMethod.bankQr,
            AppIcons.qrCode,
            l.payMethodBankQr,
            note: l.payMethodBankQrNote,
          ),
          const SizedBox(height: AppSpace.s2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: option(
                    PayMethod.momo,
                    AppIcons.wallet,
                    l.payMethodMomo,
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: option(
                    PayMethod.zaloPay,
                    AppIcons.wallet,
                    l.payMethodZaloPay,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Sizes from the mock's `.rd` radio dot and `.pmi` icon tile.
const double _dotSize = 18;
const double _tileSize = 26;

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    super.key,
    required this.icon,
    required this.label,
    required this.note,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? note;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final tile = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final idle = dark ? AppColorsDark.borderStrong : AppColors.borderStrong;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outline,
        width: selected ? 1.5 : 1.0,
      ),
    );

    final text = note == null
        ? Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          );

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      focusable: enabled,
      label: note == null ? label : '$label\n$note',
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: ShapeDecoration(
              color: selected ? subtle : glass,
              shape: shape,
            ),
            child: InkWell(
              customBorder: shape,
              onTap: enabled ? onTap : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSpace.s12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3,
                    vertical: AppSpace.s2,
                  ),
                  child: Row(
                    children: [
                      _RadioDot(
                        selected: selected,
                        color: scheme.primary,
                        idle: idle,
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Container(
                        width: _tileSize,
                        height: _tileSize,
                        decoration: BoxDecoration(
                          color: tile,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: AppIcon(
                          icon,
                          size: AppText.md,
                          color: selected ? scheme.primary : secondary,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(child: text),
                    ],
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

class _RadioDot extends StatelessWidget {
  const _RadioDot({
    required this.selected,
    required this.color,
    required this.idle,
  });

  final bool selected;
  final Color color;
  final Color idle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _dotSize,
      height: _dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? color : idle, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: AppSpace.s2,
              height: AppSpace.s2,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
