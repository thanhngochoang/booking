import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';

/// Saves the profile form. Its value turns true once a save has gone through.
class EditProfileController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> save({required String displayName}) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(userRepositoryProvider)
          .setDisplayName(uid, displayName.trim());
      return true;
    });
  }
}

final editProfileControllerProvider =
    AsyncNotifierProvider.autoDispose<EditProfileController, bool>(
      EditProfileController.new,
    );
