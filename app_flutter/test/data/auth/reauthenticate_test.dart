import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/data/auth/auth_error.dart';
import 'package:photobooking/data/auth/auth_repository.dart';

class _MockAuth extends Mock implements fb.FirebaseAuth {}

class _MockUser extends Mock implements fb.User {}

class _MockInfo extends Mock implements fb.UserInfo {}

class _MockGoogle extends Mock implements GoogleSignIn {}

class _MockFacebook extends Mock implements FacebookAuth {}

class _MockCredential extends Mock implements fb.UserCredential {}

class _FakeCredential extends Fake implements fb.AuthCredential {}

void main() {
  test(
    'Firebase re-authentication refreshes the ID token afterwards',
    () async {
      registerFallbackValue(_FakeCredential());
      final auth = _MockAuth();
      final user = _MockUser();
      final info = _MockInfo();
      when(() => info.providerId).thenReturn('password');
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.providerData).thenReturn([info]);
      when(() => user.email).thenReturn('a@b.vn');
      when(() => user.reauthenticateWithCredential(any()))
          .thenAnswer((_) async => _MockCredential());
      when(() => user.getIdToken(any())).thenAnswer((_) async => 'token');
      final repo = FirebaseAuthRepository(
        auth: auth,
        google: _MockGoogle(),
        facebook: _MockFacebook(),
      );
      expect(repo.reauthMethod, ReauthMethod.password);
      await repo.reauthenticate(password: 'secret-123');
      verifyInOrder([
        () => user.reauthenticateWithCredential(any()),
        () => user.getIdToken(true),
      ]);
    },
  );

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
