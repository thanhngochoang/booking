import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/saved_follow_providers.dart';

@immutable
class SavedListState<T> {
  const SavedListState({
    this.items = const [],
    this.cursor,
    this.loadingMore = false,
    this.moreFailed = false,
  });

  final List<T> items;
  final String? cursor;
  final bool loadingMore;
  final bool moreFailed;

  SavedListState<T> copyWith({
    List<T>? items,
    String? Function()? cursor,
    bool? loadingMore,
    bool? moreFailed,
  }) =>
      SavedListState<T>(
        items: items ?? this.items,
        cursor: cursor != null ? cursor() : this.cursor,
        loadingMore: loadingMore ?? this.loadingMore,
        moreFailed: moreFailed ?? this.moreFailed,
      );
}

class SavedPostsController extends AsyncNotifier<SavedListState<PostSummary>> {
  static const pageSize = 20;

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;

  @override
  Future<SavedListState<PostSummary>> build() async {
    final uid = _uid;
    if (uid == null) {
      return const SavedListState<PostSummary>();
    }
    final page = await ref
        .read(savedFollowRepositoryProvider)
        .savedPosts(uid, limit: pageSize);
    return SavedListState<PostSummary>(
      items: page.items,
      cursor: page.cursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    final uid = _uid;
    if (current == null ||
        uid == null ||
        current.loadingMore ||
        current.cursor == null) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await ref
          .read(savedFollowRepositoryProvider)
          .savedPosts(uid, cursor: current.cursor, limit: pageSize);
      final updated = current.copyWith(
        items: [...current.items, ...page.items],
        cursor: () => page.cursor,
        loadingMore: false,
        moreFailed: false,
      );
      state = AsyncData(updated);
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(loadingMore: false, moreFailed: true));
      }
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final savedPostsControllerProvider =
    AsyncNotifierProvider<SavedPostsController, SavedListState<PostSummary>>(
  SavedPostsController.new,
);

class SavedPhotographersController
    extends AsyncNotifier<SavedListState<PhotographerSummary>> {
  static const pageSize = 20;

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;

  @override
  Future<SavedListState<PhotographerSummary>> build() async {
    final uid = _uid;
    if (uid == null) {
      return const SavedListState<PhotographerSummary>();
    }
    final page = await ref
        .read(savedFollowRepositoryProvider)
        .savedPhotographers(uid, limit: pageSize);
    return SavedListState<PhotographerSummary>(
      items: page.items,
      cursor: page.cursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    final uid = _uid;
    if (current == null ||
        uid == null ||
        current.loadingMore ||
        current.cursor == null) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await ref
          .read(savedFollowRepositoryProvider)
          .savedPhotographers(uid, cursor: current.cursor, limit: pageSize);
      final updated = current.copyWith(
        items: [...current.items, ...page.items],
        cursor: () => page.cursor,
        loadingMore: false,
        moreFailed: false,
      );
      state = AsyncData(updated);
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(loadingMore: false, moreFailed: true));
      }
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  void removeLocally(String photographerId) {
    final current = state.value;
    if (current == null) return;
    final updated = current.items.where((p) => p.id != photographerId).toList();
    state = AsyncData(current.copyWith(items: updated));
  }

  void restore(PhotographerSummary photographer, int index) {
    final current = state.value;
    if (current == null) return;
    final updated = List<PhotographerSummary>.from(current.items);
    if (index >= 0 && index <= updated.length) {
      updated.insert(index, photographer);
    } else {
      updated.add(photographer);
    }
    state = AsyncData(current.copyWith(items: updated));
  }
}

final savedPhotographersControllerProvider = AsyncNotifierProvider<
    SavedPhotographersController, SavedListState<PhotographerSummary>>(
  SavedPhotographersController.new,
);
