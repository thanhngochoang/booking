import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/app/router.dart';

void main() {
  group('computeRedirect account lock', () {
    test('a locked account is redirected to /account/restore from any route', () {
      expect(
        computeRedirect(
          signedIn: true,
          profileLoaded: true,
          needsRole: false,
          isAccountLocked: true,
          location: '/home',
        ),
        '/account/restore',
      );

      expect(
        computeRedirect(
          signedIn: true,
          profileLoaded: true,
          needsRole: false,
          isAccountLocked: true,
          location: '/settings',
        ),
        '/account/restore',
      );

      expect(
        computeRedirect(
          signedIn: true,
          profileLoaded: true,
          needsRole: false,
          isAccountLocked: true,
          location: '/account/restore',
        ),
        isNull,
      );
    });

    test('an active account visiting /account/restore goes to home', () {
      expect(
        computeRedirect(
          signedIn: true,
          profileLoaded: true,
          needsRole: false,
          isAccountLocked: false,
          location: '/account/restore',
        ),
        '/home',
      );
    });
  });
}
