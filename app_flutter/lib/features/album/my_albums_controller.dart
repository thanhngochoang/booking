// lib/features/album/my_albums_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';

/// Product limits (plan C, Decisions 4): the server enforces them too.
const int kMaxAlbums = 30;
const int kMaxAlbumPosts = 200;

/// `movePostsToAlbum` takes at most this many posts per call.
const int kMaxMovePerCall = 50;

/// Page size of the post lists in the add-posts sheet.
const int kPostPickPage = 30;

/// S24.02: the order of the owner's albums while a change is being saved.
///
/// [pending] is the order the user just chose; the list shows it at once and
/// it is dropped when the saved order arrives or the save fails.
@immutable
class AlbumOrderState {
  const AlbumOrderState({this.pending, this.saving = false});

  /// Album ids in the order just chosen, or null when the stored order shows.
  final List<String>? pending;
  final bool saving;
}

class AlbumOrderController extends Notifier<AlbumOrderState> {
  bool _echoed = false;

  @override
  AlbumOrderState build() => const AlbumOrderState();

  /// Shows [ids] and saves them. Returns true when saved; on failure the
  /// stored order shows again and false is returned.
  Future<bool> reorder(List<String> ids) async {
    _echoed = false;
    state = AlbumOrderState(pending: ids, saving: true);
    try {
      await ref.read(albumRepositoryProvider).reorder(ids);
    } catch (_) {
      if (ref.mounted) {
        state = const AlbumOrderState();
      }
      return false;
    }
    if (ref.mounted) {
      // The stored order may already have come back while saving.
      state = _echoed ? const AlbumOrderState() : AlbumOrderState(pending: ids);
    }
    return true;
  }

  /// The stored order has caught up (or changed under us): stop overriding it.
  void settle() {
    if (state.pending == null) {
      return;
    }
    if (state.saving) {
      _echoed = true;
    } else {
      state = const AlbumOrderState();
    }
  }
}

final albumOrderProvider =
    NotifierProvider.autoDispose<AlbumOrderController, AlbumOrderState>(
      AlbumOrderController.new,
    );

/// Which of the owner's `work` posts the add-posts sheet lists.
enum MyPostsFilter { unsorted, all }

@immutable
class MyPostsState {
  const MyPostsState({
    this.posts = const [],
    this.cursor,
    this.loadingMore = false,
  });

  final List<PostSummary> posts;
  final String? cursor;
  final bool loadingMore;

  bool get hasMore => cursor != null;

  /// "12" when the list is complete, "12+" while more may follow.
  String get countLabel => hasMore ? '${posts.length}+' : '${posts.length}';
}

/// The owner's own posts for S24.02 / S24.04: `work` posts newest first, pages
/// of 30 read with `byPhotographer`. [MyPostsFilter.unsorted] keeps only posts
/// without an album, so it reads on until a page of 30 is full or posts run out.
class MyPostsController extends AsyncNotifier<MyPostsState> {
  MyPostsController(this.filter);

  final MyPostsFilter filter;

  bool _keep(PostSummary p) =>
      p.kind == PostKind.work &&
      (filter == MyPostsFilter.all || p.albumId == null);

  /// Reads pages until [want] more posts qualify or the posts run out.
  Future<MyPostsState> _read(MyPostsState from, int want) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return const MyPostsState();
    }
    final repo = ref.read(postRepositoryProvider);
    final posts = [...from.posts];
    var cursor = from.cursor;
    var found = 0;
    do {
      final page = await repo.byPhotographer(
        uid,
        cursor: cursor,
        limit: kPostPickPage,
      );
      final kept = page.posts.where(_keep).toList();
      posts.addAll(kept);
      found += kept.length;
      cursor = page.nextCursor;
    } while (cursor != null && found < want);
    return MyPostsState(posts: posts, cursor: cursor);
  }

  @override
  Future<MyPostsState> build() {
    ref.watch(authStateProvider);
    return _read(const MyPostsState(), kPostPickPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }
    state = AsyncData(
      MyPostsState(
        posts: current.posts,
        cursor: current.cursor,
        loadingMore: true,
      ),
    );
    try {
      final next = await _read(current, kPostPickPage);
      if (ref.mounted) {
        state = AsyncData(next);
      }
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(
          MyPostsState(posts: current.posts, cursor: current.cursor),
        );
      }
    }
  }
}

final myPostsProvider = AsyncNotifierProvider.autoDispose
    .family<MyPostsController, MyPostsState, MyPostsFilter>(
      MyPostsController.new,
      retry: (_, _) => null,
    );
