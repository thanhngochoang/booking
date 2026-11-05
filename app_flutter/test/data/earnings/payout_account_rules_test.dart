import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/earnings/payout_account_rules.dart';

void main() {
  test('the mask shows four dots and the last 4', () {
    expect(maskedAccount('3456'), '•••• 3456');
  });
}
