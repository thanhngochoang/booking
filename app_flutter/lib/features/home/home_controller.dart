import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/discovery/auth_reset.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/explore/location_controller.dart';

@immutable
class HomeFeedState {
  const HomeFeedState({
    this.category,
    this.items = const [],
    this.cursor,
    this.loadingMore = false,
  });

  /// Specialty code of the chip, or null for "Dành cho bạn".
  final String? category;
  final List<RecommendedPost> items;
  final String? cursor;
  final bool loadingMore;

  HomeFeedState copyWith({
    List<RecommendedPost>? items,
    String? cursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) => HomeFeedState(
    category: category,
    items: items ?? this.items,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

class HomeFeedController extends AsyncNotifier<HomeFeedState> {
  static const pageSize = 20;

  RecommendationRepository get _recommender =>
      ref.read(recommendationRepositoryProvider);

  /// The cell of an already known position or saved area. Home never asks for
  /// location; it only uses what Explore has.
  String? get _geohash6 => ref.read(exploreResolutionProvider).origin?.geohash6;

  /// Bumped by every reload so a slow earlier one never overwrites a newer.
  int _generation = 0;

  @override
  Future<HomeFeedState> build() {
    resetOnUserChange(ref, ref.invalidateSelf);
    _generation++;
    return _loadFirst(null);
  }

  Future<HomeFeedState> _loadFirst(String? category) async {
    final page = await _recommender.recommendPosts(
      PostRecommendationQuery(
        specialtyId: category,
        geohash6: _geohash6,
        limit: pageSize,
      ),
    );
    unawaited(
      ref.read(engagementProvider.notifier).seed(page.items.map((e) => e.post)),
    );
    return HomeFeedState(
      category: category,
      items: page.items,
      cursor: page.nextCursor,
    );
  }

  Future<void> selectCategory(String? category) async {
    final mine = ++_generation;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() => _loadFirst(category));
    if (ref.mounted && mine == _generation) {
      state = next;
    }
  }

  /// Pull to refresh: the old feed stays if the reload fails.
  Future<void> refresh() async {
    final mine = ++_generation;
    final next = await AsyncValue.guard(
      () => _loadFirst(state.value?.category),
    );
    if (ref.mounted && mine == _generation && next.hasValue) {
      state = next;
    }
  }

  /// Shows [postId] first, on "Dành cho bạn". The on-device ranking puts
  /// photographers who are free soon first, so a post that was just published
  /// would otherwise sit below them; the spec wants it on top.
  Future<void> pinToTop(String postId) async {
    final mine = ++_generation;
    final fresh = await AsyncValue.guard(() => _loadFirst(null));
    if (!ref.mounted || mine != _generation) {
      return;
    }
    final data = fresh.value;
    if (data == null) {
      return;
    }
    RecommendedPost? pinned;
    for (final item in data.items) {
      if (item.post.id == postId) {
        pinned = item;
      }
    }
    if (pinned == null) {
      try {
        final post = await ref.read(postRepositoryProvider).byId(postId);
        if (post != null) {
          final authors = await ref
              .read(photographerRepositoryProvider)
              .summaries([post.photographerId]);
          final author = authors[post.photographerId];
          if (author != null) {
            pinned = RecommendedPost(post: post, photographer: author, rank: 0);
          }
        }
      } catch (_) {
        // The feed without the pin is still correct.
      }
    }
    if (!ref.mounted || mine != _generation) {
      return;
    }
    final first = pinned;
    if (first == null) {
      state = fresh;
      return;
    }
    state = AsyncData(
      data.copyWith(
        items: [first, ...data.items.where((e) => e.post.id != postId)],
      ),
    );
    unawaited(ref.read(engagementProvider.notifier).seed([first.post]));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (state.isLoading ||
        current == null ||
        current.cursor == null ||
        current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _recommender.recommendPosts(
        PostRecommendationQuery(
          specialtyId: current.category,
          geohash6: _geohash6,
          limit: pageSize,
          cursor: current.cursor,
        ),
      );
      final latest = state.value;
      // A category change or reload while the page was in flight: drop it.
      if (!ref.mounted ||
          latest == null ||
          latest.category != current.category ||
          latest.cursor != current.cursor) {
        return;
      }
      unawaited(
        ref
            .read(engagementProvider.notifier)
            .seed(page.items.map((e) => e.post)),
      );
      state = AsyncData(
        latest.copyWith(
          items: [
            ...latest.items,
            ...page.items.where(
              (e) => !latest.items.any((o) => o.post.id == e.post.id),
            ),
          ],
          cursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          loadingMore: false,
        ),
      );
    } catch (_) {
      final latest = state.value;
      if (ref.mounted &&
          latest != null &&
          latest.category == current.category) {
        state = AsyncData(latest.copyWith(loadingMore: false));
      }
    }
  }
}

final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedController, HomeFeedState>(
      HomeFeedController.new,
    );

/// "Rảnh tuần này": photographers whose next free day is within a week.
final freeThisWeekProvider =
    FutureProvider.autoDispose<List<PhotographerSummary>>(
      (ref) => ref
          .watch(photographerRepositoryProvider)
          .freeThisWeek(now: ref.watch(clockProvider)()),
    );

@immutable
class FeedPost {
  const FeedPost(this.post, this.photographer);
  final PostSummary post;
  final PhotographerSummary photographer;
}

/// "Buổi chụp thật": the newest photos customers shared after a shoot.
final realShootsProvider = FutureProvider.autoDispose<List<FeedPost>>((
  ref,
) async {
  final page = await ref
      .watch(postRepositoryProvider)
      .feed(kind: PostKind.realShoot, limit: 6);
  final authors = await ref
      .watch(photographerRepositoryProvider)
      .summaries(page.posts.map((p) => p.photographerId));
  return [
    for (final p in page.posts)
      if (authors[p.photographerId] != null)
        FeedPost(p, authors[p.photographerId]!),
  ];
});
