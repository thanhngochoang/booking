import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../user/user_profile.dart';
import '../user/user_repository.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(),
);

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Profile of the signed-in user; ensures users/{uid} exists on first sign-in.
final currentProfileProvider = StreamProvider<UserProfile?>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield null;
    return;
  }
  final repo = ref.watch(userRepositoryProvider);
  await repo.ensureProfile(user);
  // If the doc disappears (deleted by an admin), recreate it without a role
  // so the router sends the user back to onboarding.
  yield* repo
      .watch(user.uid)
      .asyncMap((p) async => p ?? await repo.ensureProfile(user));
});
