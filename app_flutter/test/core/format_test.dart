import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/format.dart';

void main() {
  test('distance has one decimal, a comma and the unit', () {
    expect(formatDistance(1.24), '1,2 km');
    expect(formatDistance(12), '12,0 km');
    expect(formatDistance(0.04), '0,1 km', reason: 'never shows 0,0 km');
  });
}
