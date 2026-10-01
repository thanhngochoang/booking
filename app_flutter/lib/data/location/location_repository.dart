import 'package:photobooking/core/core.dart';

/// Where the OS permission stands, as the UI needs to tell the cases apart.
enum LocationPermissionStatus {
  /// Never asked: show the prompt card (S13).
  notAsked,
  granted,

  /// Refused once; can still be asked again by the OS.
  denied,

  /// Refused for good: only the Settings app can change it.
  deniedForever,

  /// The device's location switch is off.
  serviceOff,
}

/// A coarse fix kept in memory only. Never persisted, never sent: only the
/// geohash cells derived from it may leave the device (spec 3c.2).
class ApproxLocation {
  const ApproxLocation({
    required this.lat,
    required this.lng,
    required this.capturedAt,
  });

  final double lat;
  final double lng;
  final DateTime capturedAt;

  static const maxAge = Duration(minutes: 30);

  String get geohash5 => encodeGeohash(lat, lng, precision: 5);
  String get geohash6 => encodeGeohash(lat, lng, precision: 6);

  bool isStale(DateTime now) => now.difference(capturedAt) > maxAge;

  @override
  String toString() => 'ApproxLocation(<redacted>)';
}

abstract class LocationRepository {
  Future<LocationPermissionStatus> permissionStatus();

  /// Shows the OS dialog when the OS allows it and returns the new status.
  ///
  /// Platform errors may be thrown (for example a request already in
  /// progress); callers guard re-entry.
  Future<LocationPermissionStatus> request();

  /// Low-accuracy fix, or null when none arrives within [timeout] or the
  /// platform fails.
  Future<ApproxLocation?> currentApproxLocation({
    Duration timeout = const Duration(seconds: 8),
  });

  /// Opens the OS settings page of this app.
  Future<void> openSettings();
}

class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository({
    this.status = LocationPermissionStatus.notAsked,
    this.statusAfterRequest = LocationPermissionStatus.granted,
    this.location,
  });

  LocationPermissionStatus status;

  /// What `request()` leaves behind when it is allowed to ask.
  LocationPermissionStatus statusAfterRequest;
  ApproxLocation? location;

  int statusCalls = 0;
  int requestCalls = 0;
  int locationCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<LocationPermissionStatus> permissionStatus() async {
    statusCalls++;
    return status;
  }

  @override
  Future<LocationPermissionStatus> request() async {
    requestCalls++;
    if (status == LocationPermissionStatus.notAsked ||
        status == LocationPermissionStatus.denied) {
      status = statusAfterRequest;
    }
    return status;
  }

  @override
  Future<ApproxLocation?> currentApproxLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    locationCalls++;
    return location;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}
