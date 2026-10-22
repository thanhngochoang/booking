import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/instant_work/live_shutter_heartbeat.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';

Future<InstantWorld> _pump(
  WidgetTester tester, {
  required bool online,
  required Duration heartbeatAgo,
  Duration sample = const Duration(seconds: 60),
  bool enabled = true,
}) async {
  final clock = InstantClock();
  final repo = FakeInstantRepository(
    presence: presenceOf(
      online: online,
      heartbeatAt: clock.now.subtract(heartbeatAgo),
    ),
  );
  final world = InstantWorld(repo: repo, clock: clock);
  world.location.position = taoDan;
  await tester.pumpWidget(
    ProviderScope(
      overrides: world.overrides,
      child: LiveShutterHeartbeat(
        enabled: enabled,
        sample: sample,
        child: const SizedBox(),
      ),
    ),
  );
  await tester.pump();
  return world;
}

int _writes(InstantWorld w) => w.repo.callsOf('heartbeat').length;

void _lifecycle(WidgetTester tester, AppLifecycleState s) =>
    tester.binding.handleAppLifecycleStateChanged(s);

void main() {
  testWidgets('writes on resume when online', (tester) async {
    final w = await _pump(
      tester,
      online: true,
      heartbeatAgo: const Duration(minutes: 10),
    );
    // Opening the app with Live Shutter on is a resume: one write at once.
    expect(_writes(w), 1);
    expect(w.repo.callsOf('heartbeat').single.args, {
      'lat': taoDan.lat,
      'lng': taoDan.lng,
      // The fix's own accuracy.
      'accuracyM': 35.0,
    });

    _lifecycle(tester, AppLifecycleState.inactive);
    _lifecycle(tester, AppLifecycleState.hidden);
    _lifecycle(tester, AppLifecycleState.paused);
    await w.wait(tester, const Duration(minutes: 10));
    // Nothing in the background (no fix, no write).
    expect(_writes(w), 1);
    final fixes = w.location.fixCalls;

    _lifecycle(tester, AppLifecycleState.hidden);
    _lifecycle(tester, AppLifecycleState.inactive);
    _lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(_writes(w), 2);
    expect(w.location.fixCalls, fixes + 1);

    // A resume within 60 s of the last write waits (the rules refuse it).
    _lifecycle(tester, AppLifecycleState.inactive);
    _lifecycle(tester, AppLifecycleState.hidden);
    _lifecycle(tester, AppLifecycleState.paused);
    await w.wait(tester, const Duration(seconds: 20));
    _lifecycle(tester, AppLifecycleState.hidden);
    _lifecycle(tester, AppLifecycleState.inactive);
    _lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(_writes(w), 2);

    await tester.pumpWidget(const SizedBox());
    await w.repo.dispose();
  });

  testWidgets('writes after 5 minutes, not before', (tester) async {
    // Just switched on: `setLiveShutter` wrote the heartbeat.
    final w = await _pump(tester, online: true, heartbeatAgo: Duration.zero);
    expect(_writes(w), 0);

    await w.wait(tester, const Duration(minutes: 4, seconds: 50));
    expect(_writes(w), 0);
    // The baseline at switch-on, then a fix every minute, all in one place.
    expect(w.location.fixCalls, 5);

    await w.wait(tester, const Duration(seconds: 10));
    expect(_writes(w), 1);

    await w.wait(tester, const Duration(minutes: 4));
    expect(_writes(w), 1);
    await w.wait(tester, const Duration(minutes: 1));
    expect(_writes(w), 2);

    await tester.pumpWidget(const SizedBox());
    await w.repo.dispose();
  });

  testWidgets(
    'writes on a 350 m move after 70 s, not on a 350 m move after 30 s',
    (tester) async {
      final w = await _pump(
        tester,
        online: true,
        heartbeatAgo: const Duration(minutes: 10),
        sample: const Duration(seconds: 10),
      );
      expect(_writes(w), 1);
      w.location.position = taoDanNorth;

      await w.wait(tester, const Duration(seconds: 30));
      expect(_writes(w), 1);

      await w.wait(tester, const Duration(seconds: 40));
      expect(_writes(w), 2);
      expect(w.repo.callsOf('heartbeat').last.args['lat'], taoDanNorth.lat);

      // Standing still afterwards: no write until the 5 minutes.
      await w.wait(tester, const Duration(minutes: 2));
      expect(_writes(w), 2);

      await tester.pumpWidget(const SizedBox());
      await w.repo.dispose();
    },
  );

  testWidgets('after switch-on the first fix is the baseline: a 350 m move '
      'after 70 s is written', (tester) async {
    // `setLiveShutter` just wrote the position; no write of ours yet.
    final w = await _pump(tester, online: true, heartbeatAgo: Duration.zero);
    expect(_writes(w), 0);
    expect(w.location.fixCalls, 1);

    await w.wait(tester, const Duration(seconds: 70));
    w.location.position = taoDanNorth;
    expect(_writes(w), 0);
    await w.wait(tester, const Duration(seconds: 60));
    expect(_writes(w), 1);
    expect(w.repo.callsOf('heartbeat').single.args['lat'], taoDanNorth.lat);

    await tester.pumpWidget(const SizedBox());
    await w.repo.dispose();
  });

  testWidgets('a failed write is not counted: the next sample retries', (
    tester,
  ) async {
    final logs = <String?>[];
    final print = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m);
    final clock = InstantClock();
    final repo = FakeInstantRepository(
      presence: presenceOf(
        online: true,
        heartbeatAt: clock.now.subtract(const Duration(minutes: 10)),
      ),
    )..failNext('heartbeat', 'network');
    final w = InstantWorld(repo: repo, clock: clock)
      ..location.position = taoDan;
    await tester.pumpWidget(
      ProviderScope(
        overrides: w.overrides,
        child: const LiveShutterHeartbeat(child: SizedBox()),
      ),
    );
    await tester.pump();
    expect(_writes(w), 1);
    expect(logs.single, contains('network'));

    await w.wait(tester, const Duration(seconds: 60));
    expect(_writes(w), 2);
    await w.wait(tester, const Duration(seconds: 60));
    expect(_writes(w), 2);

    debugPrint = print;
    await tester.pumpWidget(const SizedBox());
    await repo.dispose();
  });

  testWidgets('a fix that throws an Error is contained', (tester) async {
    final logs = <String?>[];
    final print = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m);
    final clock = InstantClock();
    final repo = FakeInstantRepository(
      presence: presenceOf(online: true, heartbeatAt: clock.now),
    );
    final w = InstantWorld(repo: repo, clock: clock, location: _ThrowingFix());
    await tester.pumpWidget(
      ProviderScope(
        overrides: w.overrides,
        child: const LiveShutterHeartbeat(child: SizedBox()),
      ),
    );
    await w.wait(tester, const Duration(seconds: 120));
    expect(tester.takeException(), isNull);
    expect(_writes(w), 0);
    expect(logs, isNotEmpty);
    debugPrint = print;
    await tester.pumpWidget(const SizedBox());
    await repo.dispose();
  });

  testWidgets('enabled: false listens to nothing and takes no fix', (
    tester,
  ) async {
    final w = await _pump(
      tester,
      online: true,
      heartbeatAgo: const Duration(minutes: 10),
      enabled: false,
    );
    await w.wait(tester, const Duration(minutes: 6));
    expect(w.location.fixCalls, 0);
    expect(_writes(w), 0);
    await tester.pumpWidget(const SizedBox());
    await w.repo.dispose();
  });

  testWidgets(
    'stops when offline or when the widget is disposed (no pending timers)',
    (tester) async {
      final w = await _pump(
        tester,
        online: true,
        heartbeatAgo: const Duration(minutes: 10),
      );
      expect(_writes(w), 1);

      w.repo.emitPresence(presenceOf(heartbeatAt: w.clock.now));
      await tester.pump();
      final fixes = w.location.fixCalls;
      await w.wait(tester, const Duration(minutes: 10));
      expect(_writes(w), 1);
      expect(w.location.fixCalls, fixes);

      // Back online: the timer runs again until the widget goes.
      w.repo.emitPresence(presenceOf(online: true, heartbeatAt: w.clock.now));
      await tester.pump();
      await w.wait(tester, const Duration(minutes: 2));
      expect(w.location.fixCalls, greaterThan(fixes));

      await tester.pumpWidget(const SizedBox());
      // flutter_test fails the test if a timer is still pending here.
      await w.repo.dispose();
    },
  );
}

class _ThrowingFix extends FakeLocationRepository {
  _ThrowingFix() : super(status: LocationPermissionStatus.granted);

  @override
  Future<LocationFix?> currentFix({
    bool highAccuracy = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    throw StateError('platform channel bug');
  }
}
