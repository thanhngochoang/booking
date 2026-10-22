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

/// The photographer's position, listened to only while the request is
/// `en_route`: before that the track does not exist and a denied listen ends
/// for good, so the provider re-subscribes when the status flips.
final instantTrackProvider = StreamProvider.autoDispose
    .family<InstantTrack?, String>((ref, id) {
      final enRoute = ref.watch(
        instantRequestProvider(id)
            .select((r) => r.value?.status == InstantStatus.enRoute),
      );
      if (!enRoute) return Stream.value(null);
      return ref.watch(instantRepositoryProvider).watchTrack(id);
    });

final instantCustomerContactProvider = StreamProvider.autoDispose
    .family<BookingContactSnapshot?, String>(
      (ref, id) =>
          ref.watch(instantRepositoryProvider).watchCustomerContact(id),
    );

/// The signed-in photographer's active job (S06.01 card, S14.03).
final myActiveInstantJobProvider = StreamProvider.autoDispose<InstantRequest?>(
  (ref) => ref.watch(instantRepositoryProvider).watchMyActiveJob(),
);
