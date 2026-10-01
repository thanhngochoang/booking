import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/app/router.dart';

void main() {
  test('signed out users go to /login except on auth routes', () {
    expect(computeRedirect(signedIn: false, profileLoaded: true, needsRole: false, location: '/home'), '/login');
    expect(computeRedirect(signedIn: false, profileLoaded: true, needsRole: false, location: '/login'), isNull);
    expect(computeRedirect(signedIn: false, profileLoaded: true, needsRole: false, location: '/register'), isNull);
  });
  test('signed in without role goes to onboarding', () {
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: true, location: '/home'), '/onboarding/role');
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: true, location: '/onboarding/role'), isNull);
  });
  test('signed in with role leaves auth and onboarding routes', () {
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: false, location: '/login'), '/home');
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: false, location: '/onboarding/role'), '/home');
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: false, location: '/bookings'), isNull);
  });
  test('while the profile is loading nothing redirects', () {
    expect(computeRedirect(signedIn: true, profileLoaded: false, needsRole: false, location: '/home'), isNull);
  });
}
