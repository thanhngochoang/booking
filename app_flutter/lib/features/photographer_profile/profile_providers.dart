// lib/features/photographer_profile/profile_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';

/// S03.01 "Gói": active packages, cheapest first. One-shot.
final profilePackagesProvider = FutureProvider.autoDispose
    .family<List<ServiceSummary>, String>((ref, uid) async {
      final list = await ref.watch(serviceRepositoryProvider).activeFor(uid);
      return [
        for (final s in list)
          if (s.active) s,
      ]..sort((a, b) => a.priceVnd.compareTo(b.priceVnd));
    }, retry: (_, _) => null);

/// S03.01 "Thợ ảnh tương tự" (spec 3e.9). Never fails the screen: any error
/// gives an empty list and the section hides.
final similarPhotographersProvider = FutureProvider.autoDispose
    .family<List<PhotographerSummary>, String>((ref, uid) async {
      try {
        final page = await ref
            .watch(recommendationRepositoryProvider)
            .similar(uid, limit: 8);
        return [
          for (final item in page.items)
            if (item.photographer.id != uid) item.photographer,
        ];
      } catch (_) {
        return const [];
      }
    });

@immutable
class PortfolioState {
  const PortfolioState({
    this.posts = const [],
    this.cursor,
    this.loadingMore = false,
  });

  final List<PostSummary> posts;
  final String? cursor;
  final bool loadingMore;

  bool get hasMore => cursor != null;
}

/// The photographer's posts, newest first, 20 at a time ("Xem thêm ảnh").
class PortfolioController extends AsyncNotifier<PortfolioState> {
  PortfolioController(this.photographerId);

  final String photographerId;
  static const pageSize = 20;

  @override
  Future<PortfolioState> build() async {
    final page = await ref
        .watch(postRepositoryProvider)
        .byPhotographer(photographerId, limit: pageSize);
    return PortfolioState(posts: page.posts, cursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }
    state = AsyncData(
      PortfolioState(
        posts: current.posts,
        cursor: current.cursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(postRepositoryProvider)
          .byPhotographer(
            photographerId,
            cursor: current.cursor,
            limit: pageSize,
          );
      if (!ref.mounted) return;
      state = AsyncData(
        PortfolioState(
          posts: [...current.posts, ...page.posts],
          cursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(current); // keep what is shown; the button stays
    }
  }
}

final portfolioProvider = AsyncNotifierProvider.autoDispose
    .family<PortfolioController, PortfolioState, String>(
      PortfolioController.new,
      retry: (_, _) => null,
    );

/// S03.01 "Đánh giá": paginated list of reviews for a photographer.
class PhotographerReviews extends AsyncNotifier<List<Review>> {
  PhotographerReviews(this.photographerId);

  final String photographerId;
  Object? _cursor;
  bool _hasMore = false;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  @override
  Future<List<Review>> build() async {
    _cursor = null;
    _hasMore = false;
    _loadingMore = false;
    final page = await ref
        .watch(reviewRepositoryProvider)
        .forPhotographer(photographerId, limit: 10);
    _cursor = page.cursor;
    _hasMore = page.hasMore;
    return page.items;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    state = AsyncData(List<Review>.of(current));
    try {
      final page = await ref
          .read(reviewRepositoryProvider)
          .forPhotographer(photographerId, after: _cursor, limit: 10);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _loadingMore = false;
      state = AsyncData([...current, ...page.items]);
    } catch (_) {
      _loadingMore = false;
      state = AsyncData(List<Review>.of(current));
    }
  }
}

final photographerReviewsProvider = AsyncNotifierProvider.autoDispose
    .family<PhotographerReviews, List<Review>, String>(
      PhotographerReviews.new,
    );

/// Post summary for review thumbnails.
final reviewPostProvider =
    FutureProvider.autoDispose.family<PostSummary?, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).byId(postId);
});

