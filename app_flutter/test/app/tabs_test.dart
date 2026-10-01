import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/app/tabs.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';

void main() {
  test('paths are fixed and ordered', () {
    expect(AppTab.values.map((t) => t.path), [
      '/home',
      '/explore',
      '/action',
      '/bookings',
      '/profile',
    ]);
  });
  test('middle and bookings tabs change by role', () {
    final c = tabsFor(UserRole.customer);
    final p = tabsFor(UserRole.photographer);
    expect(c.length, 5);
    expect(c[2].labelKey, 'tabFind');
    expect(p[2].labelKey, 'tabCreate');
    expect(c[3].labelKey, 'tabBookings');
    expect(p[3].labelKey, 'tabWork');
  });
}
