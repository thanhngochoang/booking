import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 10, 1, 5);
ApproxLocation _fix([DateTime? at]) =>
    ApproxLocation(lat: 10.7769, lng: 106.7009, capturedAt: at ?? _t0);

class _Clock {
  DateTime now = _t0;
}

class _Env {
  _Env(this.container, this.repo, this.prefs, this.clock);
  final ProviderContainer container;
  final LocationRepository repo;
  final SharedPreferences prefs;
  final _Clock clock;
  LocationController get ctrl =>
      container.read(locationControllerProvider.notifier);
  LocationState get state => container.read(locationControllerProvider);
  ExploreResolution get resolution => container.read(exploreResolutionProvider);
}

Future<_Env> _env({
  LocationRepository? repo,
  Map<String, Object> prefsValues = const {},
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final fake = repo ?? FakeLocationRepository();
  final clock = _Clock();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      locationRepositoryProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => clock.now),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  container.read(locationControllerProvider); // builds and starts refresh()
  await pumpEventQueue();
  return _Env(container, fake, prefs, clock);
}

/// A repository whose calls complete only when the test says so.
class _Gated extends FakeLocationRepository {
  _Gated({super.location});
  final requestGate = Completer<void>();
  final locationGate = Completer<void>();
  @override
  Future<LocationPermissionStatus> request() async {
    await requestGate.future;
    return super.request();
  }

  @override
  Future<ApproxLocation?> currentApproxLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await locationGate.future;
    return super.currentApproxLocation(timeout: timeout);
  }
}

class _ThrowingRequest extends FakeLocationRepository {
  @override
  Future<LocationPermissionStatus> request() async {
    requestCalls++;
    throw StateError('A request for permissions is already running');
  }
}

void main() {
  group('first launch', () {
    test('not asked: the prompt card shows and nothing is requested', () async {
      final e = await _env();
      expect(e.resolution.mode, ExploreMode.ask);
      expect(e.resolution.origin, isNull);
      expect((e.repo as FakeLocationRepository).requestCalls, 0);
    });

    test('while the first status is being read the mode is loading', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          locationRepositoryProvider.overrideWithValue(
            FakeLocationRepository(),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(exploreResolutionProvider).mode, ExploreMode.loading);
    });
  });

  group('allow', () {
    test(
      'granted with a fix: nearby from the device, request counted once',
      () async {
        final repo = FakeLocationRepository(location: _fix());
        final e = await _env(repo: repo);
        await e.ctrl.allow();
        expect(repo.requestCalls, 1);
        expect(e.state.requesting, isFalse);
        expect(e.resolution.mode, ExploreMode.nearby);
        expect(e.resolution.origin!.fromDevice, isTrue);
        expect(e.resolution.origin!.geohash5, _fix().geohash5);
      },
    );

    test('shows requesting, then locating, while the platform works', () async {
      final repo = _Gated(location: _fix());
      final e = await _env(repo: repo);
      final done = e.ctrl.allow();
      await pumpEventQueue();
      expect(e.resolution.mode, ExploreMode.requesting);
      repo.requestGate.complete();
      await pumpEventQueue();
      expect(e.resolution.mode, ExploreMode.locating);
      repo.locationGate.complete();
      await done;
      expect(e.resolution.mode, ExploreMode.nearby);
    });

    test('a second allow while requesting is a no-op', () async {
      final repo = _Gated(location: _fix());
      final e = await _env(repo: repo);
      final first = e.ctrl.allow();
      await pumpEventQueue();
      await e.ctrl.allow(); // returns immediately, does not wait on the gate
      repo.requestGate.complete();
      repo.locationGate.complete();
      await first;
      expect(repo.requestCalls, 1);
      expect(e.resolution.mode, ExploreMode.nearby);
    });

    test('a platform exception from request() leaves a safe state', () async {
      final repo = _ThrowingRequest();
      final e = await _env(repo: repo);
      await e.ctrl.allow();
      expect(repo.requestCalls, 1);
      expect(e.state.requesting, isFalse);
      expect(e.state.loaded, isTrue);
      expect(e.resolution.mode, ExploreMode.ask);
      await e.ctrl.allow(); // can be retried
      expect(repo.requestCalls, 2);
    });

    test('denied: choose an area, and the OS is not asked again', () async {
      final repo = FakeLocationRepository(
        statusAfterRequest: LocationPermissionStatus.denied,
      );
      final e = await _env(repo: repo);
      await e.ctrl.allow();
      expect(e.state.permission, LocationPermissionStatus.denied);
      expect(e.resolution.mode, ExploreMode.chooseArea);
    });

    test('granted but no fix before the deadline: choose an area', () async {
      final e = await _env(repo: FakeLocationRepository()); // location == null
      await e.ctrl.allow();
      expect(e.state.permission, LocationPermissionStatus.granted);
      expect(e.resolution.mode, ExploreMode.chooseArea);
    });
  });

  group('other permission states', () {
    for (final s in [
      LocationPermissionStatus.denied,
      LocationPermissionStatus.deniedForever,
      LocationPermissionStatus.serviceOff,
    ]) {
      test('${s.name} resolves to choosing an area', () async {
        final e = await _env(repo: FakeLocationRepository(status: s));
        expect(e.resolution.mode, ExploreMode.chooseArea);
      });
    }

    test('already granted at start: nearby without any prompt', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.granted,
        location: _fix(),
      );
      final e = await _env(repo: repo);
      expect(e.resolution.mode, ExploreMode.nearby);
      expect(repo.requestCalls, 0);
    });

    test('openSettings goes to the repository', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.deniedForever,
      );
      final e = await _env(repo: repo);
      await e.ctrl.openSettings();
      expect(repo.openSettingsCalls, 1);
    });

    test(
      'permission revoked in Settings: the fix is dropped on refresh',
      () async {
        final repo = FakeLocationRepository(
          status: LocationPermissionStatus.granted,
          location: _fix(),
        );
        final e = await _env(repo: repo);
        expect(e.resolution.mode, ExploreMode.nearby);
        repo.status = LocationPermissionStatus.deniedForever;
        await e.ctrl.refresh();
        expect(e.state.location, isNull);
        expect(e.resolution.mode, ExploreMode.chooseArea);
      },
    );
  });

  group('"Để sau"', () {
    test('hides the card for 7 days and remembers across restarts', () async {
      final e = await _env();
      await e.ctrl.later();
      expect(e.resolution.mode, ExploreMode.chooseArea);
      expect(
        e.prefs.getString(LocationController.deferredKey),
        _t0.add(const Duration(days: 7)).toIso8601String(),
      );

      final again = await _env(
        prefsValues: {
          LocationController.deferredKey: _t0
              .add(const Duration(days: 7))
              .toIso8601String(),
        },
      );
      expect(again.resolution.mode, ExploreMode.chooseArea);
    });

    test('after 7 days the card comes back', () async {
      final e = await _env();
      await e.ctrl.later();
      e.clock.now = _t0.add(const Duration(days: 7, seconds: 1));
      e.container.invalidate(exploreResolutionProvider);
      expect(e.resolution.mode, ExploreMode.ask);
    });
  });

  group('manual area', () {
    test(
      'wins over the device, needs no permission, and stores no coordinates',
      () async {
        final repo = FakeLocationRepository(
          status: LocationPermissionStatus.granted,
          location: _fix(),
        );
        final e = await _env(repo: repo);
        await e.ctrl.chooseArea(builtInAreas.first);
        expect(e.resolution.mode, ExploreMode.nearby);
        expect(e.resolution.origin!.fromDevice, isFalse);
        expect(e.resolution.origin!.areaName, 'Quận 1, TP.HCM');

        final stored = jsonDecode(
          e.prefs.getString(LocationController.areaKey)!,
        ) as Map<String, dynamic>;
        expect(stored.keys.toSet(), {'id', 'name', 'geohash5'});
        expect(
          e.prefs.getKeys().any((k) => k.toLowerCase().contains('lat')),
          isFalse,
        );
      },
    );

    test(
      'is restored on the next start, even when permission is denied',
      () async {
        final saved = builtInAreas[5].toSaved();
        final e = await _env(
          repo: FakeLocationRepository(
            status: LocationPermissionStatus.deniedForever,
          ),
          prefsValues: {LocationController.areaKey: jsonEncode(saved.toJson())},
        );
        expect(e.resolution.mode, ExploreMode.nearby);
        expect(e.resolution.origin!.areaName, 'Hoàn Kiếm, Hà Nội');
      },
    );

    test('a corrupt stored value is ignored', () async {
      final e = await _env(prefsValues: {LocationController.areaKey: '{oops'});
      expect(e.state.area, isNull);
    });

    test(
      'useDeviceLocation clears the area and goes back to the fix',
      () async {
        final repo = FakeLocationRepository(
          status: LocationPermissionStatus.granted,
          location: _fix(),
        );
        final e = await _env(repo: repo);
        await e.ctrl.chooseArea(builtInAreas.first);
        await e.ctrl.useDeviceLocation();
        expect(e.prefs.getString(LocationController.areaKey), isNull);
        expect(e.resolution.origin!.fromDevice, isTrue);
      },
    );

    test('useDeviceLocation asks first when permission was never asked; a refusal keeps the area', () async {
      final repo = FakeLocationRepository(
        statusAfterRequest: LocationPermissionStatus.denied,
      );
      final e = await _env(repo: repo);
      await e.ctrl.chooseArea(builtInAreas.first);
      await e.ctrl.useDeviceLocation();
      expect(repo.requestCalls, 1);
      expect(e.state.area, isNotNull);
    });
  });

  group('fresh location', () {
    test(
      'a fix older than 30 minutes is replaced on refreshLocation',
      () async {
        final repo = FakeLocationRepository(
          status: LocationPermissionStatus.granted,
          location: _fix(),
        );
        final e = await _env(repo: repo);
        expect(repo.locationCalls, 1);
        e.clock.now = _t0.add(const Duration(minutes: 31));
        repo.location = _fix(e.clock.now);
        await e.ctrl.refreshLocation();
        expect(repo.locationCalls, 2);
        expect(e.state.location!.capturedAt, e.clock.now);
      },
    );

    test(
      'a failed refresh keeps the previous fix while it is still usable',
      () async {
        final repo = FakeLocationRepository(
          status: LocationPermissionStatus.granted,
          location: _fix(),
        );
        final e = await _env(repo: repo);
        repo.location = null;
        await e.ctrl.refreshLocation();
        expect(e.state.location, isNotNull);
      },
    );
  });

  test('ExploreOrigin never prints coordinates', () {
    const o = ExploreOrigin(lat: 10.7769, lng: 106.7009, fromDevice: true);
    expect(o.toString(), isNot(contains('10.77')));
    expect(o.cellPrefix(3), hasLength(3));
  });

  group('areasProvider', () {
    test(
      'uses the repository list, and the built-in list when it fails',
      () async {
        final ok = await _env();
        expect(await ok.container.read(areasProvider.future), builtInAreas);

        final broken = await _env(
          extra: [areaRepositoryProvider.overrideWithValue(_Throwing())],
        );
        expect(await broken.container.read(areasProvider.future), builtInAreas);
      },
    );
  });
}

class _Throwing implements AreaRepository {
  @override
  Future<List<AreaOption>> list() async => throw StateError('offline');
}
