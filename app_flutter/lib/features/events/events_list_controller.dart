// lib/features/events/events_list_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/nearby_events.dart';

/// Radius of "Gần tôi": the largest Explore radius.
const _nearRadiusKm = 50.0;

enum EventsSort { soonest, near }

/// What S11.01 shows: the type tag, the free chip and the sort. Lives outside
/// the screen so the choice survives going to an event and back.
@immutable
class EventsFilter {
  const EventsFilter({
    this.type,
    this.freeOnly = false,
    this.sort = EventsSort.soonest,
  });

  final EventType? type;
  final bool freeOnly;
  final EventsSort sort;

  EventsFilter copyWith({
    EventType? type,
    bool clearType = false,
    bool? freeOnly,
    EventsSort? sort,
  }) => EventsFilter(
    type: clearType ? null : (type ?? this.type),
    freeOnly: freeOnly ?? this.freeOnly,
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is EventsFilter &&
      other.type == type &&
      other.freeOnly == freeOnly &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(type, freeOnly, sort);
}

class EventsFilterController extends Notifier<EventsFilter> {
  @override
  EventsFilter build() => const EventsFilter();

  void setType(EventType? type) =>
      state = state.copyWith(type: type, clearType: type == null);
  void toggleFree() => state = state.copyWith(freeOnly: !state.freeOnly);
  void setSort(EventsSort sort) => state = state.copyWith(sort: sort);
}

/// Not auto-dispose: the selected tag survives back navigation.
final eventsFilterProvider =
    NotifierProvider<EventsFilterController, EventsFilter>(
      EventsFilterController.new,
    );

@immutable
class EventsListState {
  const EventsListState({
    this.events = const [],
    this.distances = const {},
    this.nextCursor,
    this.needsArea = false,
    this.loadingMore = false,
  });

  final List<EventSummary> events;

  /// Kilometres by event id, rounded to 0,1; only for "Gần tôi".
  final Map<String, double> distances;
  final String? nextCursor;

  /// "Gần tôi" without a saved area or location.
  final bool needsArea;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  EventsListState copyWith({
    List<EventSummary>? events,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) => EventsListState(
    events: events ?? this.events,
    distances: distances,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    needsArea: needsArea,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The list of S11.01: pages of 20 for "Sớm nhất", everything around the
/// saved area for "Gần tôi" (distances are computed here; the repository only
/// sees geohash cells).
final eventsListProvider =
    AsyncNotifierProvider.autoDispose<EventsListController, EventsListState>(
      EventsListController.new,
    );

class EventsListController extends AsyncNotifier<EventsListState> {
  static const pageSize = 20;

  @override
  Future<EventsListState> build() async {
    final filter = ref.watch(eventsFilterProvider);
    final now = ref.read(clockProvider)();
    if (filter.sort == EventsSort.near) {
      return _near(filter, now);
    }
    final page = await ref
        .watch(eventRepositoryProvider)
        .list(
          type: filter.type,
          freeOnly: filter.freeOnly,
          from: now,
          limit: pageSize,
        );
    return EventsListState(events: page.events, nextCursor: page.nextCursor);
  }

  Future<EventsListState> _near(EventsFilter filter, DateTime now) async {
    final origin = ref.watch(exploreResolutionProvider.select((r) => r.origin));
    if (origin == null) {
      return const EventsListState(needsArea: true);
    }
    final q = geohashQueryFor(_nearRadiusKm);
    final cells = geohashCells(origin.cellPrefix(q.precision), rings: q.rings);
    final events = await ref
        .watch(nearbyEventsRepositoryProvider)
        .inCells(cells, from: now);
    final near = selectNearby(
      events,
      lat: origin.lat,
      lng: origin.lng,
      filters: NearbyFilters(
        radiusKm: _nearRadiusKm,
        freeOnly: filter.freeOnly,
      ),
      now: now,
    ).where((n) => filter.type == null || n.event.type == filter.type);
    return EventsListState(
      events: [for (final n in near) n.event],
      distances: {for (final n in near) n.event.id: n.distanceKm},
    );
  }

  /// Next page of "Sớm nhất"; does nothing while loading or at the end.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    final filter = ref.read(eventsFilterProvider);
    try {
      final page = await ref
          .read(eventRepositoryProvider)
          .list(
            type: filter.type,
            freeOnly: filter.freeOnly,
            from: ref.read(clockProvider)(),
            cursor: current.nextCursor,
            limit: pageSize,
          );
      final seen = {for (final e in current.events) e.id};
      state = AsyncData(
        current.copyWith(
          events: [
            ...current.events,
            ...page.events.where((e) => !seen.contains(e.id)),
          ],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Keep what is shown; the next scroll tries again.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
