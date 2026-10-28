import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/recruit/firestore_recruit_repository.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';

final recruitRepositoryProvider = Provider<RecruitRepository>(
  (ref) => FirestoreRecruitRepository(),
);

/// The signed-in account's role and photographer fields; null when signed
/// out or without a photographer document.
final myProviderFactsProvider = StreamProvider.autoDispose<ProviderFacts?>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(recruitRepositoryProvider).watchMyProviderFacts(uid);
});

/// The signed-in provider's counters and quotas (zeros when signed out).
final myRecruitCountersProvider = StreamProvider.autoDispose<RecruitCounters>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(RecruitCounters.empty);
  return ref.watch(recruitRepositoryProvider).watchCounters(uid);
});

/// Open posts of a studio (S03.01 "Đang tuyển"); call it only for provider
/// viewers (R3: the rules refuse anyone else).
final studioOpenRecruitCountProvider = FutureProvider.autoDispose
    .family<int, String>(
      (ref, studioId) =>
          ref.watch(recruitRepositoryProvider).openCountOf(studioId),
    );
