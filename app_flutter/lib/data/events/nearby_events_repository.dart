// lib/data/events/nearby_events_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/events/event_summary.dart';

/// Reads events for Explore. The Firestore adapter (query by geohash prefix on
/// `events (location.geohash, startAt)`) is part of the events plan.
abstract class NearbyEventsRepository {
  /// Public events starting at or after [from] whose geohash starts with one
  /// of [cells] (prefixes of length 2 to 5). Only prefixes are passed in: the
  /// user's coordinates never reach a repository.
  ///
  /// Cells are a coarse cover. An adapter must return every public event in
  /// [cells] from [from] (paging internally if needed) rather than truncating
  /// at [limit]; the caller filters by distance.
  Future<List<EventSummary>> inCells(
    List<String> cells, {
    required DateTime from,
    int limit = 100,
  });

  /// Public upcoming events anywhere, soonest first ("Sự kiện chụp ảnh").
  Future<List<EventSummary>> upcoming({required DateTime from, int limit = 20});

  /// Events created after [since] (all of them when null), optionally inside
  /// [cells], at most [cap]: the number on the Explore tab.
  Future<int> countCreatedSince({
    List<String>? cells,
    DateTime? since,
    int cap = 10,
  });
}

bool _isPublic(EventSummary e) =>
    e.status == EventStatus.open || e.status == EventStatus.full;

class FakeNearbyEventsRepository implements NearbyEventsRepository {
  FakeNearbyEventsRepository([List<EventSummary> events = const []])
    : _events = List.of(events);

  final List<EventSummary> _events;

  /// Every `cells` argument received by [inCells], for privacy assertions.
  final List<List<String>> cellQueries = [];
  int upcomingCalls = 0;

  /// When set, every call throws it.
  Object? failWith;

  void add(EventSummary event) => _events.add(event);

  bool _inCells(EventSummary e, List<String>? cells) {
    if (cells == null) {
      return true;
    }
    final hash = e.geohash;
    return hash != null && cells.any(hash.startsWith);
  }

  @override
  Future<List<EventSummary>> inCells(
    List<String> cells, {
    required DateTime from,
    int limit = 100,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    cellQueries.add(List.unmodifiable(cells));
    final out =
        _events
            .where((e) => _isPublic(e) && !e.startsAt.isBefore(from))
            .where((e) => _inCells(e, cells))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return out.take(limit).toList();
  }

  @override
  Future<List<EventSummary>> upcoming({
    required DateTime from,
    int limit = 20,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    upcomingCalls++;
    final out =
        _events
            .where((e) => _isPublic(e) && !e.startsAt.isBefore(from))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return out.take(limit).toList();
  }

  @override
  Future<int> countCreatedSince({
    List<String>? cells,
    DateTime? since,
    int cap = 10,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    final n = _events
        .where((e) => _isPublic(e) && _inCells(e, cells))
        .where((e) => since == null || e.createdAt.isAfter(since))
        .length;
    return n < cap ? n : cap;
  }
}

/// The production default until the events backend exists: no events.
class EmptyNearbyEventsRepository implements NearbyEventsRepository {
  const EmptyNearbyEventsRepository();

  @override
  Future<List<EventSummary>> inCells(
    List<String> cells, {
    required DateTime from,
    int limit = 100,
  }) async => const [];

  @override
  Future<List<EventSummary>> upcoming({
    required DateTime from,
    int limit = 20,
  }) async => const [];

  @override
  Future<int> countCreatedSince({
    List<String>? cells,
    DateTime? since,
    int cap = 10,
  }) async => 0;
}

final nearbyEventsRepositoryProvider = Provider<NearbyEventsRepository>(
  (ref) => const EmptyNearbyEventsRepository(),
);
