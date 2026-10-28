import 'package:photobooking/core/core.dart';

/// Where the OS permission stands, as the UI needs to tell the cases apart.
enum LocationPermissionStatus {
  /// Never asked: show the prompt card (S02.03).
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

/// A one-shot fix with the platform's horizontal accuracy in metres (the
/// radius of 68% confidence). Kept in memory only; Chụp ngay sends it to the
/// server with the presence and the arrival check, which trust [accuracyM].
class LocationFix {
  const LocationFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
  });

  final double lat;
  final double lng;
  final double accuracyM;

  @override
  String toString() => 'LocationFix(<redacted>)';
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

  /// One-shot GPS / device position for chat sharing, or null when permission
  /// denied or unavailable.
  Future<({double lat, double lng})?> currentPosition({
    Duration timeout = const Duration(seconds: 10),
  });

  /// One-shot fix with its real accuracy, or null when permission is not
  /// granted, no fix arrives within [timeout] or the platform fails.
  /// [highAccuracy] asks for GPS grade (S14.03 arrival); the default is the
  /// low-power fix (presence).
  Future<LocationFix?> currentFix({
    bool highAccuracy = false,
    Duration timeout = const Duration(seconds: 10),
  });

  /// Opens the OS settings page of this app.
  Future<void> openSettings();

  /// Opens the system location settings (the device's location switch is
  /// off: [LocationPermissionStatus.serviceOff]).
  Future<void> openLocationSettings();
}

class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository({
    this.status = LocationPermissionStatus.notAsked,
    this.statusAfterRequest = LocationPermissionStatus.granted,
    this.location,
    this.position,
  });

  LocationPermissionStatus status;

  /// What `request()` leaves behind when it is allowed to ask.
  LocationPermissionStatus statusAfterRequest;
  ApproxLocation? location;
  ({double lat, double lng})? position;

  /// The accuracy [currentFix] reports for [position].
  double accuracyM = 35;

  int statusCalls = 0;
  int requestCalls = 0;
  int locationCalls = 0;
  int positionCalls = 0;
  int openSettingsCalls = 0;
  int openLocationSettingsCalls = 0;
  int fixCalls = 0;
  int highAccuracyFixCalls = 0;

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
  Future<({double lat, double lng})?> currentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    positionCalls++;
    if (status != LocationPermissionStatus.granted) {
      return null;
    }
    return position;
  }

  @override
  Future<LocationFix?> currentFix({
    bool highAccuracy = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    fixCalls++;
    if (highAccuracy) highAccuracyFixCalls++;
    final p = position;
    if (status != LocationPermissionStatus.granted || p == null) {
      return null;
    }
    return LocationFix(lat: p.lat, lng: p.lng, accuracyM: accuracyM);
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }

  @override
  Future<void> openLocationSettings() async {
    openLocationSettingsCalls++;
  }
}
