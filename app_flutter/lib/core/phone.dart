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
/// at most 9. A leading "+84" (pasted) is dropped; without "+", "84…" is part
/// of the number (08x numbers exist).
String nationalDigits(String input) {
  final s = _compact(input);
  var d = s.startsWith('+84') ? s.substring(3) : s;
  d = d.replaceAll(RegExp(r'\D'), '');
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
String? phoneFromField(String fieldText) =>
    normalizePhone('+84${nationalDigits(fieldText)}');

/// Text to prefill a `PhoneField` from a stored E.164 number.
String nationalFromE164(String e164) => formatNational(nationalDigits(e164));

String? validatePhone(String? fieldText, AppLocalizations l) {
  final t = (fieldText ?? '').trim();
  if (t.isEmpty) return l.phoneRequired;
  return phoneFromField(t) == null ? l.phoneInvalid : null;
}
