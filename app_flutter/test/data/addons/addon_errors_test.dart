import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/addons/addon_repository.dart';

void main() {
  test('details {code: contact_leak, field: description} → contactLeak/'
      'description', () {
    final e = addonErrorOf(
      const AddonException('contact_leak', field: 'description'),
    );
    expect(e.code, AddonErrorCode.contactLeak);
    expect(e.field, 'description');
  });

  test('details {code: invalid_argument, field: name.contact} → contactLeak/'
      'name', () {
    final e = addonErrorOf(
      const AddonException('invalid_argument', field: 'name.contact'),
    );
    expect(e.code, AddonErrorCode.contactLeak);
    expect(e.field, 'name');
  });

  test('invalid_argument keeps its field', () {
    final e = addonErrorOf(
      const AddonException('invalid_argument', field: 'price'),
    );
    expect(e.code, AddonErrorCode.invalidArgument);
    expect(e.field, 'price');
  });

  test('addon_limit → addonLimit', () {
    expect(
      addonErrorOf(const AddonException('addon_limit')).code,
      AddonErrorCode.addonLimit,
    );
  });

  test('unavailable and socket errors → network', () {
    expect(
      addonErrorOf(const AddonException('unavailable')).code,
      AddonErrorCode.network,
    );
    expect(
      addonErrorOf(const SocketException('down')).code,
      AddonErrorCode.network,
    );
  });

  test('anything else → unknown', () {
    expect(addonErrorOf(StateError('x')).code, AddonErrorCode.unknown);
  });
}
