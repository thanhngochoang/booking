import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/studio/firestore_studio_repository.dart';
import 'package:photobooking/data/studio/studio_repository.dart';

// The assignee's bookings are #134's `assignedBookingsProvider` /
// `myWorkBookingsProvider` (booking_providers.dart), not redefined here.

final studioRepositoryProvider = Provider<StudioRepository>(
  (ref) => FirestoreStudioRepository(clock: ref.watch(clockProvider)),
);

/// The signed-in studio's open relations: members, invites and requests
/// (S26.01).
final myStudioRelationsProvider =
    StreamProvider.autoDispose<List<StudioRelation>>((ref) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return const Stream.empty();
      return ref.watch(studioRepositoryProvider).watchStudioRelations(uid);
    });

/// The signed-in photographer's open relations: its studio, invites it got
/// and its own request (S26.03).
final myMemberRelationsProvider =
    StreamProvider.autoDispose<List<StudioRelation>>((ref) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return const Stream.empty();
      return ref.watch(studioRepositoryProvider).watchMemberRelations(uid);
    });

/// Actions the signed-in user has left today; the argument is `true` for the
/// studio side, `false` for the member side.
final studioQuotaProvider = StreamProvider.autoDispose
    .family<StudioQuota, bool>((ref, studio) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return const Stream.empty();
      return ref
          .watch(studioRepositoryProvider)
          .watchQuota(uid, studio: studio);
    });

/// The public members row of a studio (S03.01): the first 10 by join date;
/// the studio's `memberCount` gives "+n".
final studioMembersProvider = FutureProvider.autoDispose
    .family<List<PhotographerSummary>, String>(
      (ref, studioId) =>
          ref.watch(photographerRepositoryProvider).membersOf(studioId),
    );
