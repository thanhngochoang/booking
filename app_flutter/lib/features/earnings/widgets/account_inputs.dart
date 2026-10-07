// lib/features/earnings/widgets/account_inputs.dart
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'package:photobooking/data/earnings/payout_account_rules.dart';

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

/// Turns the holder name into upper-case ASCII while typing: no diacritics
/// (`Đ` becomes `D`), only letters and single spaces, at most
/// [holderNameMax] characters.
class HolderNameFormatter extends TextInputFormatter {
  const HolderNameFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final caret = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    final cleaned = _clean(text);
    final before = _clean(text.substring(0, caret)).length;
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(
        offset: math.min(before, cleaned.length),
      ),
    );
  }

  static String _clean(String raw) {
    final out = StringBuffer();
    var lastSpace = true; // drops leading spaces
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      if (ch.trim().isEmpty) {
        if (!lastSpace) out.write(' ');
        lastSpace = true;
        continue;
      }
      // Run the shared rule on a doubled letter (it needs 2+ letters): digits,
      // punctuation and lone combining marks come back null and are dropped.
      final letter = normalizeHolderName('$ch$ch');
      if (letter == null || letter.length != 2) continue;
      out.write(letter[0]);
      lastSpace = false;
    }
    final s = out.toString();
    return s.length > holderNameMax ? s.substring(0, holderNameMax) : s;
  }
}
