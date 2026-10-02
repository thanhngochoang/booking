import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

final photographerContactRepositoryProvider =
    Provider<PhotographerContactRepository>(
      (ref) => FirestorePhotographerContactRepository(),
    );

/// Public contact flags of one photographer (what S05.04 shows).
final photographerChannelsProvider = StreamProvider.autoDispose
    .family<ContactChannels?, String>(
      (ref, photographerId) => ref
          .watch(photographerContactRepositoryProvider)
          .watchChannels(photographerId),
    );
