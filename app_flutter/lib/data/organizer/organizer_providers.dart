// lib/data/organizer/organizer_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/organizer/firestore_organizer_repository.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_repository.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';

/// Rebuilt when the signed-in user changes, so own-data streams follow it.
final organizerRepositoryProvider = Provider<OrganizerRepository>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return FirestoreOrganizerRepository(
    uid: uid,
    uploader: ref.watch(mediaUploaderProvider),
  );
});

/// My organizer document; null when I am not an organizer.
final myOrganizerProvider = StreamProvider.autoDispose<Organizer?>(
  (ref) => ref.watch(organizerRepositoryProvider).watchMine(),
);

final organizerProvider = StreamProvider.autoDispose.family<Organizer?, String>(
  (ref, uid) => ref.watch(organizerRepositoryProvider).watch(uid),
);

/// My spot claims and proposals, newest first (S30.02 pending / rejected).
final mySpotClaimsProvider = StreamProvider.autoDispose<List<SpotClaim>>(
  (ref) => ref.watch(organizerRepositoryProvider).watchMyClaims(),
);

/// The spots I manage (`managedSpotIds`), in that order; spots that no
/// longer read are left out.
final managedSpotsProvider = FutureProvider.autoDispose<List<Spot>>((
  ref,
) async {
  final org = await ref.watch(myOrganizerProvider.future);
  if (org == null || org.managedSpotIds.isEmpty) return const [];
  final spots = ref.watch(spotRepositoryProvider);
  final out = await Future.wait(org.managedSpotIds.map(spots.spot));
  return out.whereType<Spot>().toList();
});

/// Residents of a spot (S29.02 tags, S30.03 tab), expired rows included.
final spotResidentsProvider = StreamProvider.autoDispose
    .family<List<Resident>, String>(
      (ref, spotId) => ref.watch(spotRepositoryProvider).watchResidents(spotId),
    );

/// The spot's entry-ticket event on sale (`open` / `full`), or null.
final entryEventProvider = StreamProvider.autoDispose
    .family<EntryEvent?, String>(
      (ref, spotId) =>
          ref.watch(spotRepositoryProvider).watchEntryEvent(spotId),
    );

/// Whether the spot is ticketed (`Spot.ticketedWith` its entry event on
/// sale); false while the spot loads or when it does not read.
final spotTicketedProvider = Provider.autoDispose.family<bool, String>((
  ref,
  spotId,
) {
  final spot = ref.watch(spotProvider(spotId)).value;
  if (spot == null) return false;
  return spot.ticketedWith(ref.watch(entryEventProvider(spotId)).value);
});

/// `entry_days/{eventId}_{day}`.
final entryDayProvider = StreamProvider.autoDispose
    .family<EntryDay?, ({String eventId, String day})>(
      (ref, k) => ref
          .watch(organizerRepositoryProvider)
          .watchEntryDay(k.eventId, k.day),
    );

/// My gate staff (S30.06).
final gateStaffProvider = StreamProvider.autoDispose<List<GateStaff>>(
  (ref) => ref.watch(organizerRepositoryProvider).watchGateStaff(),
);

/// Invites and active rows naming me as gate staff.
final myGateInvitesProvider = StreamProvider.autoDispose<List<GateStaff>>(
  (ref) => ref.watch(organizerRepositoryProvider).watchMyGateInvites(),
);
