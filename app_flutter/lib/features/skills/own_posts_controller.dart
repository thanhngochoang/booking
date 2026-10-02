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
  });

  final List<PostThumb> posts;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;
}

/// The signed-in photographer's own posts for S40, a page at a time
/// (one-shot reads; nothing stays open when the sheet closes).
class OwnPostsController extends AsyncNotifier<OwnPostsState> {
  static const pageSize = 30;

  late String _uid;
  String? _failedCursor;

  @override
  Future<OwnPostsState> build() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) throw StateError('signed_out');
    _uid = uid;
    _failedCursor = null;
    final page = await ref
        .read(postRepositoryProvider)
        .byPhotographer(uid, limit: pageSize);
    return OwnPostsState(posts: _thumbs(page), nextCursor: page.nextCursor);
  }

  /// Only what the photographer posted themselves, with a photo.
  List<PostThumb> _thumbs(PostPage page) => [
    for (final p in page.posts)
      if (p.authorId == _uid && p.images.isNotEmpty)
        PostThumb(id: p.id, imageUrl: p.cover.url),
  ];

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null ||
        current.loadingMore ||
        cursor == null ||
        cursor == _failedCursor) {
      return;
    }
    final repo = ref.read(postRepositoryProvider);
    state = AsyncData(
      OwnPostsState(
        posts: current.posts,
        nextCursor: cursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await repo.byPhotographer(
        _uid,
        cursor: cursor,
        limit: pageSize,
      );
      if (!ref.mounted) return;
      state = AsyncData(
        OwnPostsState(
          posts: [...current.posts, ..._thumbs(page)],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      // Shown posts stay; scrolling does not hammer a failing network.
      _failedCursor = cursor;
      if (ref.mounted) state = AsyncData(current);
    }
  }
}

final ownPostsProvider =
    AsyncNotifierProvider.autoDispose<OwnPostsController, OwnPostsState>(
      OwnPostsController.new,
      retry: (_, _) => null,
    );
