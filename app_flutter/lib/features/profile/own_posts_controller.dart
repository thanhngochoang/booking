import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';

/// The S09.01 grid of one filter: the posts read so far, newest first.
@immutable
class OwnPostsState {
  const OwnPostsState({
    this.posts = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.moreError = false,
  });

  final List<PostSummary> posts;

  /// Pass to the repository for the next page; null after the last page.
  final String? nextCursor;

  /// A next page is in flight; further [OwnPostsController.loadMore] calls
  /// wait for nothing and do nothing.
  final bool loadingMore;

  /// The last next page failed; the posts read so far stay. The grid shows a
  /// retry row instead of asking again by itself.
  final bool moreError;
}

/// The signed-in user's own posts (`authorId` = uid) for S09.01, one list
/// per filter (null = all kinds), read with one-shot pages of [pageSize]
/// (no listener on `posts`). autoDispose: re-read on each visit.
class OwnPostsController extends AsyncNotifier<OwnPostsState> {
  OwnPostsController(this.kind);

  /// The kind chip; null for "Tất cả".
  final PostKind? kind;

  static const pageSize = 20;

  String? _uid;

  /// Bumped by every first-page load so a page from before a refresh never
  /// lands on the new list.
  int _generation = 0;

  @override
  Future<OwnPostsState> build() async {
    _generation++;
    _uid = (await ref.watch(authStateProvider.future))?.uid;
    return _firstPage();
  }

  Future<OwnPostsState> _firstPage() async {
    final uid = _uid;
    if (uid == null) {
      return const OwnPostsState();
    }
    final page = await ref
        .read(postRepositoryProvider)
        .byAuthor(uid, kind: kind, limit: pageSize);
    return OwnPostsState(posts: page.posts, nextCursor: page.nextCursor);
  }

  /// The next page, once per page: does nothing while one is in flight or
  /// after the last page. A failure keeps the posts and sets
  /// [OwnPostsState.moreError]; calling again asks for the same page.
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
      OwnPostsState(
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
        OwnPostsState(
          posts: [...current.posts, ...page.posts],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (!ref.mounted || mine != _generation) {
        return;
      }
      state = AsyncData(
        OwnPostsState(
          posts: current.posts,
          nextCursor: cursor,
          moreError: true,
        ),
      );
    }
  }

  /// Pull to refresh and the first-load retry: reads the first page again.
  /// A failed reload shows the error state.
  Future<void> refresh() async {
    final mine = ++_generation;
    final next = await AsyncValue.guard(_firstPage);
    if (ref.mounted && mine == _generation) {
      state = next;
    }
  }
}

final ownPostsProvider = AsyncNotifierProvider.autoDispose
    .family<OwnPostsController, OwnPostsState, PostKind?>(
      OwnPostsController.new,
    );

/// How many posts the user has in all and per kind (S09.01 counts row and
/// chips), counted by the server.
@immutable
class OwnPostCounts {
  const OwnPostCounts({required this.total, required this.byKind});

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
/// (about one read each, never the documents themselves).
final ownPostCountsProvider = FutureProvider.autoDispose<OwnPostCounts>((
  ref,
) async {
  final uid = (await ref.watch(authStateProvider.future))?.uid;
  if (uid == null) {
    return const OwnPostCounts(total: 0, byKind: {});
  }
  final repo = ref.watch(postRepositoryProvider);
  final counts = await Future.wait([
    repo.countByAuthor(uid),
    for (final k in PostKind.values) repo.countByAuthor(uid, kind: k),
  ]);
  return OwnPostCounts(
    total: counts.first,
    byKind: {
      for (var i = 0; i < PostKind.values.length; i++)
        PostKind.values[i]: counts[i + 1],
    },
  );
});
