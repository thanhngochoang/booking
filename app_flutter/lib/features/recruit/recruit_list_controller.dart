import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';

/// What S27.01 shows for one filter: the loaded posts ordered by match score
/// then date (Decision 7), the cursor of the next page, and whether the
/// viewer may see posts at all (R3).
@immutable
class RecruitListState {
  const RecruitListState({
    required this.visible,
    this.posts = const [],
    this.viewerKeys = const [],
    this.next,
    this.loadingMore = false,
  });

  /// Not a provider account (customer, customer mode, signed out): nothing
  /// was queried, the screen shows only the R3 note.
  static const hidden = RecruitListState(visible: false);

  final bool visible;
  final List<RecruitPost> posts;

  /// The viewer's `recruitMatchKeys`, to tag score-2 posts.
  final List<String> viewerKeys;

  /// Cursor of the next page; null on the last one.
  final Object? next;
  final bool loadingMore;

  bool get hasMore => next != null;

  bool matches(RecruitPost p) => recruitMatchScore(p, viewerKeys) == 2;

  RecruitListState copyWith({
    List<RecruitPost>? posts,
    Object? Function()? next,
    bool? loadingMore,
  }) => RecruitListState(
    visible: visible,
    posts: posts ?? this.posts,
    viewerKeys: viewerKeys,
    next: next == null ? this.next : next(),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Pages of open posts for one [RecruitFilter] (20 per `get`, Decision 7).
/// Only a provider account queries (R3, Decision 2).
class RecruitListController extends AsyncNotifier<RecruitListState> {
  RecruitListController(this.filter);

  final RecruitFilter filter;

  static const pageSize = 20;

  /// How long a filter's loaded pages outlive their last listener: going to
  /// another S06.01 segment and back does not query again.
  static const keepFor = Duration(minutes: 2);

  @override
  Future<RecruitListState> build() async {
    final link = ref.keepAlive();
    Timer? release;
    ref.onCancel(() => release = Timer(keepFor, link.close));
    ref.onResume(() => release?.cancel());
    ref.onDispose(() => release?.cancel());
    final facts = await ref.watch(myProviderFactsProvider.future);
    if (facts == null || !facts.isProviderAccount) {
      return RecruitListState.hidden;
    }
    final page = await ref
        .read(recruitRepositoryProvider)
        .list(filter, limit: pageSize);
    return RecruitListState(
      visible: true,
      posts: sortByMatch(page.items, facts.recruitMatchKeys),
      viewerKeys: facts.recruitMatchKeys,
      next: page.next,
    );
  }

  /// "Xem thêm": appends the next page and re-sorts everything loaded. A
  /// failure keeps the list and its cursor (the button stays) and rethrows
  /// for the screen to say so.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(recruitRepositoryProvider)
          .list(filter, after: current.next, limit: pageSize);
      if (!ref.mounted) return;
      final seen = {for (final p in current.posts) p.id};
      state = AsyncData(
        current.copyWith(
          posts: sortByMatch([
            ...current.posts,
            for (final p in page.items)
              if (!seen.contains(p.id)) p,
          ], current.viewerKeys),
          next: () => page.next,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (ref.mounted) state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }
}

final recruitListProvider = AsyncNotifierProvider.autoDispose
    .family<RecruitListController, RecruitListState, RecruitFilter>(
      RecruitListController.new,
      retry: (_, _) => null,
    );
