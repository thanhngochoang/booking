// test/features/contact/return_to_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/contact/return_to.dart';

void main() {
  test('keeps in-app paths, with query', () {
    expect(safeReturnTo('/u/abc/book'), '/u/abc/book');
    expect(safeReturnTo('/e/1/join?qty=2'), '/e/1/join?qty=2');
  });
  test('refuses anything that could leave the app or is empty', () {
    for (final bad in [
      null,
      '',
      'https://evil.com',
      '//evil.com',
      'evil.com',
      r'/\evil.com',
      'javascript:alert(1)',
    ]) {
      expect(safeReturnTo(bad), isNull, reason: '$bad');
    }
  });
}
