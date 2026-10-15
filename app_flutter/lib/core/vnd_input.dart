import 'package:flutter/services.dart';

/// Whole đồng typed in a money field (dots, spaces and `₫` ignored); null
/// when there are no digits or more than 10 of them.
int? parseVnd(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty || digits.length > 10) {
    return null;
  }
  return int.parse(digits);
}

/// `3200000` → `3.200.000`: the inside of a money field, without `₫`.
String groupVnd(int vnd) {
  final s = vnd.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      out.write('.');
    }
    out.write(s[i]);
  }
  return out.toString();
}

/// Keeps a money field as grouped digits while typing or pasting; at most
/// 10 digits, leading zeros dropped.
class VndInputFormatter extends TextInputFormatter {
  const VndInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 10 ? digits.substring(0, 10) : digits;
    final text = capped.isEmpty ? '' : groupVnd(int.parse(capped));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
