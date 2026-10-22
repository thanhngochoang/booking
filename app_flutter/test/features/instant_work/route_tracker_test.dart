import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/instant_work/route_tracker.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';

/// Degrees of latitude per metre (about).
const _degPerM = 1 / 111195.0;

class _FakeTimer implements Timer {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

/// Drives a [RouteTracker] by hand: the clock and the periodic callback.
class _Rig {
  _Rig() {
    tracker = RouteTracker(
      location: location,
      repo: repo,
      requestId: 'req1',
      now: () => now,
      timer: (every, onTick) {
        period = every;
        this.onTick = onTick;
        return timer = _FakeTimer();
      },
    );
  }

  final repo = FakeInstantRepository();
  final location = FakeLocationRepository(
    status: LocationPermissionStatus.granted,
    position: taoDan,
  );
  DateTime now = instantNow;
  late final RouteTracker tracker;
  Duration? period;
  void Function()? onTick;
  _FakeTimer? timer;

  int get writes => repo.callsOf('shareTrack').length;

  /// Moves [metres] north of Tao Đàn.
  void moveTo(double metres) => location.position = (
    lat: taoDan.lat + metres * _degPerM,
    lng: taoDan.lng,
  );

  /// [d] passes, then the periodic callback fires.
  Future<void> tick([Duration d = const Duration(seconds: 15)]) async {
    now = now.add(d);
    onTick!();
    await pumpEventQueue();
  }
}

void main() {
  test('first fix writes at once', () async {
    final rig = _Rig();
    rig.tracker.start();
    await pumpEventQueue();

    expect(rig.period, const Duration(seconds: 15));
    final call = rig.repo.callsOf('shareTrack').single;
    expect(call.args['requestId'], 'req1');
    expect(call.args['lat'], taoDan.lat);
    expect(call.args['lng'], taoDan.lng);
    // The fix's own accuracy, never a constant.
    expect(call.args['accuracyM'], 35);
    // A low-power fix: the high-accuracy one is for the arrival only.
    expect(rig.location.highAccuracyFixCalls, 0);
  });

  test('a 10 m move after 15 s does not write; a 30 m move does', () async {
    final rig = _Rig();
    rig.tracker.start();
    await pumpEventQueue();
    expect(rig.writes, 1);

    rig.moveTo(10);
    await rig.tick();
    expect(rig.writes, 1);

    rig.moveTo(40); // 30 m from the last written point
    await rig.tick();
    expect(rig.writes, 2);
    expect(
      rig.repo.callsOf('shareTrack').last.args['lat'],
      closeTo(taoDan.lat + 40 * _degPerM, 1e-9),
    );
  });

  test('60 s without moving writes once', () async {
    final rig = _Rig();
    rig.tracker.start();
    await pumpEventQueue();

    for (var i = 0; i < 3; i++) {
      await rig.tick();
    }
    expect(rig.writes, 1); // 45 s: nothing new
    await rig.tick(); // 60 s
    expect(rig.writes, 2);
    await rig.tick(); // 75 s
    expect(rig.writes, 2);
  });

  test('never writes twice within 15 s', () async {
    final rig = _Rig();
    rig.tracker.start();
    await pumpEventQueue();

    // A far move 5 s later (e.g. a stop/start on resume) still waits.
    rig.moveTo(500);
    rig.now = rig.now.add(const Duration(seconds: 5));
    rig.tracker
      ..stop()
      ..start();
    await pumpEventQueue();
    expect(rig.writes, 1);

    await rig.tick(const Duration(seconds: 9)); // 14 s after the write
    expect(rig.writes, 1);
    await rig.tick(const Duration(seconds: 1)); // 15 s
    expect(rig.writes, 2);
  });

  test(
    'a point already sent with start_route counts as the last write',
    () async {
      final rig = _Rig();
      rig.tracker.start(
        sent: const LocationFix(lat: 10.7745, lng: 106.6918, accuracyM: 35),
      );
      await pumpEventQueue();
      expect(rig.writes, 0);

      rig.moveTo(30);
      await rig.tick();
      expect(rig.writes, 1);
    },
  );

  test('a refused write is tried again on the next fix', () async {
    final logged = <String?>[];
    final print = debugPrint;
    debugPrint = (m, {wrapWidth}) => logged.add(m);
    addTearDown(() => debugPrint = print);
    final rig = _Rig();
    rig.repo.failNext('shareTrack', 'permission_denied');
    rig.tracker.start();
    await pumpEventQueue();
    expect(rig.writes, 1); // attempted, refused
    expect(logged, ['instant track not written: permission_denied']);

    await rig.tick();
    expect(rig.writes, 2);
  });

  test('every fix is reported, written or not', () async {
    final fixes = <LocationFix>[];
    final rig = _Rig();
    final tracker = RouteTracker(
      location: rig.location,
      repo: rig.repo,
      requestId: 'req1',
      now: () => rig.now,
      timer: (every, onTick) {
        rig.onTick = onTick;
        return _FakeTimer();
      },
      onFix: fixes.add,
    );
    tracker.start();
    await pumpEventQueue();
    rig.moveTo(10);
    await rig.tick();
    expect(fixes, hasLength(2));
    expect(fixes.last.lat, closeTo(taoDan.lat + 10 * _degPerM, 1e-9));
    tracker.stop();
  });

  test('stop cancels the timer', () async {
    final rig = _Rig();
    rig.tracker.start();
    await pumpEventQueue();
    expect(rig.tracker.running, isTrue);

    rig.tracker.stop();
    expect(rig.timer!.cancelled, isTrue);
    expect(rig.tracker.running, isFalse);

    // A late callback does nothing.
    rig.moveTo(100);
    await rig.tick(const Duration(seconds: 60));
    expect(rig.writes, 1);
  });

  test('no fix (permission gone) writes nothing', () async {
    final rig = _Rig();
    rig.location.status = LocationPermissionStatus.denied;
    rig.tracker.start();
    await pumpEventQueue();
    expect(rig.writes, 0);
  });
}
