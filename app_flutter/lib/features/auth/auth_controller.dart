import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_error.dart';
import '../../data/auth/auth_providers.dart';
import '../../l10n/app_localizations.dart';

/// State is the last [AuthError] to show, or null. Loading while an action runs.
class AuthController extends AsyncNotifier<AuthError?> {
  @override
  Future<AuthError?> build() async => null;

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } on AuthException catch (e) {
      // A cancelled social login is not an error the user needs to read.
      state = AsyncData(e.error == AuthError.cancelled ? null : e.error);
    } catch (_) {
      state = const AsyncData(AuthError.unknown);
    }
  }

  Future<void> signInEmail(String email, String password) => _run(
    () => ref
        .read(authRepositoryProvider)
        .signInWithEmail(email.trim(), password),
  );

  Future<void> register(String email, String password, String name) =>
      _run(() async {
        final user = await ref
            .read(authRepositoryProvider)
            .registerWithEmail(email.trim(), password, name.trim());
        // authStateChanges fires before the display name is set, so the
        // users/{uid} doc may already exist with the email prefix.
        await ref
            .read(userRepositoryProvider)
            .setDisplayName(user.uid, name.trim());
      });

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();

  Future<void> google() =>
      _run(() => ref.read(authRepositoryProvider).signInWithGoogle());

  Future<void> facebook() =>
      _run(() => ref.read(authRepositoryProvider).signInWithFacebook());
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthError?>(AuthController.new);

String authErrorMessage(AuthError e, AppLocalizations l) => switch (e) {
  AuthError.wrongPassword => l.authErrorWrongPassword,
  AuthError.userNotFound => l.authErrorUserNotFound,
  AuthError.emailInUse => l.authErrorEmailInUse,
  AuthError.weakPassword => l.authErrorWeakPassword,
  AuthError.network => l.authErrorNetwork,
  AuthError.cancelled || AuthError.unknown => l.authErrorUnknown,
};
