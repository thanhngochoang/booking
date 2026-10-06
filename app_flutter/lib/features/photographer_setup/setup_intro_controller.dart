import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/provider_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/photographer_setup/intro_logic.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/stored_provider_type.dart';

/// Saves setup step 1. Its value turns true once a save went through. A
/// failed type change surfaces as a `ProviderError` (`not_eligible`, ...) and
/// nothing else is written.
class SetupIntroController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> save(IntroResult r) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null || !r.ok) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // The stored type comes from the provider the screen shows. Unknown
      // (the read failed) throws: nothing is switched or saved on a guess.
      final stored = await ref.read(storedProviderTypeProvider.future);
      if (r.choice != stored.choice) {
        await ref.read(providerRepositoryProvider).setType(r.choice);
        ref.invalidate(photographerProfileProvider(uid));
        ref.invalidate(myIntroProvider);
      }
      await ref.read(userRepositoryProvider).setDisplayName(uid, r.displayName);
      await ref
          .read(photographerIntroRepositoryProvider)
          .save(uid, bio: r.bio, equipment: r.equipment);
      final drafts = ref.read(setupDraftStoreProvider);
      await drafts.clearIntro(uid);
      if (drafts.step(uid) < 2) {
        await drafts.setStep(uid, 2);
      }
      return true;
    });
  }
}

final setupIntroControllerProvider =
    AsyncNotifierProvider.autoDispose<SetupIntroController, bool>(
      SetupIntroController.new,
    );
