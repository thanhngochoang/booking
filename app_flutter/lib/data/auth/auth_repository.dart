import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:photobooking/data/auth/auth_error.dart';

class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  AuthUser copyWithName(String name) =>
      AuthUser(uid: uid, email: email, displayName: name, photoUrl: photoUrl);
}

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<AuthUser> signInWithEmail(String email, String password);
  Future<AuthUser> registerWithEmail(
    String email,
    String password,
    String displayName,
  );

  /// Throws [AuthException] with [AuthError.cancelled] when the user backs out.
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithFacebook();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    GoogleSignIn? google,
    FacebookAuth? facebook,
  }) : _auth = auth ?? fb.FirebaseAuth.instance,
       _google = google ?? GoogleSignIn.instance,
       _facebook = facebook ?? FacebookAuth.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;
  final FacebookAuth _facebook;
  bool _googleReady = false;

  AuthUser _map(fb.User u) => AuthUser(
    uid: u.uid,
    email: u.email,
    displayName: u.displayName,
    photoUrl: u.photoURL,
  );

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : _map(u));

  @override
  AuthUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _map(u);
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _map(c.user!);
    } catch (e) {
      throw AuthException(mapAuthException(e));
    }
  }

  @override
  Future<AuthUser> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await c.user!.updateDisplayName(displayName);
      return _map(c.user!).copyWithName(displayName);
    } catch (e) {
      throw AuthException(mapAuthException(e));
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final GoogleSignInAccount account;
    try {
      if (!_googleReady) {
        await _google.initialize();
        _googleReady = true;
      }
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException(AuthError.cancelled);
      }
      throw const AuthException(AuthError.unknown);
    }
    try {
      final cred = fb.GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      final c = await _auth.signInWithCredential(cred);
      return _map(c.user!);
    } catch (e) {
      throw AuthException(mapAuthException(e));
    }
  }

  @override
  Future<AuthUser> signInWithFacebook() async {
    final LoginResult result;
    try {
      result = await _facebook.login(
        permissions: const ['email', 'public_profile'],
      );
    } catch (_) {
      throw const AuthException(AuthError.unknown);
    }
    if (result.status == LoginStatus.cancelled) {
      throw const AuthException(AuthError.cancelled);
    }
    final token = result.accessToken?.tokenString;
    if (result.status != LoginStatus.success || token == null) {
      throw const AuthException(AuthError.unknown);
    }
    try {
      final cred = fb.FacebookAuthProvider.credential(token);
      final c = await _auth.signInWithCredential(cred);
      return _map(c.user!);
    } catch (e) {
      throw AuthException(mapAuthException(e));
    }
  }

  @override
  Future<void> signOut() async {
    // Social logouts are best-effort: a provider that was never used (or whose
    // plugin is unavailable) must not fail the Firebase sign-out.
    Future<void> quiet(Future<void> Function() f) async {
      try {
        await f();
      } catch (_) {}
    }

    await Future.wait([
      _auth.signOut(),
      if (_googleReady) quiet(_google.signOut),
      quiet(_facebook.logOut),
    ]);
  }
}

/// In-memory implementation for tests and widget previews.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.cancelSocial = false, this.emitBeforeName = false});
  final bool cancelSocial;

  /// Mimics Firebase: authStateChanges fires before updateDisplayName lands.
  final bool emitBeforeName;
  final _users = <String, ({String password, AuthUser user})>{};
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  int _seq = 0;

  void _emit(AuthUser? u) {
    _current = u;
    _controller.add(u);
  }

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final rec = _users[email];
    if (rec == null) throw const AuthException(AuthError.userNotFound);
    if (rec.password != password) {
      throw const AuthException(AuthError.wrongPassword);
    }
    _emit(rec.user);
    return rec.user;
  }

  @override
  Future<AuthUser> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    if (_users.containsKey(email)) {
      throw const AuthException(AuthError.emailInUse);
    }
    if (password.length < 8) throw const AuthException(AuthError.weakPassword);
    final user = AuthUser(
      uid: 'fake-${++_seq}',
      email: email,
      displayName: displayName,
    );
    _users[email] = (password: password, user: user);
    _emit(
      emitBeforeName
          ? AuthUser(uid: user.uid, email: email, displayName: null)
          : user,
    );
    return user;
  }

  Future<AuthUser> _social(String provider) async {
    if (cancelSocial) throw const AuthException(AuthError.cancelled);
    final user = AuthUser(
      uid: '$provider-${++_seq}',
      email: '$provider@example.com',
      displayName: 'Người dùng $provider',
    );
    _emit(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() => _social('google');

  @override
  Future<AuthUser> signInWithFacebook() => _social('facebook');

  @override
  Future<void> signOut() async => _emit(null);
}
