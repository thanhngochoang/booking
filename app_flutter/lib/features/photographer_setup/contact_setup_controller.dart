import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/provider_providers.dart';
import 'package:photobooking/data/photographer/provider_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';

/// Saves S08.05. Its value turns true once the save went through.
class SetupContactController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> save({
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
    StudioAddressInput? studioAddress,
  }) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // A studio's address goes first: finishing is refused without it.
      if (studioAddress != null) {
        await ref
            .read(providerRepositoryProvider)
            .setStudioAddress(studioAddress);
      }
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
  const ContactSetupDraft({
    this.area,
    this.channels,
    this.numbers,
    this.providerType = ProviderType.individual,
    this.studioAddress,
    this.studioDistrict,
  });
  final ServiceArea? area;
  final ContactChannels? channels;
  final ContactNumbers? numbers;

  /// Studio shows the address block; unknown (offline) reads as individual.
  final ProviderType providerType;
  final StudioAddressInput? studioAddress;

  /// The public district on the profile, when the private address is unread.
  final String? studioDistrict;
}

final contactSetupPrefillProvider =
    FutureProvider.autoDispose<ContactSetupDraft>((ref) async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid == null) return const ContactSetupDraft();
      final repo = ref.read(photographerContactRepositoryProvider);
      final area = await repo.watchServiceArea(uid).first;
      final channels = await repo.watchChannels(uid).first;
      final numbers = await repo.watchNumbers(uid).first;
      var type = ProviderType.individual;
      String? district;
      StudioAddressInput? address;
      try {
        final p = await ref.read(publicProfileRepositoryProvider).load(uid);
        type = p?.summary.providerType ?? type;
        district = p?.summary.studioDistrict;
        if (type == ProviderType.studio) {
          address = await ref
              .read(providerRepositoryProvider)
              .myStudioAddress(uid);
        }
      } catch (_) {
        // Offline: the form still opens, the server checks at finish.
      }
      return ContactSetupDraft(
        area: area,
        channels: channels,
        numbers: numbers,
        providerType: type,
        studioAddress: address,
        studioDistrict: district,
      );
    });
