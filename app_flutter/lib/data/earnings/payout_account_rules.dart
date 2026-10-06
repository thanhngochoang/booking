/// Input rules for the payout account form (S06.06). Mirrors
/// `packages/domain/src/payout_account.ts`; `payout_account.json` keeps both
/// equal.
library;

part 'holder_name_fold.g.dart';

const int accountNumberMin = 6;
const int accountNumberMax = 20;
const int holderNameMin = 2;
const int holderNameMax = 50;

final _numberChars = RegExp(r'[ .-]');
final _digits = RegExp(r'^[0-9]{6,20}$');

/// Digits only after dropping spaces, dots and dashes; 6-20 of them, else null.
String? normalizeAccountNumber(String raw) {
  final digits = raw.replaceAll(_numberChars, '');
  return _digits.hasMatch(digits) ? digits : null;
}

/// Upper-case ASCII without diacritics, `Đ` to `D`, single spaces, 2-50 letters
/// or spaces; else null. Same result as the domain for every input: the
/// non-ASCII folding comes from the generated table in `holder_name_fold.g.dart`.
String? normalizeHolderName(String raw) {
  final b = StringBuffer();
  var lastSpace = true; // drops leading spaces
  for (final r in raw.runes) {
    String? piece;
    if (r < 0x80) {
      if ((r >= 0x41 && r <= 0x5A)) {
        piece = String.fromCharCode(r);
      } else if (r >= 0x61 && r <= 0x7A) {
        piece = String.fromCharCode(r - 32);
      } else if (r == 0x20 || (r >= 0x09 && r <= 0x0D)) {
        piece = ' ';
      } else {
        return null;
      }
    } else if (r >= 0x300 && r <= 0x36F) {
      continue;
    } else if (_holderSpaces.contains(r)) {
      piece = ' ';
    } else {
      piece = _holderFold[r];
      if (piece == null) return null;
    }
    if (piece == ' ') {
      if (lastSpace) continue;
      lastSpace = true;
    } else {
      lastSpace = false;
    }
    b.write(piece);
  }
  final out = b.toString().trimRight();
  if (out.length < holderNameMin || out.length > holderNameMax) return null;
  return out;
}

/// How the number is shown after saving; never more than the last 4 digits.
String maskedAccount(String last4) => '•••• $last4';
