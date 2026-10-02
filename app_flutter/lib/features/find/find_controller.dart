import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/explore/location_controller.dart';

@immutable
class FindFilters {
  const FindFilters({
    this.specialtyId,
    this.styleId,
    this.date,
    this.budgetMax,
    this.minRating,
    this.sort = RecommendationSort.best,
  });

  final String? specialtyId;
  final String? styleId;

  /// A calendar date (Vietnam) at local midnight; only year, month and day
  /// matter.
  final DateTime? date;
  final int? budgetMax;
  final double? minRating;
  final RecommendationSort sort;

  bool get hasAny =>
      specialtyId != null ||
      styleId != null ||
      date != null ||
      budgetMax != null ||
      minRating != null;

  @override
  bool operator ==(Object other) =>
      other is FindFilters &&
      other.specialtyId == specialtyId &&
      other.styleId == styleId &&
      other.date == date &&
      other.budgetMax == budgetMax &&
      other.minRating == minRating &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(specialtyId, styleId, date, budgetMax, minRating, sort);
}

class FindFiltersController extends Notifier<FindFilters> {
  static const _keep = Object();

  @override
  FindFilters build() => const FindFilters();

  FindFilters _with({
    Object? specialtyId = _keep,
    Object? styleId = _keep,
    Object? date = _keep,
    Object? budgetMax = _keep,
    Object? minRating = _keep,
    RecommendationSort? sort,
  }) => FindFilters(
    specialtyId: identical(specialtyId, _keep)
        ? state.specialtyId
        : specialtyId as String?,
    styleId: identical(styleId, _keep) ? state.styleId : styleId as String?,
    date: identical(date, _keep) ? state.date : date as DateTime?,
    budgetMax: identical(budgetMax, _keep)
        ? state.budgetMax
        : budgetMax as int?,
    minRating: identical(minRating, _keep)
        ? state.minRating
        : minRating as double?,
    sort: sort ?? state.sort,
  );

  void setSpecialty(String? v) => state = _with(specialtyId: v);
  void setStyle(String? v) => state = _with(styleId: v);

  /// Always stored as a local `DateTime(y, m, d)`, so the same day from a
  /// UTC or a local source is one value.
  void setDate(DateTime? v) =>
      state = _with(date: v == null ? null : DateTime(v.year, v.month, v.day));
  void setBudget(int? v) => state = _with(budgetMax: v);
  void setMinRating(double? v) => state = _with(minRating: v);
  void setSort(RecommendationSort v) => state = _with(sort: v);

  /// Removes every filter and keeps the chosen sort.
  void clear() => state = FindFilters(sort: state.sort);
}

/// Kept while the app runs, so the choices survive switching tabs.
final findFiltersProvider =
    NotifierProvider<FindFiltersController, FindFilters>(
      FindFiltersController.new,
    );

@immutable
class FindResults {
  const FindResults({
    this.items = const [],
    this.cursor,
    this.usedFallback = false,
    this.loadingMore = false,
    this.requestId = '',
    this.algorithmVersion = '',
  });

  final List<RecommendedPhotographer> items;
  final String? cursor;
  final bool usedFallback;
  final bool loadingMore;
  final String requestId;
  final String algorithmVersion;

  FindResults copyWith({bool? loadingMore}) => FindResults(
    items: items,
    cursor: cursor,
    usedFallback: usedFallback,
    loadingMore: loadingMore ?? this.loadingMore,
    requestId: requestId,
    algorithmVersion: algorithmVersion,
  );
}

class FindResultsController extends AsyncNotifier<FindResults> {
  static const pageSize = 20;

  /// A rating filter that empties a whole page looks at the next pages, up to
  /// this many in a row.
  static const maxEmptyPages = 4;

  /// Bumped by every rebuild (filters or area changed) so a page that was in
  /// flight for the old query is dropped.
  int _generation = 0;

  @override
  Future<FindResults> build() async {
    final filters = ref.watch(findFiltersProvider);
    final geohash6 = ref.watch(
      exploreResolutionProvider.select((r) => r.origin?.geohash6),
    );
    _generation++;
    return _fetch(
      filters,
      geohash6,
      cursor: null,
      previous: const FindResults(),
    );
  }

  Future<FindResults> _fetch(
    FindFilters f,
    String? geohash6, {
    required String? cursor,
    required FindResults previous,
  }) async {
    final recommender = ref.read(recommendationRepositoryProvider);
    final collected = <RecommendedPhotographer>[];
    var page = await recommender.recommendPhotographers(
      _query(f, geohash6, cursor),
    );
    var usedFallback = previous.usedFallback || page.usedFallback;
    collected.addAll(_byRating(page.items, f));
    for (
      var i = 1;
      i < maxEmptyPages && collected.isEmpty && page.nextCursor != null;
      i++
    ) {
      page = await recommender.recommendPhotographers(
        _query(f, geohash6, page.nextCursor),
      );
      usedFallback = usedFallback || page.usedFallback;
      collected.addAll(_byRating(page.items, f));
    }
    return FindResults(
      items: [...previous.items, ...collected],
      cursor: page.nextCursor,
      usedFallback: usedFallback,
      requestId: page.requestId,
      algorithmVersion: page.algorithmVersion,
    );
  }

  RecommendationQuery _query(FindFilters f, String? geohash6, String? cursor) =>
      RecommendationQuery(
        specialtyId: f.specialtyId,
        styleId: f.styleId,
        date: f.date,
        geohash6: geohash6,
        budgetMax: f.budgetMax,
        sort: f.sort,
        limit: pageSize,
        cursor: cursor,
      );

  List<RecommendedPhotographer> _byRating(
    List<RecommendedPhotographer> items,
    FindFilters f,
  ) => f.minRating == null
      ? items
      : items.where((i) => i.photographer.ratingAvg >= f.minRating!).toList();

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.cursor == null || current.loadingMore) {
      return;
    }
    final mine = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(
        ref.read(findFiltersProvider),
        ref.read(exploreResolutionProvider).origin?.geohash6,
        cursor: current.cursor,
        previous: current,
      );
      // The filters or the area changed while the page was in flight: drop it.
      if (ref.mounted && mine == _generation) {
        state = AsyncData(next);
      }
    } catch (_) {
      if (ref.mounted && mine == _generation) {
        state = AsyncData(current.copyWith(loadingMore: false));
      }
    }
  }

  /// "Click": the user opened this photographer from the list. Best effort.
  void sendClick(RecommendedPhotographer item) {
    final current = state.value;
    if (current == null) {
      return;
    }
    unawaited(
      ref.read(recommendationRepositoryProvider).sendFeedback([
        RecommendationSignal(
          type: SignalType.click,
          requestId: current.requestId,
          photographerId: item.photographer.id,
          rank: item.rank,
          algorithmVersion: current.algorithmVersion,
          at: ref.read(clockProvider)(),
        ),
      ]),
    );
  }
}

final findResultsProvider =
    AsyncNotifierProvider<FindResultsController, FindResults>(
      FindResultsController.new,
    );
