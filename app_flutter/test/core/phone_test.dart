// test/core/phone_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/phone.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

void main() {
  group('normalizePhone', () {
    const valid = {
      '0903123456': '+84903123456',
      '+84 903 123 456': '+84903123456',
      '0903.123.456': '+84903123456',
      '(090) 312-3456': '+84903123456',
      '+84903123456': '+84903123456',
      '0321234567': '+84321234567',
    };
    valid.forEach((input, e164) {
      test('accepts $input', () => expect(normalizePhone(input), e164));
    });

    const invalid = [
      '',
      '090312345',
      '0123456789',
      '09031234567',
      '0203123456',
      '+84 023 123 456',
      '+14155552671',
      'abc',
      '0903 123 45a',
    ];
    for (final input in invalid) {
      test('rejects "$input"', () => expect(normalizePhone(input), isNull));
    }

    test(
      'international accepts other countries, still rejects malformed +84',
      () {
        expect(
          normalizePhone('+1 415 555 2671', international: true),
          '+14155552671',
        );
        expect(normalizePhone('+84012345678', international: true), isNull);
        expect(normalizePhone('+123', international: true), isNull);
      },
    );
  });

  group('field text', () {
    test('nationalDigits strips +84, one leading 0 and junk, caps at 9', () {
      expect(nationalDigits('0903123456'), '903123456');
      expect(nationalDigits('+84 903 123 456'), '903123456');
      expect(nationalDigits('903 123 456'), '903123456');
      expect(nationalDigits('0'), '');
      expect(
        nationalDigits('84312345678'),
        '843123456',
      ); // no "+": 84 is part of the number
      expect(nationalDigits('9031234567890'), '903123456');
    });
    test('formatNational groups by three', () {
      expect(formatNational(''), '');
      expect(formatNational('90'), '90');
      expect(formatNational('9031'), '903 1');
      expect(formatNational('903123456'), '903 123 456');
    });
    test('phoneFromField accepts what a person types or pastes', () {
      expect(phoneFromField('903 123 456'), '+84903123456');
      expect(phoneFromField('0903123456'), '+84903123456');
      expect(phoneFromField('+84 903 123 456'), '+84903123456');
      expect(phoneFromField('90312345'), isNull);
      expect(phoneFromField('123456789'), isNull);
    });
    test('nationalFromE164 round-trips', () {
      expect(nationalFromE164('+84903123456'), '903 123 456');
    });
  });

  group('validatePhone', () {
    final l = AppLocalizationsVi();
    test('empty, wrong and right', () {
      expect(validatePhone('', l), l.phoneRequired);
      expect(validatePhone(null, l), l.phoneRequired);
      expect(validatePhone('90312345', l), l.phoneInvalid);
      expect(validatePhone('903 123 456', l), isNull);
    });
  });
}
