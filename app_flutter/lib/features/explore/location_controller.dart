import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/geolocator_location_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => GeolocatorLocationRepository(
    gateway: const GeolocatorGateway(),
    prefs: ref.watch(sharedPreferencesProvider),
    now: ref.watch(clockProvider),
  ),
);

final areaRepositoryProvider = Provider<AreaRepository>(
  (ref) => const BuiltInAreaRepository(),
);

/// The pickable areas; never fails, so S36 always has something to show.
final areasProvider = FutureProvider<List<AreaOption>>((ref) async {
  try {
    final list = await ref.watch(areaRepositoryProvider).list();
    return list.isEmpty ? builtInAreas : list;
  } catch (_) {
    return builtInAreas;
  }
});

@immutable
class LocationState {
  const LocationState({
    this.loaded = false,
    this.permission = LocationPermissionStatus.notAsked,
    this.requesting = false,
    this.locating = false,
    this.location,
    this.area,
    this.deferredUntil,
  });

  /// True once the permission status has been read at least once.
  final bool loaded;
  final LocationPermissionStatus permission;

  /// The OS dialog is open.
  final bool requesting;

  /// A fix is being fetched.
  final bool locating;
  final ApproxLocation? location;
  final SavedArea? area;
  final DateTime? deferredUntil;

  LocationState copyWith({
    bool? loaded,
    LocationPermissionStatus? permission,
    bool? requesting,
    bool? locating,
    ApproxLocation? location,
    bool clearLocation = false,
    SavedArea? area,
    bool clearArea = false,
    DateTime? deferredUntil,
  }) => LocationState(
    loaded: loaded ?? this.loaded,
    permission: permission ?? this.permission,
    requesting: requesting ?? this.requesting,
    locating: locating ?? this.locating,
    location: clearLocation ? null : (location ?? this.location),
    area: clearArea ? null : (area ?? this.area),
    deferredUntil: deferredUntil ?? this.deferredUntil,
  );
}

enum ExploreMode { loading, ask, requesting, locating, chooseArea, nearby }

/// Where "near me" is measured from. In memory only; see the privacy rules.
@immutable
class ExploreOrigin {
  const ExploreOrigin({
    required this.lat,
    required this.lng,
    required this.fromDevice,
    this.areaName,
  });

  final double lat;
  final double lng;
  final bool fromDevice;
  final String? areaName;

  String get geohash5 => cellPrefix(5);
  String get geohash6 => cellPrefix(6);
  String cellPrefix(int precision) =>
      encodeGeohash(lat, lng, precision: precision);

  @override
  bool operator ==(Object other) =>
      other is ExploreOrigin &&
      other.lat == lat &&
      other.lng == lng &&
      other.fromDevice == fromDevice &&
      other.areaName == areaName;

  @override
  int get hashCode => Object.hash(lat, lng, fromDevice, areaName);

  @override
  String toString() => 'ExploreOrigin(<redacted>)';
}

@immutable
class ExploreResolution {
  const ExploreResolution(this.mode, [this.origin]);
  final ExploreMode mode;
  final ExploreOrigin? origin;
}

ExploreResolution resolveExplore(LocationState s, DateTime now) {
  final area = s.area;
  if (area != null) {
    final c = area.center;
    return ExploreResolution(
      ExploreMode.nearby,
      ExploreOrigin(
        lat: c.lat,
        lng: c.lng,
        fromDevice: false,
        areaName: area.name,
      ),
    );
  }
  if (!s.loaded) {
    return const ExploreResolution(ExploreMode.loading);
  }
  if (s.requesting) {
    return const ExploreResolution(ExploreMode.requesting);
  }
  switch (s.permission) {
    case LocationPermissionStatus.granted:
      final fix = s.location;
      if (fix != null) {
        return ExploreResolution(
          ExploreMode.nearby,
          ExploreOrigin(lat: fix.lat, lng: fix.lng, fromDevice: true),
        );
      }
      return ExploreResolution(
        s.locating ? ExploreMode.locating : ExploreMode.chooseArea,
      );
    case LocationPermissionStatus.notAsked:
      final until = s.deferredUntil;
      return ExploreResolution(
        until != null && now.isBefore(until)
            ? ExploreMode.chooseArea
            : ExploreMode.ask,
      );
    case LocationPermissionStatus.denied:
    case LocationPermissionStatus.deniedForever:
    case LocationPermissionStatus.serviceOff:
      return const ExploreResolution(ExploreMode.chooseArea);
  }
}

class LocationController extends Notifier<LocationState> {
  static const areaKey = 'area';
  static const deferredKey = 'locationDeferredUntil';
  static const deferDays = 7;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  LocationRepository get _repo => ref.read(locationRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  LocationState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    Future.microtask(refresh);
    return LocationState(
      area: _readArea(prefs),
      deferredUntil: _readDeferred(prefs),
    );
  }

  static SavedArea? _readArea(SharedPreferences prefs) {
    final raw = prefs.getString(areaKey);
    if (raw == null) {
      return null;
    }
    try {
      return SavedArea.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _readDeferred(SharedPreferences prefs) {
    final raw = prefs.getString(deferredKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  /// Re-reads the permission (also on returning from the Settings app) and
  /// fetches a fix when allowed.
  Future<void> refresh() async {
    LocationPermissionStatus status;
    try {
      status = await _repo.permissionStatus();
    } catch (_) {
      // Keep the previous permission; never stay on "loading".
      status = state.permission;
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loaded: true,
      permission: status,
      clearLocation: status != LocationPermissionStatus.granted,
    );
    if (status == LocationPermissionStatus.granted) {
      await _locate();
    }
  }

  Future<void>? _locating;

  /// One fetch at a time: overlapping calls await the one in flight.
  Future<void> _locate({bool force = false}) {
    final running = _locating;
    if (running != null) {
      return running;
    }
    final current = state.location;
    if (!force && current != null && !current.isStale(_now())) {
      return Future.value();
    }
    final f = _fetchFix(current);
    _locating = f;
    return f.whenComplete(() => _locating = null);
  }

  Future<void> _fetchFix(ApproxLocation? current) async {
    state = state.copyWith(locating: true);
    ApproxLocation? fresh;
    try {
      fresh = await _repo.currentApproxLocation();
    } catch (_) {
      fresh = null;
    }
    if (!ref.mounted) {
      return;
    }
    if (state.permission != LocationPermissionStatus.granted) {
      // Revoked while the fix was in flight: drop it.
      state = state.copyWith(locating: false, clearLocation: true);
      return;
    }
    // Keep the previous fix when the new attempt fails (spec: use the old one).
    state = state.copyWith(locating: false, location: fresh ?? current);
  }

  /// The user tapped "Cho phép": the only place the OS dialog is opened.
  Future<void> allow() async {
    if (state.requesting) {
      return; // re-entry guard: the OS dialog is already open
    }
    state = state.copyWith(requesting: true);
    LocationPermissionStatus status;
    try {
      status = await _repo.request();
    } catch (_) {
      // Platform errors (e.g. a request already running): fall back to the
      // status the OS reports, never leave the UI stuck on "requesting".
      if (!ref.mounted) {
        return;
      }
      try {
        status = await _repo.permissionStatus();
      } catch (_) {
        status = state.permission;
      }
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loaded: true,
      requesting: false,
      permission: status,
      clearLocation: status != LocationPermissionStatus.granted,
    );
    if (status == LocationPermissionStatus.granted) {
      await _locate(force: true);
    }
  }

  /// "Để sau": do not show the card again for [deferDays] days.
  Future<void> later() async {
    final until = _now().add(const Duration(days: deferDays));
    await _prefs.setString(deferredKey, until.toIso8601String());
    state = state.copyWith(deferredUntil: until);
  }

  Future<void> chooseArea(AreaOption option) async {
    final saved = option.toSaved();
    await _prefs.setString(areaKey, jsonEncode(saved.toJson()));
    state = state.copyWith(area: saved);
  }

  /// Back to "near me". Asks for permission first if it was never asked. The
  /// chosen area is dropped only once a device fix is actually in hand; in
  /// every other case (refused, off, no fix in time) it stays.
  Future<void> useDeviceLocation() async {
    if (!state.loaded) {
      await refresh();
      if (!ref.mounted) {
        return;
      }
    }
    if (state.permission == LocationPermissionStatus.notAsked ||
        state.permission == LocationPermissionStatus.denied) {
      await allow();
      if (!ref.mounted) {
        return;
      }
    }
    if (state.permission != LocationPermissionStatus.granted) {
      return;
    }
    await _locate();
    if (!ref.mounted ||
        state.permission != LocationPermissionStatus.granted ||
        state.location == null) {
      return;
    }
    await _prefs.remove(areaKey);
    state = state.copyWith(clearArea: true);
  }

  /// Pull to refresh.
  Future<void> refreshLocation() =>
      refresh(); // refetches when the fix is stale

  Future<void> openSettings() => _repo.openSettings();
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

final exploreResolutionProvider = Provider<ExploreResolution>(
  (ref) => resolveExplore(
    ref.watch(locationControllerProvider),
    ref.watch(clockProvider)(),
  ),
);
