import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/award/firestore_award_repository.dart';

final awardRepositoryProvider = Provider<AwardRepository>(
  (ref) => FirestoreAwardRepository(),
);

/// The signed-in photographer's own awards, every status; empty when signed
/// out.
final myAwardsProvider = StreamProvider.autoDispose<List<Award>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) {
    return Stream.value(const <Award>[]);
  }
  return ref.watch(awardRepositoryProvider).watchMine(uid);
});

/// Approved awards shown on a photographer's profile.
final approvedAwardsProvider = StreamProvider.autoDispose
    .family<List<Award>, String>(
      (ref, photographerId) =>
          ref.watch(awardRepositoryProvider).watchApproved(photographerId),
    );
