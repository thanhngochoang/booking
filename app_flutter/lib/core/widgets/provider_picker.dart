// lib/core/widgets/provider_picker.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Single choice of a ticket payment method (mock S11.03): "Chuyển khoản QR"
/// takes the wider slot, then MoMo and ZaloPay.
class PayMethodPicker extends StatelessWidget {
  const PayMethodPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final PayMethod value;
  final ValueChanged<PayMethod> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget button(PayMethod m, String label, int flex) => Expanded(
      flex: flex,
      child: _ProviderButton(
        key: Key('pay-method-${m.name}'),
        label: label,
        selected: value == m,
        onTap: enabled ? () => onChanged(m) : null,
      ),
    );
    return Semantics(
      container: true,
      label: l.payMethodLabel,
      child: Row(
        children: [
          button(PayMethod.bankQr, l.payMethodBankQr, 44),
          const SizedBox(width: AppSpace.s2),
          button(PayMethod.momo, l.payMethodMomo, 28),
          const SizedBox(width: AppSpace.s2),
          button(PayMethod.zaloPay, l.payMethodZaloPay, 28),
        ],
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final border = selected ? scheme.primary : scheme.outline;
    final bg = selected ? subtle : glass;
    final textColor = selected
        ? scheme.primary
        : (dark
              ? AppColorsDark.foregroundSecondary
              : AppColors.foregroundSecondary);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      side: BorderSide(color: border, width: selected ? 1.5 : 1.0),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: ShapeDecoration(color: bg, shape: shape),
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3,
                    vertical: AppSpace.s2,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
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
