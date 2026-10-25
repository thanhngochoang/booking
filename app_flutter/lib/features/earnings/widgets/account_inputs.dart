// lib/features/earnings/widgets/account_inputs.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/earnings/payout_account_rules.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';

/// Digits only, in groups of four ("0123 4567 890"), at most
/// [accountNumberMax] digits; the caret stays after the digit it was after.
class AccountNumberFormatter extends TextInputFormatter {
  const AccountNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final caret = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    final digitsBefore = _digits(text.substring(0, caret)).length;
    var digits = _digits(text);
    if (digits.length > accountNumberMax) {
      digits = digits.substring(0, accountNumberMax);
    }
    final kept = math.min(digitsBefore, digits.length);
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) out.write(' ');
      out.write(digits[i]);
    }
    // After the k-th digit: k digits plus the spaces between them.
    final offset = kept == 0 ? 0 : kept + (kept - 1) ~/ 4;
    return TextEditingValue(
      text: out.toString(),
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
}

/// The mock's bank field: a code badge, the short and full name, and a
/// search mark that opens the bank list ([onTap]). Without a bank it reads
/// "Chọn ngân hàng". [label] replaces "Ngân hàng" of S06.06 (S22.04 has its
/// own key with the same words).
class BankField extends StatelessWidget {
  const BankField({
    super.key,
    required this.bank,
    required this.onTap,
    this.label,
  });

  final VnBank? bank;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final b = bank;
    final fieldLabel = label ?? l.payoutAccountBank;
    return Semantics(
      button: true,
      enabled: onTap != null,
      excludeSemantics: true,
      label:
          '$fieldLabel, ${b == null ? l.payoutAccountBankPick : '${b.shortName}, ${b.name}'}',
      onTap: onTap,
      child: InkWell(
        key: const Key('payout-bank'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: fieldLabel,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            enabled: onTap != null,
            suffixIcon: const AppIcon(AppIcons.search),
          ),
          child: b == null
              ? Text(
                  l.payoutAccountBankPick,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor,
                  ),
                )
              : Row(
                  children: [
                    BankBadge(code: b.code),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(b.shortName, style: theme.textTheme.titleSmall),
                          Text(b.name, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The mock's `.bnk`: the bank code in a small rounded tile (the logo slot).
class BankBadge extends StatelessWidget {
  const BankBadge({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(
          minWidth: AppSpace.s10,
          minHeight: AppSpace.s8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          code,
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
