import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/auth/auth_form_validators.dart';
import 'package:photobooking/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('vi'));
  });
  test('email', () {
    expect(validateEmail('', l), l.errorEmailInvalid);
    expect(validateEmail('abc', l), l.errorEmailInvalid);
    expect(validateEmail('a@b.vn', l), isNull);
  });
  test('password and confirm', () {
    expect(validatePassword('1234567', l), l.errorPasswordShort);
    expect(validatePassword('12345678', l), isNull);
    expect(validateConfirm('x', 'y', l), l.errorPasswordMismatch);
    expect(validateConfirm('y', 'y', l), isNull);
  });
  test('name', () {
    expect(validateName('  ', l), l.errorNameEmpty);
    expect(validateName('Lan', l), isNull);
  });
}
