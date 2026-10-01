// lib/features/explore/nearby_events.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';

/// Radius chips of S35.
const kRadiusOptionsKm = [10.0, 25.0, 50.0];

@immutable
class NearbyFilters {
  const NearbyFilters({
    this.radiusKm = 25,
    this.thisWeek = false,
    this.weekend = false,
    this.freeOnly = false,
  });

  final double radiusKm;
  final bool thisWeek;
  final bool weekend;
  final bool freeOnly;

  NearbyFilters copyWith({
    double? radiusKm,
    bool? thisWeek,
    bool? weekend,
    bool? freeOnly,
  }) => NearbyFilters(
    radiusKm: radiusKm ?? this.radiusKm,
    thisWeek: thisWeek ?? this.thisWeek,
    weekend: weekend ?? this.weekend,
    freeOnly: freeOnly ?? this.freeOnly,
  );

  @override
  bool operator ==(Object other) =>
      other is NearbyFilters &&
      other.radiusKm == radiusKm &&
      other.thisWeek == thisWeek &&
      other.weekend == weekend &&
      other.freeOnly == freeOnly;

  @override
  int get hashCode => Object.hash(radiusKm, thisWeek, weekend, freeOnly);
}

@immutable
class NearbyEvent {
  const NearbyEvent({required this.event, required this.distanceKm});
  final EventSummary event;

  /// Rounded to 0.1 km.
  final double distanceKm;
}

List<NearbyEvent> selectNearby(
  List<EventSummary> events, {
  required double lat,
  required double lng,
  required NearbyFilters filters,
  required DateTime now,
}) {
  final weekEnd = endOfVnWeek(now);
  final weekendHorizon = now.add(const Duration(days: 7));
  final matches = <(double, EventSummary)>[];
  for (final e in events) {
    if (e.status != EventStatus.open && e.status != EventStatus.full) {
      continue;
    }
    if (e.startsAt.isBefore(now) || !e.hasGeo) {
      continue;
    }
    final km = haversineKm(lat, lng, e.lat!, e.lng!);
    if (km > filters.radiusKm) {
      continue;
    }
    if (filters.thisWeek && !e.startsAt.isBefore(weekEnd)) {
      continue;
    }
    if (filters.weekend &&
        !(isVnWeekend(e.startsAt) && e.startsAt.isBefore(weekendHorizon))) {
      continue;
    }
    if (filters.freeOnly && !e.isFree) {
      continue;
    }
    matches.add((km, e));
  }
  matches.sort((a, b) {
    final byDistance = a.$1.compareTo(b.$1);
    return byDistance != 0
        ? byDistance
        : a.$2.startsAt.compareTo(b.$2.startsAt);
  });
  return [
    for (final (km, e) in matches)
      NearbyEvent(event: e, distanceKm: roundKm(km)),
  ];
}

class NearbyFiltersController extends Notifier<NearbyFilters> {
  @override
  NearbyFilters build() => const NearbyFilters();

  void setRadius(double km) => state = state.copyWith(radiusKm: km);
  void toggleThisWeek() => state = state.copyWith(thisWeek: !state.thisWeek);
  void toggleWeekend() => state = state.copyWith(weekend: !state.weekend);
  void toggleFree() => state = state.copyWith(freeOnly: !state.freeOnly);

  /// Moves to the next larger radius; false when already at the largest.
  bool widen() {
    for (final km in kRadiusOptionsKm) {
      if (km > state.radiusKm) {
        state = state.copyWith(radiusKm: km);
        return true;
      }
    }
    return false;
  }
}

final nearbyFiltersProvider =
    NotifierProvider<NearbyFiltersController, NearbyFilters>(
      NearbyFiltersController.new,
    );

/// Events around the current origin. Distances are computed here, on the
/// device; the repository only ever sees geohash prefixes.
final nearbyEventsProvider = FutureProvider.autoDispose<List<NearbyEvent>>((
  ref,
) async {
  final origin = ref.watch(exploreResolutionProvider.select((r) => r.origin));
  if (origin == null) {
    return const [];
  }
  final filters = ref.watch(nearbyFiltersProvider);
  final now = ref.watch(clockProvider)();
  final q = geohashQueryFor(filters.radiusKm);
  final cells = geohashCells(origin.cellPrefix(q.precision), rings: q.rings);
  final events = await ref
      .watch(nearbyEventsRepositoryProvider)
      .inCells(cells, from: now);
  return selectNearby(
    events,
    lat: origin.lat,
    lng: origin.lng,
    filters: filters,
    now: now,
  );
});

/// "Sự kiện chụp ảnh" when there is no location: upcoming events anywhere.
final upcomingEventsProvider = FutureProvider.autoDispose<List<EventSummary>>((
  ref,
) {
  final now = ref.watch(clockProvider)();
  return ref.watch(nearbyEventsRepositoryProvider).upcoming(from: now);
});
