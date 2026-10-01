import 'package:geolocator/geolocator.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RawPermission { denied, deniedForever, granted }

/// The few platform calls the repository needs, so the permission logic can
/// be tested without a device.
abstract class LocationGateway {
  Future<bool> serviceEnabled();
  Future<RawPermission> checkPermission();
  Future<RawPermission> requestPermission();

  /// Throws on failure or timeout.
  Future<({double lat, double lng})> lowAccuracyPosition(Duration timeout);
  Future<bool> openAppSettings();
}

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  RawPermission _map(LocationPermission p) => switch (p) {
    LocationPermission.always ||
    LocationPermission.whileInUse => RawPermission.granted,
    LocationPermission.deniedForever => RawPermission.deniedForever,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => RawPermission.denied,
  };

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<RawPermission> checkPermission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<RawPermission> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<({double lat, double lng})> lowAccuracyPosition(
    Duration timeout,
  ) async {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: timeout,
      ),
    );
    return (lat: p.latitude, lng: p.longitude);
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

class GeolocatorLocationRepository implements LocationRepository {
  GeolocatorLocationRepository({
    required this._gateway,
    required this._prefs,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  /// Set the first time we show the OS dialog. The platform reports "denied"
  /// both before the first request and after one refusal; this flag tells
  /// the two apart.
  static const askedKey = 'locationAsked';

  final LocationGateway _gateway;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  @override
  Future<LocationPermissionStatus> permissionStatus() async {
    if (!await _gateway.serviceEnabled()) {
      return LocationPermissionStatus.serviceOff;
    }
    return switch (await _gateway.checkPermission()) {
      RawPermission.granted => LocationPermissionStatus.granted,
      RawPermission.deniedForever => LocationPermissionStatus.deniedForever,
      RawPermission.denied =>
        _prefs.getBool(askedKey) == true
            ? LocationPermissionStatus.denied
            : LocationPermissionStatus.notAsked,
    };
  }

  @override
  Future<LocationPermissionStatus> request() async {
    if (!await _gateway.serviceEnabled()) {
      return LocationPermissionStatus.serviceOff;
    }
    final result = await _gateway.requestPermission();
    await _prefs.setBool(askedKey, true);
    return switch (result) {
      RawPermission.granted => LocationPermissionStatus.granted,
      RawPermission.deniedForever => LocationPermissionStatus.deniedForever,
      RawPermission.denied => LocationPermissionStatus.denied,
    };
  }

  @override
  Future<ApproxLocation?> currentApproxLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final p = await _gateway.lowAccuracyPosition(timeout).timeout(timeout);
      return ApproxLocation(lat: p.lat, lng: p.lng, capturedAt: _now());
    } on Exception catch (_) {
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    await _gateway.openAppSettings();
  }
}
