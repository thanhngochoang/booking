import 'package:flutter/foundation.dart';

import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/reason.dart';

/// "Phù hợp nhất" is the recommender's own order; the others are applied by
/// the plain query path (spec S02.06).
enum RecommendationSort { best, near, price, rating }

@immutable
class RecommendationQuery {
  const RecommendationQuery({
    this.specialtyId,
    this.styleId,
    this.date,
    this.geohash6,
    this.budgetMax,
    this.sort = RecommendationSort.best,
    this.limit = 20,
    this.cursor,
    this.excludeIds = const [],
  });

  final String? specialtyId;

  /// A style code (`natural_light`, ...); photographers must list it.
  final String? styleId;

  /// A calendar date (Vietnam); only year, month and day are read.
  final DateTime? date;

  /// 6-character geohash of the searcher's area (about 1.2 km). Never
  /// coordinates.
  final String? geohash6;

  /// Integer VND.
  final int? budgetMax;
  final RecommendationSort sort;
  final int limit;
  final String? cursor;
  final List<String> excludeIds;

  RecommendationQuery copyWith({
    String? specialtyId,
    String? styleId,
    DateTime? date,
    String? geohash6,
    int? budgetMax,
    RecommendationSort? sort,
    int? limit,
    String? cursor,
    bool clearCursor = false,
    List<String>? excludeIds,
  }) => RecommendationQuery(
    specialtyId: specialtyId ?? this.specialtyId,
    styleId: styleId ?? this.styleId,
    date: date ?? this.date,
    geohash6: geohash6 ?? this.geohash6,
    budgetMax: budgetMax ?? this.budgetMax,
    sort: sort ?? this.sort,
    limit: limit ?? this.limit,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    excludeIds: excludeIds ?? this.excludeIds,
  );

  @override
  bool operator ==(Object other) =>
      other is RecommendationQuery &&
      other.specialtyId == specialtyId &&
      other.styleId == styleId &&
      other.date == date &&
      other.geohash6 == geohash6 &&
      other.budgetMax == budgetMax &&
      other.sort == sort &&
      other.limit == limit &&
      other.cursor == cursor &&
      listEquals(other.excludeIds, excludeIds);

  @override
  int get hashCode => Object.hash(
    specialtyId,
    styleId,
    date,
    geohash6,
    budgetMax,
    sort,
    limit,
    cursor,
    Object.hashAll(excludeIds),
  );
}

@immutable
class RecommendedPhotographer {
  const RecommendedPhotographer({
    required this.photographer,
    required this.rank,
    required this.score,
    this.reasons = const [],
    this.distanceKm,
  });

  final PhotographerSummary photographer;

  /// 1-based position across pages.
  final int rank;

  /// 0..1; only meaningful for comparing within one response.
  final double score;
  final List<Reason> reasons;

  /// From the searcher's cell centre; null when either side has no position.
  final double? distanceKm;
}

@immutable
class RecommendationPage {
  const RecommendationPage({
    required this.items,
    required this.requestId,
    required this.algorithm,
    required this.algorithmVersion,
    this.nextCursor,
    this.usedFallback = false,
  });

  final List<RecommendedPhotographer> items;
  final String requestId;
  final String algorithm;
  final String algorithmVersion;
  final String? nextCursor;

  /// True when the remote recommender failed or was too slow and this page was
  /// ranked on the device instead.
  final bool usedFallback;

  RecommendationPage markFallback() => RecommendationPage(
    items: items,
    requestId: requestId,
    algorithm: algorithm,
    algorithmVersion: algorithmVersion,
    nextCursor: nextCursor,
    usedFallback: true,
  );
}

@immutable
class PostRecommendationQuery {
  const PostRecommendationQuery({
    this.specialtyId,
    this.geohash6,
    this.limit = 20,
    this.cursor,
  });

  final String? specialtyId;
  final String? geohash6;
  final int limit;
  final String? cursor;
}

@immutable
class RecommendedPost {
  const RecommendedPost({
    required this.post,
    required this.photographer,
    required this.rank,
    this.reasons = const [],
  });

  final PostSummary post;
  final PhotographerSummary photographer;
  final int rank;
  final List<Reason> reasons;
}

@immutable
class PostRecommendationPage {
  const PostRecommendationPage({
    required this.items,
    required this.requestId,
    required this.algorithm,
    required this.algorithmVersion,
    this.nextCursor,
    this.usedFallback = false,
  });

  final List<RecommendedPost> items;
  final String requestId;
  final String algorithm;
  final String algorithmVersion;
  final String? nextCursor;
  final bool usedFallback;

  PostRecommendationPage markFallback() => PostRecommendationPage(
    items: items,
    requestId: requestId,
    algorithm: algorithm,
    algorithmVersion: algorithmVersion,
    nextCursor: nextCursor,
    usedFallback: true,
  );
}

enum SignalType { impression, click, inquiry, booking }

/// One thing the user did with a recommendation. No position, no phone, no
/// message text (spec 3e.7).
@immutable
class RecommendationSignal {
  const RecommendationSignal({
    required this.type,
    required this.requestId,
    required this.photographerId,
    this.rank,
    this.algorithmVersion,
    required this.at,
  });

  final SignalType type;
  final String requestId;
  final String photographerId;
  final int? rank;
  final String? algorithmVersion;
  final DateTime at;
}

/// The only way screens ask for ranked photographers and posts. Implemented
/// on the device by `LocalRecommender` and, in step 3r, by a remote client of
/// the `recommend` callable.
abstract class RecommendationRepository {
  Future<RecommendationPage> recommendPhotographers(RecommendationQuery query);

  /// Photographers similar to [photographerId] (S03.01 "Thợ ảnh tương tự").
  Future<RecommendationPage> similar(String photographerId, {int limit = 8});

  /// Order for the Home feed (S02.01 "Dành cho bạn").
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery query);

  /// Never throws: feedback must not break a screen.
  Future<void> sendFeedback(List<RecommendationSignal> signals);
}
