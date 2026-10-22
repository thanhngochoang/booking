// lib/data/instant/instant_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/instant/firestore_instant_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repository.dart';

/// Rebuilt when the signed-in user changes, so own-data streams follow it.
final instantRepositoryProvider = Provider<InstantRepository>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return FirestoreInstantRepository(uid: uid);
});

/// Chụp ngay is visible in the app (Decision 28; #202 flips [kInstantEnabled]).
final instantEnabledProvider = Provider<bool>((_) => kInstantEnabled);

final instantConfigProvider = FutureProvider.autoDispose<InstantConfig>(
  (ref) => ref.watch(instantRepositoryProvider).config(),
);

/// The signed-in photographer's presence (S14.01, S06.01 card).
final livePresenceProvider = StreamProvider.autoDispose<LiveShutterState?>(
  (ref) => ref.watch(instantRepositoryProvider).watchPresence(),
);

/// The signed-in photographer's pending offers, soonest expiry first (S14.02).
final pendingOffersProvider = StreamProvider.autoDispose<List<InstantOffer>>(
  (ref) => ref.watch(instantRepositoryProvider).watchPendingOffers(),
);

final instantRequestProvider = StreamProvider.autoDispose
    .family<InstantRequest?, String>(
      (ref, id) => ref.watch(instantRepositoryProvider).watchRequest(id),
    );

final instantTrackProvider = StreamProvider.autoDispose
    .family<InstantTrack?, String>(
      (ref, id) => ref.watch(instantRepositoryProvider).watchTrack(id),
    );

final instantCustomerContactProvider = StreamProvider.autoDispose
    .family<BookingContactSnapshot?, String>(
      (ref, id) =>
          ref.watch(instantRepositoryProvider).watchCustomerContact(id),
    );

/// The signed-in photographer's active job (S06.01 card, S14.03).
final myActiveInstantJobProvider = StreamProvider.autoDispose<InstantRequest?>(
  (ref) => ref.watch(instantRepositoryProvider).watchMyActiveJob(),
);
