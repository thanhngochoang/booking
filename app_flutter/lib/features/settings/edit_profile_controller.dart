import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

/// Saves the profile form. Its value turns true once a save has gone through.
class EditProfileController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  /// [phone] is E.164. The contact is written only when there is a number;
  /// it goes to the private contact, never to the public profile.
  Future<void> save({
    required String displayName,
    String? phone,
    bool allowZalo = true,
    bool allowWhatsApp = false,
  }) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(userRepositoryProvider)
          .setDisplayName(uid, displayName.trim());
      if (phone != null) {
        await ref
            .read(userContactRepositoryProvider)
            .save(
              uid,
              phone: phone,
              allowZalo: allowZalo,
              allowWhatsApp: allowWhatsApp,
            );
      }
      return true;
    });
  }
}

final editProfileControllerProvider =
    AsyncNotifierProvider.autoDispose<EditProfileController, bool>(
      EditProfileController.new,
    );
