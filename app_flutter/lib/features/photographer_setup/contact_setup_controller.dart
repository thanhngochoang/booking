import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';

/// Saves S08.05. Its value turns true once the save went through.
class SetupContactController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> save({
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  }) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(photographerContactRepositoryProvider)
          .completeContactSetup(
            uid,
            area: area,
            channels: channels,
            numbers: numbers,
          );
      return true;
    });
  }
}

final setupContactControllerProvider =
    AsyncNotifierProvider.autoDispose<SetupContactController, bool>(
      SetupContactController.new,
    );

/// What the photographer saved before, to prefill the form when editing.
class ContactSetupDraft {
  const ContactSetupDraft({this.area, this.channels, this.numbers});
  final ServiceArea? area;
  final ContactChannels? channels;
  final ContactNumbers? numbers;
}

final contactSetupPrefillProvider =
    FutureProvider.autoDispose<ContactSetupDraft>((ref) async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid == null) return const ContactSetupDraft();
      final repo = ref.read(photographerContactRepositoryProvider);
      return ContactSetupDraft(
        area: await repo.watchServiceArea(uid).first,
        channels: await repo.watchChannels(uid).first,
        numbers: await repo.watchNumbers(uid).first,
      );
    });
