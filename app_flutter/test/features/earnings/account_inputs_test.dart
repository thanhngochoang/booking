import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/earnings/widgets/account_inputs.dart';

TextEditingValue _v(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);

TextEditingValue _number(String old, TextEditingValue next) =>
    const AccountNumberFormatter().formatEditUpdate(_v(old), next);

TextEditingValue _holder(TextEditingValue next) =>
    const HolderNameFormatter().formatEditUpdate(_v(''), next);

void main() {
  group('AccountNumberFormatter', () {
    test('number groups by four and keeps the caret', () {
      final typed = _number('0123', _v('01234'));
      expect(typed.text, '0123 4');
      expect(typed.selection.baseOffset, 6);

      // A digit typed after the second digit of "0123 4567".
      final middle = _number('0123 4567', _v('01923 4567', 3));
      expect(middle.text, '0192 3456 7');
      expect(middle.selection.baseOffset, 3);

      // Typing the fourth digit does not add a trailing space.
      final four = _number('012', _v('0123'));
      expect(four.text, '0123');
      expect(four.selection.baseOffset, 4);

      // Deleting the only digit of the last group drops its space.
      final back = _number('0123 4', _v('0123 ', 5));
      expect(back.text, '0123');
      expect(back.selection.baseOffset, 4);
    });

    test('a caret in the middle stays after the same digit', () {
      final r = _number('0123 4567', _v('0123 45a67', 8));
      expect(r.text, '0123 4567');
      expect(r.selection.baseOffset, 7);
    });

    test('letters are dropped from the number', () {
      final r = _number('', _v('12ab-34 x'));
      expect(r.text, '1234');
      expect(r.selection.baseOffset, 4);
    });

    test('more than 20 digits are cut', () {
      final r = _number('', _v('0123456789012345678901234'));
      expect(r.text, '0123 4567 8901 2345 6789');
    });

    test('empty stays empty', () {
      final r = _number('1', _v(''));
      expect(r.text, '');
      expect(r.selection.baseOffset, 0);
    });
  });

  group('HolderNameFormatter', () {
    test('holder name turns upper-case without diacritics while typing', () {
      expect(_holder(_v('nguyễn minh trí')).text, 'NGUYEN MINH TRI');
      expect(_holder(_v('Đặng Văn Ơn')).text, 'DANG VAN ON');
    });

    test('digits and punctuation are dropped, spaces collapse', () {
      expect(_holder(_v('  an  b-2c ')).text, 'AN BC ');
      expect(_holder(_v('   ')).text, '');
    });

    test('decomposed accents are folded too', () {
      // "ế" as e + circumflex + acute.
      expect(_holder(_v('trế')).text, 'TRE');
    });

    test('the caret stays after the same letter', () {
      final r = _holder(
        _v(
          'tri'
          'ễ'
          'n',
          4,
        ),
      );
      expect(r.text, 'TRIEN');
      expect(r.selection.baseOffset, 4);
    });

    test('at most 50 characters', () {
      expect(_holder(_v('A' * 80)).text.length, 50);
    });
  });
}
