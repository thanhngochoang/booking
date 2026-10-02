import 'package:photobooking/data/recommendation/recommendation_models.dart';

/// Asks [primary] (the remote recommender) with a deadline and falls back to
/// [fallback] (the on-device ranking) when it fails or is too slow, so Home
/// and Find always show something (spec 3e.4).
///
/// There is no retry: one attempt per request, so a dead server costs one
/// deadline of waiting and no background work.
class ResilientRecommendationRepository implements RecommendationRepository {
  ResilientRecommendationRepository({
    required this.primary,
    required this.fallback,
    this.timeout = const Duration(milliseconds: 800),
  });

  final RecommendationRepository primary;
  final RecommendationRepository fallback;
  final Duration timeout;

  @override
  Future<RecommendationPage> recommendPhotographers(
    RecommendationQuery query,
  ) async {
    try {
      return await primary.recommendPhotographers(query).timeout(timeout);
    } catch (_) {
      return (await fallback.recommendPhotographers(query)).markFallback();
    }
  }

  @override
  Future<RecommendationPage> similar(
    String photographerId, {
    int limit = 8,
  }) async {
    try {
      return await primary
          .similar(photographerId, limit: limit)
          .timeout(timeout);
    } catch (_) {
      return (await fallback.similar(
        photographerId,
        limit: limit,
      )).markFallback();
    }
  }

  @override
  Future<PostRecommendationPage> recommendPosts(
    PostRecommendationQuery query,
  ) async {
    try {
      return await primary.recommendPosts(query).timeout(timeout);
    } catch (_) {
      return (await fallback.recommendPosts(query)).markFallback();
    }
  }

  @override
  Future<void> sendFeedback(List<RecommendationSignal> signals) async {
    try {
      await primary.sendFeedback(signals).timeout(timeout);
    } catch (_) {
      // Feedback is best effort; the next screen must not notice.
    }
  }
}
