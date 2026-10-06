// lib/features/album/album_detail_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';

/// S24.01: one album; null when it does not exist.
final albumProvider = FutureProvider.autoDispose.family<AlbumSummary?, String>(
  (ref, albumId) => ref.watch(albumRepositoryProvider).album(albumId),
  retry: (_, _) => null,
);

@immutable
class AlbumPostsState {
  const AlbumPostsState({
    this.posts = const [],
    this.cursor,
    this.loadingMore = false,
  });

  final List<PostSummary> posts;
  final String? cursor;
  final bool loadingMore;

  bool get hasMore => cursor != null;

  AlbumPostsState copyWith({
    List<PostSummary>? posts,
    String? cursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) => AlbumPostsState(
    posts: posts ?? this.posts,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The album's posts in `albumPosition` order, 24 at a time.
class AlbumPostsController extends AsyncNotifier<AlbumPostsState> {
  AlbumPostsController(this.albumId);

  final String albumId;
  static const pageSize = 24;

  @override
  Future<AlbumPostsState> build() async {
    final page = await ref
        .watch(postRepositoryProvider)
        .byAlbum(albumId, limit: pageSize);
    return AlbumPostsState(posts: page.posts, cursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(postRepositoryProvider)
          .byAlbum(albumId, cursor: current.cursor, limit: pageSize);
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(
        AlbumPostsState(
          posts: [...current.posts, ...page.posts],
          cursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(current); // keep what is shown; the button stays
    }
  }

  /// Arranging needs every post (the server wants the full id list). An
  /// album holds at most 200 posts, so this is at most nine pages.
  Future<void> loadAll() async {
    while (ref.mounted && (state.value?.hasMore ?? false)) {
      final before = state.value!.posts.length;
      await loadMore();
      if ((state.value?.posts.length ?? before) == before) {
        return; // a page failed; do not loop forever
      }
    }
  }

  /// Shows [postIds] order at once and saves it; puts the old order back and
  /// returns false when the save fails. Returns true when nothing changed.
  Future<bool> reorder(List<String> postIds) async {
    final current = state.value;
    if (current == null) {
      return false;
    }
    final byId = {for (final p in current.posts) p.id: p};
    if (postIds.length != byId.length || !postIds.every(byId.containsKey)) {
      return false;
    }
    final next = [for (final id in postIds) byId[id]!];
    state = AsyncData(current.copyWith(posts: next));
    try {
      await ref.read(albumRepositoryProvider).reorderPosts(albumId, postIds);
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(current);
      }
      return false;
    }
  }

  /// Takes one post out of the album (it stays on the timeline).
  Future<bool> remove(String postId) async {
    try {
      await ref.read(albumRepositoryProvider).movePosts(null, [postId]);
    } catch (_) {
      return false;
    }
    if (!ref.mounted) {
      return true;
    }
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          posts: [
            for (final p in current.posts)
              if (p.id != postId) p,
          ],
        ),
      );
    }
    ref.invalidate(albumProvider(albumId));
    return true;
  }
}

final albumPostsProvider = AsyncNotifierProvider.autoDispose
    .family<AlbumPostsController, AlbumPostsState, String>(
      AlbumPostsController.new,
      retry: (_, _) => null,
    );
