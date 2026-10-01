import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

final userContactRepositoryProvider = Provider<UserContactRepository>(
  (ref) => FirestoreUserContactRepository(),
);

/// The signed-in user's private contact; null while signed out or when no
/// number has been saved yet.
final currentContactProvider = StreamProvider.autoDispose<UserContact?>((
  ref,
) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield null;
    return;
  }
  yield* ref.watch(userContactRepositoryProvider).watch(user.uid);
});
