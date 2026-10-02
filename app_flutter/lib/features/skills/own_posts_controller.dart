// lib/features/skills/own_posts_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';

class OwnPostsState {
  const OwnPostsState({
    this.posts = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.capped = false,
  });

  final List<PostThumb> posts;
  final String? nextCursor;
  final bool loadingMore;

  /// The next page failed; scrolling no longer asks for it, the sheet offers
  /// a retry row ([OwnPostsController.retryLoadMore]).
  final bool loadMoreFailed;

  /// The session read [OwnPostsController.maxPages] pages and stopped; more
  /// exist, the sheet offers a manual "Tải thêm".
  final bool capped;

  bool get hasMore => nextCursor != null;
}

/// The signed-in photographer's own posts for S40, a page at a time
/// (one-shot reads; nothing stays open when the sheet closes).
///
/// `byPhotographer` also returns customers' real-shoot posts about the
/// photographer, filtered out here; a page can therefore come back short or
/// empty while more exist, so one call reads up to [maxPagesPerLoad] pages
/// (one after another) until it has [pageSize] own posts or runs out; the
/// bound only guards against a runaway loop.
class OwnPostsController extends AsyncNotifier<OwnPostsState> {
  static const pageSize = 30;
  static const maxPagesPerLoad = 20;

  /// Total pages one sheet session reads on its own.
  static const maxPages = 100;

  late String _uid;
  int _pages = 0;

  @override
  Future<OwnPostsState> build() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) throw StateError('signed_out');
    _uid = uid;
    _pages = 0;
    final chunk = await _fetch(null);
    if (chunk.posts.isEmpty && chunk.failed) {
      Error.throwWithStackTrace(chunk.error!, chunk.stackTrace!);
    }
    return OwnPostsState(
      posts: chunk.posts,
      nextCursor: chunk.cursor,
      loadMoreFailed: chunk.failed,
      capped: _capped(chunk.cursor),
    );
  }

  bool _capped(String? cursor) => cursor != null && _pages >= maxPages;

  /// Only what the photographer posted themselves, with a photo.
  List<PostThumb> _thumbs(PostPage page) => [
    for (final p in page.posts)
      if (p.authorId == _uid && p.images.isNotEmpty)
        PostThumb(id: p.id, imageUrl: p.cover.url),
  ];

  /// Reads pages from [cursor] until [pageSize] own posts, no cursor, or
  /// [maxPagesPerLoad] pages. On a failure keeps what it got and the cursor
  /// of the page that failed.
  Future<_Chunk> _fetch(String? cursor) async {
    final repo = ref.read(postRepositoryProvider);
    final posts = <PostThumb>[];
    var next = cursor;
    for (var i = 0; i < maxPagesPerLoad && _pages < maxPages; i++) {
      final PostPage page;
      try {
        page = await repo.byPhotographer(_uid, cursor: next, limit: pageSize);
      } catch (e, st) {
        return _Chunk(posts, next, error: e, stackTrace: st);
      }
      if (!ref.mounted) break;
      _pages++;
      posts.addAll(_thumbs(page));
      next = page.nextCursor;
      if (next == null || posts.length >= pageSize) break;
    }
    return _Chunk(posts, next);
  }

  /// The next page, from scrolling; does nothing after a failure until
  /// [retryLoadMore].
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadMoreFailed) return;
    await _loadMore(current);
  }

  /// The "Tải thêm" row after the session cap: one more chunk.
  Future<void> loadMoreManually() async {
    final current = state.value;
    if (current == null || !current.capped) return;
    _pages = maxPages - maxPagesPerLoad;
    await _loadMore(current);
  }

  /// The retry row: asks again for the page that failed.
  Future<void> retryLoadMore() async {
    final current = state.value;
    if (current == null || !current.loadMoreFailed) return;
    await _loadMore(current);
  }

  Future<void> _loadMore(OwnPostsState current) async {
    final cursor = current.nextCursor;
    if (current.loadingMore || cursor == null) return;
    state = AsyncData(
      OwnPostsState(
        posts: current.posts,
        nextCursor: cursor,
        loadingMore: true,
      ),
    );
    final chunk = await _fetch(cursor);
    if (!ref.mounted) return;
    state = AsyncData(
      OwnPostsState(
        posts: [...current.posts, ...chunk.posts],
        nextCursor: chunk.cursor,
        loadMoreFailed: chunk.failed,
        capped: _capped(chunk.cursor),
      ),
    );
  }
}

class _Chunk {
  _Chunk(this.posts, this.cursor, {this.error, this.stackTrace});
  final List<PostThumb> posts;
  final String? cursor;
  final Object? error;
  final StackTrace? stackTrace;
  bool get failed => error != null;
}

final ownPostsProvider =
    AsyncNotifierProvider.autoDispose<OwnPostsController, OwnPostsState>(
      OwnPostsController.new,
      retry: (_, _) => null,
    );
