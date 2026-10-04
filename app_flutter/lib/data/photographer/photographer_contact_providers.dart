import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/http/api_providers.dart';
import 'package:photobooking/data/photographer/http_photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

final photographerContactRepositoryProvider =
    Provider<PhotographerContactRepository>((ref) {
      if (ref
          .watch(backendConfigProvider)
          .uses(SelfhostedRepo.photographerContact)) {
        final repo = HttpPhotographerContactRepository(
          api: ref.watch(apiClientProvider),
        );
        ref.onDispose(repo.dispose);
        return repo;
      }
      return FirestorePhotographerContactRepository();
    });

/// Public contact flags of one photographer (what S05.04 shows).
final photographerChannelsProvider = StreamProvider.autoDispose
    .family<ContactChannels?, String>(
      (ref, photographerId) => ref
          .watch(photographerContactRepositoryProvider)
          .watchChannels(photographerId),
    );
