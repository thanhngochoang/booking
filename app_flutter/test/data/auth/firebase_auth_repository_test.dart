import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/auth/auth_error.dart';
import 'package:photobooking/data/auth/auth_repository.dart';

class _Fb extends Mock implements FacebookAuth {}

class _Auth extends Mock implements fb.FirebaseAuth {}

class _Google extends Mock implements GoogleSignIn {}

void main() {
  test('a native Facebook SDK failure becomes a typed AuthException', () async {
    final facebook = _Fb();
    when(() => facebook.login(permissions: any(named: 'permissions')))
        .thenThrow(
          PlatformException(code: 'FAILED', message: 'client token missing'),
        );
    final repo = FirebaseAuthRepository(
      auth: _Auth(),
      google: _Google(),
      facebook: facebook,
    );
    await expectLater(repo.signInWithFacebook(), throwsA(isA<AuthException>()));
  });
}
