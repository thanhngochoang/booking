// lib/features/spots/spots_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/features/explore/location_controller.dart';

@immutable
class SpotsFilter {
  const SpotsFilter({
    this.area,
    this.inSeason = false,
    this.weekendOnly = false,
  });

  final String? area;
  final bool inSeason;
  final bool weekendOnly;

  SpotsFilter copyWith({
    String? area,
    bool clearArea = false,
    bool? inSeason,
    bool? weekendOnly,
  }) =>
      SpotsFilter(
        area: clearArea ? null : (area ?? this.area),
        inSeason: inSeason ?? this.inSeason,
        weekendOnly: weekendOnly ?? this.weekendOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is SpotsFilter &&
      other.area == area &&
      other.inSeason == inSeason &&
      other.weekendOnly == weekendOnly;

  @override
  int get hashCode => Object.hash(area, inSeason, weekendOnly);
}

class SpotsFilterController extends Notifier<SpotsFilter> {
  @override
  SpotsFilter build() => const SpotsFilter();

  void initArea(String? area) {
    if (area != null && state.area == null) {
      state = state.copyWith(area: area);
    }
  }

  void setArea(String? area) =>
      state = state.copyWith(area: area, clearArea: area == null);
  void toggleInSeason() => state = state.copyWith(inSeason: !state.inSeason);
  void toggleWeekendOnly() =>
      state = state.copyWith(weekendOnly: !state.weekendOnly);
}

final spotsFilterProvider =
    NotifierProvider<SpotsFilterController, SpotsFilter>(
  SpotsFilterController.new,
);

class SpotsPageLimitNotifier extends Notifier<int> {
  @override
  int build() => 20;

  void loadMore() {
    state += 20;
  }

  void reset() {
    state = 20;
  }
}

final spotsPageLimitProvider =
    NotifierProvider<SpotsPageLimitNotifier, int>(
  SpotsPageLimitNotifier.new,
);

/// Computes filtered and ordered spots list based on spotDirectoryProvider and current filters.
final filteredSpotsProvider = Provider<AsyncValue<List<SpotEntry>>>((ref) {
  final directoryAsync = ref.watch(spotDirectoryProvider);
  final filter = ref.watch(spotsFilterProvider);
  final loc = ref.watch(locationControllerProvider);
  final now = ref.watch(clockProvider)();
  final month = now.month;

  return directoryAsync.whenData((all) {
    var spots = all;
    if (filter.area != null && filter.area!.isNotEmpty) {
      spots = spots.where((s) => s.areaCode == filter.area).toList();
    }
    if (filter.inSeason) {
      spots = spots.where((s) => s.inSeason).toList();
    }
    if (filter.weekendOnly) {
      spots = spots.where((s) => s.providersWeekend > 0).toList();
    }

    return orderSpots(
      spots,
      month: month,
      lat: loc.location?.lat,
      lng: loc.location?.lng,
    );
  });
});
