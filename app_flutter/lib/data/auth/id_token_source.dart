// lib/data/auth/id_token_source.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Port: the bearer token for the self-hosted API. Firebase Auth stays the
/// identity provider in phase 2, so this is the signed-in user's ID token.
abstract class IdTokenSource {
  /// Null while signed out. [forceRefresh] is used once after a 401.
  Future<String?> token({bool forceRefresh = false});
}

class FirebaseIdTokenSource implements IdTokenSource {
  FirebaseIdTokenSource({this.auth});
  final fb.FirebaseAuth? auth;

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    final user = (auth ?? fb.FirebaseAuth.instance).currentUser;
    // The SDK caches the token and refreshes it only near expiry, so this is
    // not a network call per request.
    return user?.getIdToken(forceRefresh);
  }
}

/// Fixed token, for tests and the contract runs.
class StaticIdTokenSource implements IdTokenSource {
  const StaticIdTokenSource(this.value);
  final String? value;

  @override
  Future<String?> token({bool forceRefresh = false}) async => value;
}
