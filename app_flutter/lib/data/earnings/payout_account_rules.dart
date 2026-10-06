/// Input rules for the payout account form (S06.06). Mirrors
/// `packages/domain/src/payout_account.ts`; `payout_account.json` keeps both
/// equal.
library;

const int accountNumberMin = 6;
const int accountNumberMax = 20;
const int holderNameMin = 2;
const int holderNameMax = 50;

final _numberChars = RegExp(r'[ .-]');
final _digits = RegExp(r'^[0-9]{6,20}$');
final _marks = RegExp('[̀-ͯ]');
final _letters = RegExp(r'^[A-Z ]+$');
final _spaces = RegExp(r'\s+');

/// Digits only after dropping spaces, dots and dashes; 6-20 of them, else null.
String? normalizeAccountNumber(String raw) {
  final digits = raw.replaceAll(_numberChars, '');
  return _digits.hasMatch(digits) ? digits : null;
}

const _diacritics = {
  'àáâãäåăắằẳẵặấầẩẫậạảąā': 'a',
  'èéêëẽẻẹếềểễệēę': 'e',
  'ìíîïĩỉịī': 'i',
  'òóôõöơọỏốồổỗộớờởỡợō': 'o',
  'ùúûüũưụủứừửữựū': 'u',
  'ỳýỷỹỵÿ': 'y',
  'đ': 'd',
};

String _stripMarks(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    var mapped = ch;
    final lower = ch.toLowerCase();
    for (final e in _diacritics.entries) {
      if (e.key.contains(lower)) {
        mapped = e.value;
        break;
      }
    }
    b.write(mapped);
  }
  return b.toString().replaceAll(_marks, '');
}

/// Upper-case ASCII without diacritics, `Đ` to `D`, single spaces, 2-50 letters
/// or spaces; else null.
String? normalizeHolderName(String raw) {
  final ascii = _stripMarks(raw).toUpperCase().replaceAll(_spaces, ' ').trim();
  if (!_letters.hasMatch(ascii)) return null;
  if (ascii.length < holderNameMin || ascii.length > holderNameMax) return null;
  return ascii;
}

/// How the number is shown after saving; never more than the last 4 digits.
String maskedAccount(String last4) => '•••• $last4';
