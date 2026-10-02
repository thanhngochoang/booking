// lib/features/photographer_profile/profile_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';

/// S03 "Gói": active packages, cheapest first. One-shot.
final profilePackagesProvider = FutureProvider.autoDispose
    .family<List<ServiceSummary>, String>((ref, uid) async {
      final list = await ref.watch(serviceRepositoryProvider).activeFor(uid);
      return [
        for (final s in list)
          if (s.active) s,
      ]..sort((a, b) => a.priceVnd.compareTo(b.priceVnd));
    });

/// S03 "Thợ ảnh tương tự" (spec 3e.9). Never fails the screen: any error
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
      state = AsyncData(
        PortfolioState(
          posts: [...current.posts, ...page.posts],
          cursor: page.nextCursor,
        ),
      );
    } catch (_) {
      state = AsyncData(current); // keep what is shown; the button stays
    }
  }
}

final portfolioProvider = AsyncNotifierProvider.autoDispose
    .family<PortfolioController, PortfolioState, String>(
      PortfolioController.new,
    );
