// test/data/contracts/emulator_token.dart
import 'dart:convert';

/// An ID token shaped like the Firebase Auth emulator's (unsigned, alg
/// "none"). services/api accepts it only with AUTH_MODE=firebase-emulator,
/// which it refuses in production.
String emulatorIdToken(String uid, {String projectId = 'demo-nag'}) {
  String enc(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'none', 'typ': 'JWT'})}.${enc({
    'iss': 'https://securetoken.google.com/$projectId',
    'aud': projectId,
    'sub': uid,
    'user_id': uid,
    'iat': now,
    'auth_time': now,
    'exp': now + 3600,
    'firebase': {'sign_in_provider': 'password', 'identities': <String, Object?>{}},
  })}.';
}
