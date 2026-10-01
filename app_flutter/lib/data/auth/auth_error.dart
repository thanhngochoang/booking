import 'package:firebase_auth/firebase_auth.dart';

enum AuthError {
  cancelled,
  wrongPassword,
  userNotFound,
  emailInUse,
  weakPassword,
  network,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.error);
  final AuthError error;
  @override
  String toString() => 'AuthException($error)';
}

AuthError mapAuthException(Object e) {
  if (e is AuthException) return e.error;
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-email' =>
        AuthError.wrongPassword,
      'user-not-found' => AuthError.userNotFound,
      'email-already-in-use' => AuthError.emailInUse,
      'weak-password' => AuthError.weakPassword,
      'network-request-failed' => AuthError.network,
      _ => AuthError.unknown,
    };
  }
  return AuthError.unknown;
}
