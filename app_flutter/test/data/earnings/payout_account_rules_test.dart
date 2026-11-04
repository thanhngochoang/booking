import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/earnings/payout_account_rules.dart';

import '../../support/backend_snapshot.dart';

void main() {
  setUpAll(requireBackendSnapshot);

  // booking-be packages/domain/test/fixtures/payout_account.json, read after
  // the guard so a missing snapshot fails with its hint.
  late final Map<String, dynamic> fixture;
  setUpAll(() {
    fixture = jsonDecode(
      File('../.backend/packages/domain/test/fixtures/payout_account.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('holder and number cases match the shared fixture', () {
    for (final c in fixture['accountNumbers'] as List) {
      expect(
        normalizeAccountNumber(c['raw'] as String),
        c['normalized'],
        reason: 'number ${c['raw']}',
      );
    }
    for (final c in fixture['holderNames'] as List) {
      expect(
        normalizeHolderName(c['raw'] as String),
        c['normalized'],
        reason: 'holder ${c['raw']}',
      );
    }
    for (final c in fixture['last4'] as List) {
      final n = c['number'] as String;
      expect(n.substring(n.length - 4), c['last4']);
    }
  });

  test('the mask shows four dots and the last 4', () {
    expect(maskedAccount('3456'), '•••• 3456');
  });
}
