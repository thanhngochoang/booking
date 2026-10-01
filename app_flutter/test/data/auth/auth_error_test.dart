import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_error.dart';

void main() {
  test('maps Firebase codes to AuthError', () {
    expect(
      mapAuthException(FirebaseAuthException(code: 'wrong-password')),
      AuthError.wrongPassword,
    );
    expect(
      mapAuthException(FirebaseAuthException(code: 'invalid-credential')),
      AuthError.wrongPassword,
    );
    expect(
      mapAuthException(FirebaseAuthException(code: 'user-not-found')),
      AuthError.userNotFound,
    );
    expect(
      mapAuthException(FirebaseAuthException(code: 'email-already-in-use')),
      AuthError.emailInUse,
    );
    expect(
      mapAuthException(FirebaseAuthException(code: 'weak-password')),
      AuthError.weakPassword,
    );
    expect(
      mapAuthException(FirebaseAuthException(code: 'network-request-failed')),
      AuthError.network,
    );
    expect(
      mapAuthException(FirebaseAuthException(code: 'something-else')),
      AuthError.unknown,
    );
    expect(
      mapAuthException(const AuthException(AuthError.cancelled)),
      AuthError.cancelled,
    );
    expect(mapAuthException(StateError('x')), AuthError.unknown);
  });
}
