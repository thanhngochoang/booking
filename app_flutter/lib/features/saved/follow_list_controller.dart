import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/saved_follow.dart';
import 'package:photobooking/data/content/saved_follow_providers.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/saved/saved_controller.dart';

class FollowingController
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
        .following(uid, limit: pageSize);
    final followNotifier = ref.read(followProvider.notifier);
    for (final item in page.items) {
      followNotifier.set(item.id, true);
    }
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
          .following(uid, cursor: current.cursor, limit: pageSize);
      final followNotifier = ref.read(followProvider.notifier);
      for (final item in page.items) {
        followNotifier.set(item.id, true);
      }
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

final followingControllerProvider = AsyncNotifierProvider<
    FollowingController, SavedListState<PhotographerSummary>>(
  FollowingController.new,
);

class FollowersController extends AsyncNotifier<SavedListState<Follower>> {
  static const pageSize = 30;

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;

  @override
  Future<SavedListState<Follower>> build() async {
    final uid = _uid;
    if (uid == null) {
      return const SavedListState<Follower>();
    }
    final page = await ref
        .read(savedFollowRepositoryProvider)
        .followers(uid, limit: pageSize);
    return SavedListState<Follower>(
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
          .followers(uid, cursor: current.cursor, limit: pageSize);
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

final followersControllerProvider =
    AsyncNotifierProvider<FollowersController, SavedListState<Follower>>(
  FollowersController.new,
);
