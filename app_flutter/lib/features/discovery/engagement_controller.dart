// lib/features/discovery/engagement_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/features/discovery/auth_reset.dart';

@immutable
class EngagementView {
  const EngagementView({
    this.liked = false,
    this.saved = false,
    this.likeCount = 0,
    this.saveCount = 0,
  });

  final bool liked;
  final bool saved;
  final int likeCount;
  final int saveCount;

  EngagementView copyWith({
    bool? liked,
    bool? saved,
    int? likeCount,
    int? saveCount,
  }) => EngagementView(
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
    likeCount: likeCount ?? this.likeCount,
    saveCount: saveCount ?? this.saveCount,
  );
}

int _plusMinus(int count, bool on) =>
    on ? count + 1 : (count > 0 ? count - 1 : 0);

/// The viewer's likes and saves, keyed by post id, with optimistic updates.
/// Counts shown are the post's server count plus the viewer's own change.
class EngagementController extends Notifier<Map<String, EngagementView>> {
  final _busy = <String>{};

  @override
  Map<String, EngagementView> build() {
    resetOnUserChange(ref, () {
      _busy.clear();
      state = const {};
    });
    return const {};
  }

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;
  PostEngagementRepository get _repo =>
      ref.read(postEngagementRepositoryProvider);

  /// Registers counts for [posts] and fetches the viewer's saved marks for the
  /// whole list in one batch. A failed batch only leaves the bookmarks empty.
  Future<void> seed(Iterable<PostSummary> posts) async {
    final list = posts.toList();
    final next = Map.of(state);
    for (final p in list) {
      next.putIfAbsent(
        p.id,
        () => EngagementView(likeCount: p.likeCount, saveCount: p.saveCount),
      );
    }
    state = next;
    final uid = _uid;
    if (uid == null || list.isEmpty) {
      return;
    }
    try {
      final saved = await _repo.savedAmong(uid, list.map((p) => p.id));
      if (!ref.mounted) {
        return;
      }
      final updated = Map.of(state);
      for (final p in list) {
        final v = updated[p.id];
        if (v != null) {
          updated[p.id] = v.copyWith(saved: saved.contains(p.id));
        }
      }
      state = updated;
    } catch (_) {
      // Bookmarks are a nicety; the feed works without them.
    }
  }

  /// Counts, liked and saved for a single post (the detail screen).
  Future<void> load(PostSummary post) async {
    final next = Map.of(state);
    next.putIfAbsent(
      post.id,
      () =>
          EngagementView(likeCount: post.likeCount, saveCount: post.saveCount),
    );
    state = next;
    final uid = _uid;
    if (uid == null) {
      return;
    }
    try {
      final e = await _repo.engagementFor(uid, post.id);
      if (!ref.mounted) {
        return;
      }
      state = {
        ...state,
        post.id: state[post.id]!.copyWith(liked: e.liked, saved: e.saved),
      };
    } catch (_) {
      // Keep the counts; the buttons start in the "off" state.
    }
  }

  Future<bool> toggleLike(String postId) => _toggle(postId, like: true);
  Future<bool> toggleSave(String postId) => _toggle(postId, like: false);

  Future<bool> _toggle(String postId, {required bool like}) async {
    final uid = _uid;
    final before = state[postId];
    if (uid == null || before == null) {
      return false;
    }
    final key = '${like ? 'like' : 'save'}:$postId';
    if (!_busy.add(key)) {
      return true;
    }
    final want = like ? !before.liked : !before.saved;
    state = {
      ...state,
      postId: like
          ? before.copyWith(
              liked: want,
              likeCount: _plusMinus(before.likeCount, want),
            )
          : before.copyWith(
              saved: want,
              saveCount: _plusMinus(before.saveCount, want),
            ),
    };
    try {
      if (like) {
        await _repo.setLiked(uid, postId, want);
      } else {
        await _repo.setSaved(uid, postId, want);
      }
      return true;
    } catch (_) {
      if (ref.mounted) {
        final now = state[postId] ?? before;
        state = {
          ...state,
          postId: like
              ? now.copyWith(liked: before.liked, likeCount: before.likeCount)
              : now.copyWith(saved: before.saved, saveCount: before.saveCount),
        };
      }
      return false;
    } finally {
      _busy.remove(key);
    }
  }
}

final engagementProvider =
    NotifierProvider<EngagementController, Map<String, EngagementView>>(
      EngagementController.new,
    );

/// Whether the viewer follows a photographer, with optimistic toggling.
class FollowController extends Notifier<Map<String, bool>> {
  final _busy = <String>{};

  @override
  Map<String, bool> build() {
    resetOnUserChange(ref, () {
      _busy.clear();
      state = const {};
    });
    return const {};
  }

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;

  Future<void> load(String photographerId) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    try {
      final following = await ref
          .read(postEngagementRepositoryProvider)
          .isFollowing(uid, photographerId);
      if (ref.mounted) {
        state = {...state, photographerId: following};
      }
    } catch (_) {
      // Shown as "not following" until a tap says otherwise.
    }
  }

  Future<bool> toggle(String photographerId) async {
    final uid = _uid;
    if (uid == null || !_busy.add(photographerId)) {
      return uid != null;
    }
    final before = state[photographerId] ?? false;
    state = {...state, photographerId: !before};
    try {
      await ref
          .read(postEngagementRepositoryProvider)
          .setFollowing(uid, photographerId, !before);
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = {...state, photographerId: before};
      }
      return false;
    } finally {
      _busy.remove(photographerId);
    }
  }
}

final followProvider = NotifierProvider<FollowController, Map<String, bool>>(
  FollowController.new,
);
