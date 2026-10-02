// lib/features/contact/save_contact_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

/// Saves the user's private contact. Its value turns true once a save went
/// through.
class SaveContactController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> save({
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(userContactRepositoryProvider)
          .save(
            uid,
            phone: phone,
            allowZalo: allowZalo,
            allowWhatsApp: allowWhatsApp,
          );
      return true;
    });
  }
}

final saveContactControllerProvider =
    AsyncNotifierProvider.autoDispose<SaveContactController, bool>(
      SaveContactController.new,
    );
