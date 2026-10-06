import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/auth/auth_error.dart';
import 'package:photobooking/data/auth/auth_repository.dart';

void main() {
  test('email users re-authenticate with their password', () async {
    final auth = FakeAuthRepository();
    await auth.registerWithEmail('a@b.vn', 'secret-123', 'An');
    expect(auth.reauthMethod, ReauthMethod.password);
    await expectLater(
      auth.reauthenticate(password: 'wrong-pass'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.error,
          'error',
          AuthError.wrongPassword,
        ),
      ),
    );
    await auth.reauthenticate(password: 'secret-123');
    expect(auth.reauthentications, 1);
  });

  test('a cancelled provider flow throws cancelled', () async {
    final auth = FakeAuthRepository();
    await auth.signInWithGoogle();
    final cancelled = FakeAuthRepository(
      cancelSocial: false,
      initialUser: const AuthUser(uid: 'google-9'),
    );
    expect(cancelled.reauthMethod, ReauthMethod.google);
    final strict = FakeAuthRepository(
      cancelSocial: true,
      initialUser: const AuthUser(uid: 'facebook-9'),
    );
    expect(strict.reauthMethod, ReauthMethod.facebook);
    await expectLater(
      strict.reauthenticate(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.error,
          'error',
          AuthError.cancelled,
        ),
      ),
    );
  });

  test('the fake records re-authentication', () async {
    final auth = FakeAuthRepository();
    expect(auth.reauthMethod, isNull);
    await auth.signInWithGoogle();
    expect(auth.reauthMethod, ReauthMethod.google);
    await auth.reauthenticate();
    await auth.reauthenticate();
    expect(auth.reauthentications, 2);
  });
}
