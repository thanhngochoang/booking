// lib/core/phone.dart
import 'package:photobooking/l10n/app_localizations.dart';

/// Vietnamese numbers: 0 or +84, then a 3/5/7/8/9 prefix and 8 more digits.
final _vn = RegExp(r'^(?:\+84|0)([35789]\d{8})$');
final _international = RegExp(r'^\+\d{8,15}$');

String _compact(String s) => s.replaceAll(RegExp(r'[\s.\-()]'), '');

/// E.164 for a valid number, else null. Spaces, dots, dashes and brackets are
/// ignored. [international] also accepts other countries' numbers
/// (`+` and 8–15 digits), for WhatsApp.
String? normalizePhone(String input, {bool international = false}) {
  final s = _compact(input);
  final vn = _vn.firstMatch(s);
  if (vn != null) return '+84${vn.group(1)}';
  // A malformed +84 number must not slip through as "international".
  if (international && !s.startsWith('+84') && _international.hasMatch(s)) {
    return s;
  }
  return null;
}

/// What goes after the fixed "+84" in a field: digits only, no leading 0,
/// at most 9. A leading "+84" (pasted) is dropped. Without "+", exactly 11
/// digits starting with "84" (the wa.me / export form `84903123456`) also lose
/// the "84"; shorter "84…" input is part of the number (084 numbers exist).
String nationalDigits(String input) {
  final s = _compact(input);
  var d = s.startsWith('+84') ? s.substring(3) : s;
  d = d.replaceAll(RegExp(r'\D'), '');
  if (!s.startsWith('+84') && d.length == 11 && d.startsWith('84')) {
    d = d.substring(2);
  }
  if (d.startsWith('0')) d = d.substring(1);
  return d.length > 9 ? d.substring(0, 9) : d;
}

/// `903123456` → `903 123 456`.
String formatNational(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) b.write(' ');
    b.write(digits[i]);
  }
  return b.toString();
}

/// E.164 from the text of a `PhoneField`, or null while it is not valid.
/// A national field (default) holds only the digits after the fixed "+84";
/// an [international] field holds the whole number as typed.
String? phoneFromField(String fieldText, {bool international = false}) =>
    international
    ? normalizePhone(fieldText, international: true)
    : normalizePhone('+84${nationalDigits(fieldText)}');

/// What an international field keeps: one leading "+" if present, then digits
/// only, at most 15 (the E.164 maximum).
String internationalInput(String input) {
  final s = input.trim();
  var digits = s.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 15) digits = digits.substring(0, 15);
  return s.startsWith('+') ? '+$digits' : digits;
}

/// Text to prefill a `PhoneField` from a stored E.164 number.
String nationalFromE164(String e164) => formatNational(nationalDigits(e164));

String? validatePhone(
  String? fieldText,
  AppLocalizations l, {
  bool international = false,
}) {
  final t = (fieldText ?? '').trim();
  if (t.isEmpty) return l.phoneRequired;
  if (phoneFromField(t, international: international) != null) return null;
  return international ? l.phoneInvalidInternational : l.phoneInvalid;
}
