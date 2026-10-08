import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';

/// The S09.01 grid of one filter: the posts read so far, newest first.
@immutable
class ProfilePostsState {
  const ProfilePostsState({
    this.posts = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.moreError = false,
  });

  final List<PostSummary> posts;

  /// Pass to the repository for the next page; null after the last page.
  final String? nextCursor;

  /// A next page is in flight; further [ProfilePostsController.loadMore] calls
  /// wait for nothing and do nothing.
  final bool loadingMore;

  /// The last next page failed; the posts read so far stay. The grid shows a
  /// retry row instead of asking again by itself.
  final bool moreError;
}

/// The signed-in user's own posts (`authorId` = uid) for S09.01, one list
/// per filter (null = all kinds), read with one-shot pages of [pageSize]
/// (no listener on `posts`). The shell keeps Hồ sơ mounted, so a revisit
/// does not re-read: the list reloads from its first page when the user
/// creates a post ([ownPostsChangedProvider]) or pulls to refresh. The list
/// of a filter not on screen is disposed (autoDispose) and read again when
/// its chip is chosen.
class ProfilePostsController extends AsyncNotifier<ProfilePostsState> {
  ProfilePostsController(this.kind);

  /// The kind chip; null for "Tất cả".
  final PostKind? kind;

  static const pageSize = 20;

  String? _uid;

  /// Bumped by every first-page load so a page from before a refresh never
  /// lands on the new list.
  int _generation = 0;

  @override
  Future<ProfilePostsState> build() async {
    _generation++;
    ref.watch(ownPostsChangedProvider);
    _uid = (await ref.watch(authStateProvider.future))?.uid;
    return _firstPage();
  }

  Future<ProfilePostsState> _firstPage() async {
    final uid = _uid;
    if (uid == null) {
      return const ProfilePostsState();
    }
    final page = await ref
        .read(postRepositoryProvider)
        .byAuthor(uid, kind: kind, limit: pageSize);
    return ProfilePostsState(posts: page.posts, nextCursor: page.nextCursor);
  }

  /// The next page, once per page: does nothing while one is in flight or
  /// after the last page. A failure keeps the posts and sets
  /// [ProfilePostsState.moreError]; calling again asks for the same page.
  Future<void> loadMore() async {
    final current = state.value;
    final uid = _uid;
    final cursor = current?.nextCursor;
    if (current == null || uid == null || cursor == null) {
      return;
    }
    if (current.loadingMore) {
      return;
    }
    final mine = _generation;
    state = AsyncData(
      ProfilePostsState(
        posts: current.posts,
        nextCursor: cursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(postRepositoryProvider)
          .byAuthor(uid, kind: kind, cursor: cursor, limit: pageSize);
      if (!ref.mounted || mine != _generation) {
        return;
      }
      state = AsyncData(
        ProfilePostsState(
          posts: [...current.posts, ...page.posts],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (!ref.mounted || mine != _generation) {
        return;
      }
      state = AsyncData(
        ProfilePostsState(
          posts: current.posts,
          nextCursor: cursor,
          moreError: true,
        ),
      );
    }
  }

  /// Pull to refresh and the first-load retry: reads the first page again.
  /// Returns false when the read failed. Posts already shown stay as they
  /// were (the caller tells the user); with nothing shown yet the state
  /// becomes the error, so the first-load error state stays.
  Future<bool> refresh() async {
    final mine = ++_generation;
    final next = await AsyncValue.guard(_firstPage);
    if (!ref.mounted || mine != _generation) {
      return next.hasValue;
    }
    if (next.hasValue || !state.hasValue) {
      state = next;
    } else if (state.requireValue.loadingMore) {
      // The next page in flight belongs to the old generation and will never
      // land: stop its spinner and offer the retry row instead.
      final shown = state.requireValue;
      state = AsyncData(
        ProfilePostsState(
          posts: shown.posts,
          nextCursor: shown.nextCursor,
          moreError: true,
        ),
      );
    }
    return next.hasValue;
  }
}

final profilePostsProvider = AsyncNotifierProvider.autoDispose
    .family<ProfilePostsController, ProfilePostsState, PostKind?>(
      ProfilePostsController.new,
    );

/// How many posts the user has in all and per kind (S09.01 counts row and
/// chips), counted by the server.
@immutable
class ProfilePostCounts {
  const ProfilePostCounts({required this.total, required this.byKind});

  final int total;
  final Map<PostKind, int> byKind;

  int of(PostKind kind) => byKind[kind] ?? 0;

  /// Kinds with at least one post, in chip order (work, real shoot, event).
  List<PostKind> get present => [
    for (final k in PostKind.values)
      if (of(k) > 0) k,
  ];
}

/// Four `count()` aggregations in parallel: all posts and one per kind
/// (about one read each, never the documents themselves). Counted again
/// when the user creates a post ([ownPostsChangedProvider]).
final profilePostCountsProvider = FutureProvider.autoDispose<ProfilePostCounts>(
  (ref) async {
    ref.watch(ownPostsChangedProvider);
    final uid = (await ref.watch(authStateProvider.future))?.uid;
    if (uid == null) {
      return const ProfilePostCounts(total: 0, byKind: {});
    }
    final repo = ref.watch(postRepositoryProvider);
    final counts = await Future.wait([
      repo.countByAuthor(uid),
      for (final k in PostKind.values) repo.countByAuthor(uid, kind: k),
    ]);
    return ProfilePostCounts(
      total: counts.first,
      byKind: {
        for (var i = 0; i < PostKind.values.length; i++)
          PostKind.values[i]: counts[i + 1],
      },
    );
  },
);
