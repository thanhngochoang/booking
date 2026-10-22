import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/instant_work/live_shutter_heartbeat.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';

Future<InstantWorld> _pump(
  WidgetTester tester, {
  required bool online,
  required Duration heartbeatAgo,
  Duration sample = const Duration(seconds: 60),
}) async {
  final clock = InstantClock();
  final repo = FakeInstantRepository(
    presence: presenceOf(
      online: online,
      heartbeatAt: clock.now.subtract(heartbeatAgo),
    ),
  );
  final world = InstantWorld(repo: repo, clock: clock);
  world.location.location = approxAt(taoDan, clock.now);
  await tester.pumpWidget(
    ProviderScope(
      overrides: world.overrides,
      child: LiveShutterHeartbeat(sample: sample, child: const SizedBox()),
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
      'accuracyM': 500.0,
    });

    _lifecycle(tester, AppLifecycleState.inactive);
    _lifecycle(tester, AppLifecycleState.hidden);
    _lifecycle(tester, AppLifecycleState.paused);
    await w.wait(tester, const Duration(minutes: 10));
    // Nothing in the background (no fix, no write).
    expect(_writes(w), 1);
    final fixes = w.location.locationCalls;

    _lifecycle(tester, AppLifecycleState.hidden);
    _lifecycle(tester, AppLifecycleState.inactive);
    _lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(_writes(w), 2);
    expect(w.location.locationCalls, fixes + 1);

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
    // A fix every minute, all at the same place.
    expect(w.location.locationCalls, 4);

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
      w.location.location = approxAt(taoDanNorth, w.clock.now);

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
      final fixes = w.location.locationCalls;
      await w.wait(tester, const Duration(minutes: 10));
      expect(_writes(w), 1);
      expect(w.location.locationCalls, fixes);

      // Back online: the timer runs again until the widget goes.
      w.repo.emitPresence(presenceOf(online: true, heartbeatAt: w.clock.now));
      await tester.pump();
      await w.wait(tester, const Duration(minutes: 2));
      expect(w.location.locationCalls, greaterThan(fixes));

      await tester.pumpWidget(const SizedBox());
      // flutter_test fails the test if a timer is still pending here.
      await w.repo.dispose();
    },
  );
}
