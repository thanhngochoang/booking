import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/user/user_profile.dart';

void main() {
  test('signed out users go to /login except on auth routes', () {
    expect(
      computeRedirect(
        signedIn: false,
        profileLoaded: true,
        needsRole: false,
        location: '/home',
      ),
      '/login',
    );
    expect(
      computeRedirect(
        signedIn: false,
        profileLoaded: true,
        needsRole: false,
        location: '/login',
      ),
      isNull,
    );
    expect(
      computeRedirect(
        signedIn: false,
        profileLoaded: true,
        needsRole: false,
        location: '/register',
      ),
      isNull,
    );
  });
  test('signed in without role goes to onboarding', () {
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: true,
        location: '/home',
      ),
      '/onboarding/role',
    );
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: true,
        location: '/onboarding/role',
      ),
      isNull,
    );
  });
  test('signed in with role leaves auth and onboarding routes', () {
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: false,
        location: '/login',
      ),
      '/home',
    );
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: false,
        location: '/onboarding/role',
      ),
      '/home',
    );
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: false,
        location: '/bookings',
      ),
      isNull,
    );
  });
  test('while the profile is loading nothing redirects', () {
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: false,
        needsRole: false,
        location: '/splash',
      ),
      isNull,
    );
  });
  test('while auth is restoring, park on splash and remember the target', () {
    expect(
      computeRedirect(
        authLoading: true,
        signedIn: false,
        profileLoaded: false,
        needsRole: false,
        location: '/bookings',
      ),
      '/splash?from=%2Fbookings',
    );
    expect(
      computeRedirect(
        authLoading: true,
        signedIn: false,
        profileLoaded: false,
        needsRole: false,
        location: '/splash',
      ),
      isNull,
    );
  });
  test('signed in but profile still loading also waits on splash', () {
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: false,
        needsRole: false,
        location: '/home',
      ),
      '/splash?from=%2Fhome',
    );
  });
  test('splash resumes the remembered target once the session is known', () {
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: false,
        location: '/splash',
        from: '/bookings',
      ),
      '/bookings',
    );
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: false,
        location: '/splash',
      ),
      '/home',
    );
    expect(
      computeRedirect(
        signedIn: false,
        profileLoaded: true,
        needsRole: false,
        location: '/splash',
        from: '/bookings',
      ),
      '/login',
    );
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: true,
        location: '/splash',
        from: '/bookings',
      ),
      '/onboarding/role',
    );
  });
  test('profile load error goes to the session error screen', () {
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: false,
        profileError: true,
        needsRole: false,
        location: '/login',
      ),
      '/session-error',
    );
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: false,
        profileError: true,
        needsRole: false,
        location: '/session-error',
      ),
      isNull,
    );
  });

  test('photographer-only routes send everyone else home', () {
    expect(photographerOnlyRedirect(UserRole.photographer), isNull);
    expect(photographerOnlyRedirect(UserRole.customer), '/home');
    expect(photographerOnlyRedirect(null), '/home');
  });
}
