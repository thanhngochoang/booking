import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/geolocator_location_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gateway implements LocationGateway {
  bool service = true;
  RawPermission raw = RawPermission.denied;
  RawPermission afterRequest = RawPermission.granted;
  Object? positionError;
  bool hang = false;
  int settingsCalls = 0;

  @override
  Future<bool> serviceEnabled() async => service;
  @override
  Future<RawPermission> checkPermission() async => raw;
  @override
  Future<RawPermission> requestPermission() async => raw = afterRequest;
  @override
  Future<({double lat, double lng})> lowAccuracyPosition(
    Duration timeout,
  ) async {
    if (hang) {
      await Completer<void>().future;
    }
    if (positionError != null) {
      throw positionError!;
    }
    return (lat: 10.7769, lng: 106.7009);
  }

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return true;
  }
}

Future<(GeolocatorLocationRepository, _Gateway, SharedPreferences)>
_make() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final gateway = _Gateway();
  final repo = GeolocatorLocationRepository(
    gateway: gateway,
    prefs: prefs,
    now: () => DateTime.utc(2026, 10, 1, 5),
  );
  return (repo, gateway, prefs);
}

void main() {
  group('ApproxLocation', () {
    final loc = ApproxLocation(
      lat: 10.7769,
      lng: 106.7009,
      capturedAt: DateTime.utc(2026, 10, 1, 5),
    );
    test('derives geohash5 and geohash6 prefixes', () {
      expect(loc.geohash6, startsWith(loc.geohash5));
      expect(loc.geohash5, hasLength(5));
      expect(loc.geohash6, hasLength(6));
    });
    test('is stale after 30 minutes', () {
      expect(loc.isStale(DateTime.utc(2026, 10, 1, 5, 29)), isFalse);
      expect(loc.isStale(DateTime.utc(2026, 10, 1, 5, 31)), isTrue);
    });
    test('toString never prints coordinates', () {
      expect(loc.toString(), isNot(contains('10.77')));
      expect(loc.toString(), isNot(contains('106.70')));
    });
  });

  group('FakeLocationRepository', () {
    test('request only moves notAsked or denied', () async {
      final fake = FakeLocationRepository();
      expect(await fake.request(), LocationPermissionStatus.granted);
      final forever = FakeLocationRepository(
        status: LocationPermissionStatus.deniedForever,
      );
      expect(await forever.request(), LocationPermissionStatus.deniedForever);
      final off = FakeLocationRepository(
        status: LocationPermissionStatus.serviceOff,
      );
      expect(await off.request(), LocationPermissionStatus.serviceOff);
      expect(fake.requestCalls, 1);
    });
  });

  group('GeolocatorLocationRepository.permissionStatus', () {
    test('service off wins over everything', () async {
      final (repo, gateway, _) = await _make();
      gateway.service = false;
      gateway.raw = RawPermission.granted;
      expect(
        await repo.permissionStatus(),
        LocationPermissionStatus.serviceOff,
      );
    });

    test(
      'denied before any request is "not asked", after one it is "denied"',
      () async {
        final (repo, gateway, _) = await _make();
        expect(
          await repo.permissionStatus(),
          LocationPermissionStatus.notAsked,
        );
        gateway.afterRequest = RawPermission.denied;
        expect(await repo.request(), LocationPermissionStatus.denied);
        expect(await repo.permissionStatus(), LocationPermissionStatus.denied);
      },
    );

    test('granted and denied-forever map straight through', () async {
      final (repo, gateway, _) = await _make();
      gateway.raw = RawPermission.granted;
      expect(await repo.permissionStatus(), LocationPermissionStatus.granted);
      gateway.raw = RawPermission.deniedForever;
      expect(
        await repo.permissionStatus(),
        LocationPermissionStatus.deniedForever,
      );
    });
  });

  group('GeolocatorLocationRepository.request', () {
    test('records that we asked, and returns the new status', () async {
      final (repo, gateway, prefs) = await _make();
      gateway.afterRequest = RawPermission.granted;
      expect(await repo.request(), LocationPermissionStatus.granted);
      expect(prefs.getBool(GeolocatorLocationRepository.askedKey), isTrue);
    });

    test('does not show a dialog when the service is off', () async {
      final (repo, gateway, prefs) = await _make();
      gateway.service = false;
      expect(await repo.request(), LocationPermissionStatus.serviceOff);
      expect(prefs.getBool(GeolocatorLocationRepository.askedKey), isNull);
    });

    test('a refusal that cannot be asked again is denied-forever', () async {
      final (repo, gateway, _) = await _make();
      gateway.afterRequest = RawPermission.deniedForever;
      expect(await repo.request(), LocationPermissionStatus.deniedForever);
    });
  });

  group('GeolocatorLocationRepository.currentApproxLocation', () {
    test('returns the fix stamped with the injected clock', () async {
      final (repo, _, _) = await _make();
      final loc = await repo.currentApproxLocation();
      expect(loc!.capturedAt, DateTime.utc(2026, 10, 1, 5));
      expect(loc.geohash5, hasLength(5));
    });

    test('gives null when the platform throws', () async {
      final (repo, gateway, _) = await _make();
      gateway.positionError = StateError('no fix');
      expect(await repo.currentApproxLocation(), isNull);
    });

    test('gives null when no fix arrives within the timeout', () async {
      final (repo, gateway, _) = await _make();
      gateway.hang = true;
      final loc = await repo.currentApproxLocation(
        timeout: const Duration(milliseconds: 20),
      );
      expect(loc, isNull);
    });

    test('openSettings goes to the OS app settings', () async {
      final (repo, gateway, _) = await _make();
      await repo.openSettings();
      expect(gateway.settingsCalls, 1);
    });
  });

  test('the repository stores no coordinates', () async {
    final (repo, _, prefs) = await _make();
    await repo.request();
    await repo.currentApproxLocation();
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key).toString();
      expect(value, isNot(contains('10.77')), reason: key);
      expect(value, isNot(contains('106.70')), reason: key);
    }
    expect(prefs.getKeys(), {GeolocatorLocationRepository.askedKey});
  });
}
