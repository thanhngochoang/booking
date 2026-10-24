import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_card.dart';
import 'package:photobooking/l10n/app_localizations.dart';

// S27.05 data: the studio's posts (listener), the applicants of one post
// (`get`, refreshed after each answer), their sample posts, and what a
// refused answer says.

/// The signed-in studio's posts of every status, newest first (10).
final studioRecruitPostsProvider =
    StreamProvider.autoDispose<List<RecruitPost>>((ref) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(recruitRepositoryProvider).watchStudioPosts(uid);
    });

/// `applied` applications of one of the studio's posts, newest first.
final studioRecruitApplicantsProvider = FutureProvider.autoDispose
    .family<List<RecruitApplication>, String>((ref, postId) async {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return const [];
      return ref.watch(recruitRepositoryProvider).applicantsOf(uid, postId);
    }, retry: (_, _) => null);

/// The sample posts of an application, keyed by `ids.join(',')` (the
/// order the applicant chose); missing or deleted ones are left out.
final recruitSamplesProvider = FutureProvider.autoDispose
    .family<List<PostSummary>, String>((ref, joined) async {
      final ids = [
        for (final id in joined.split(','))
          if (id.isNotEmpty) id,
      ];
      if (ids.isEmpty) return const [];
      final found = await ref.watch(postRepositoryProvider).byIds(ids);
      return [for (final id in ids) ?found[id]];
    }, retry: (_, _) => null);

/// The post S27.05 shows applicants for: [requested] (query `post`) when
/// it is one of [posts], else the first one still open at [now], else the
/// newest; null without posts.
RecruitPost? selectedRecruitPost(
  List<RecruitPost> posts,
  String? requested,
  DateTime now,
) {
  for (final p in posts) {
    if (p.id == requested) return p;
  }
  for (final p in posts) {
    if (recruitPostIsOpen(p, now)) return p;
  }
  return posts.isEmpty ? null : posts.first;
}

/// "12/11": the Vietnam day a recruiting block ends.
String recruitBlockedDate(DateTime until) => formatDayMonth(toVn(until));

/// What to say when answering [name]'s application is refused (S26 errors
/// for a member post, spec §3.3: the exact one).
String recruitRespondErrorText(
  Object error,
  AppLocalizations l, {
  required String name,
  DateTime? blockedUntil,
}) {
  final e = recruitErrorOf(error);
  return switch (e.code) {
    RecruitErrorCode.membershipConflict => l.recruitAcceptConflict(name),
    RecruitErrorCode.cooldown => l.recruitAcceptCooldown(name),
    RecruitErrorCode.studioFull => l.recruitAcceptStudioFull,
    RecruitErrorCode.collabFull => l.recruitAcceptCollabFull,
    RecruitErrorCode.rateLimited => l.recruitErrorRateLimited,
    RecruitErrorCode.recruitBlocked when blockedUntil != null =>
      l.recruitBlocked(recruitBlockedDate(blockedUntil)),
    RecruitErrorCode.deadlinePassed => l.recruitErrorClosed,
    RecruitErrorCode.notAcceptingOrders => l.recruitAcceptNotAccepting(name),
    RecruitErrorCode.conflict => l.studioErr_conflict,
    RecruitErrorCode.network => l.authErrorNetwork,
    _ => l.recruitErrorGeneric,
  };
}

/// What to say when closing or renewing a post is refused.
String recruitPostActionErrorText(Object error, AppLocalizations l) =>
    switch (recruitErrorOf(error).code) {
      RecruitErrorCode.rateLimited => l.recruitErrorRateLimited,
      RecruitErrorCode.deadlinePassed ||
      RecruitErrorCode.conflict => l.recruitErrorClosed,
      RecruitErrorCode.network => l.authErrorNetwork,
      _ => l.recruitErrorGeneric,
    };
