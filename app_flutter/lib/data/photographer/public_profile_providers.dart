import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/photographer/firestore_public_profile_repository.dart';
import 'package:photobooking/data/photographer/public_profile.dart';

final publicProfileRepositoryProvider = Provider<PublicProfileRepository>(
  (ref) => FirestorePublicProfileRepository(),
);

/// S03's profile, read once per visit (pull the screen again to refresh;
/// the owner's edits invalidate it on return).
final photographerProfileProvider = FutureProvider.autoDispose
    .family<PhotographerProfile?, String>(
      (ref, uid) => ref.watch(publicProfileRepositoryProvider).load(uid),
    );
