// test/battery/explore_battery_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/explore_screen.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/core/core.dart';

import '../data/events/nearby_events_repository_test.dart' show event;
import '../support/blur.dart';
import '../support/explore_world.dart';
import '../support/idle.dart';
import '../support/screen_host.dart';

Future<Widget> _screen(ExploreWorld w) async {
  await w.init();
  return screenApp(home: const ExploreScreen(), overrides: w.overrides);
}

/// Sends the lifecycle messages the OS sends when the app goes to the
/// background and comes back (for example from the Settings app).
Future<void> _backgroundAndBack(WidgetTester tester) async {
  for (final state in ['paused', 'resumed']) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/lifecycle',
      const StringCodec().encodeMessage('AppLifecycleState.$state'),
      (_) {},
    );
    await tester.pump();
  }
}

/// A tall phone, so the lazy list builds the prompt card (the default 800x600
/// view leaves it below the fold).
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _savedArea = {
  LocationController.areaKey: jsonEncode(builtInAreas.first.toSaved().toJson()),
};

void main() {
  group('a settled Explore screen leaves the frame loop', () {
    testWidgets('asking for location', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(await _screen(ExploreWorld()));
      await expectIdle(tester);
      expectBlurBudget(max: 1); // only the prompt card
    });

    testWidgets('nearby events', (tester) async {
      _tallPhone(tester);
      final w = ExploreWorld(
        status: LocationPermissionStatus.granted,
        prefsValues: _savedArea,
      );
      await tester.pumpWidget(await _screen(w));
      await expectIdle(tester);
      expect(find.byType(EventCard), findsWidgets);
      expectBlurBudget(max: 0); // rows never blur
    });

    testWidgets('choosing an area', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(
        await _screen(ExploreWorld(status: LocationPermissionStatus.denied)),
      );
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('with the area sheet open', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(
        await _screen(ExploreWorld(status: LocationPermissionStatus.denied)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-choose-area')));
      await expectIdle(tester);
      expectBlurBudget(max: 1); // the sheet frame
    });
  });

  group('location is requested once', () {
    testWidgets('pull to refresh, resume and filters reuse the fresh fix', (
      tester,
    ) async {
      final w = ExploreWorld(status: LocationPermissionStatus.granted);
      await tester.pumpWidget(await _screen(w));
      await tester.pumpAndSettle();
      expect(w.location.locationCalls, 1);
      expect(w.location.requestCalls, 0, reason: 'already granted: no dialog');

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      final statusBefore = w.location.statusCalls;
      await _backgroundAndBack(tester);
      await tester.pumpAndSettle();
      expect(
        w.location.statusCalls,
        greaterThan(statusBefore),
        reason: 'coming back re-reads the permission (the observer is alive)',
      );
      await tester.tap(find.byKey(const Key('filter-radius-10')));
      await tester.pumpAndSettle();
      expect(
        w.location.locationCalls,
        1,
        reason: 'a fix younger than 30 minutes is reused',
      );
    });

    testWidgets('tapping "Cho phép" asks the OS once and takes one fix', (
      tester,
    ) async {
      _tallPhone(tester);
      final w = ExploreWorld();
      await tester.pumpWidget(await _screen(w));
      await tester.pumpAndSettle();
      expect(w.location.requestCalls, 0);
      await tester.tap(find.byKey(const Key('location-allow')));
      await tester.pumpAndSettle();
      expect((w.location.requestCalls, w.location.locationCalls), (1, 1));
    });
  });

  testWidgets('after the screen is gone nothing keeps running', (tester) async {
    final w = ExploreWorld(
      status: LocationPermissionStatus.granted,
      prefsValues: _savedArea,
    );
    await tester.pumpWidget(await _screen(w));
    await tester.pumpAndSettle();
    final status = w.location.statusCalls;
    final fixes = w.location.locationCalls;
    final queries = w.repo.cellQueries.length;

    await tester.pumpWidget(
      screenApp(home: const SizedBox(), overrides: w.overrides),
    );
    await _backgroundAndBack(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(
      w.location.statusCalls,
      status,
      reason: 'the lifecycle observer was removed',
    );
    expect(w.location.locationCalls, fixes);
    expect(
      w.repo.cellQueries.length,
      queries,
      reason: 'autoDispose providers stopped',
    );
    await expectIdle(tester);
  });

  testWidgets('a long event list is built lazily', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final many = [
      for (var i = 0; i < 100; i++)
        event(
          'n$i',
          lat: 10.7770 + i * 0.0001,
          lng: 106.7009,
          title: 'Sự kiện $i',
        ),
    ];
    final w = ExploreWorld(
      status: LocationPermissionStatus.granted,
      prefsValues: _savedArea,
      events: many,
    );
    await tester.pumpWidget(await _screen(w));
    await tester.pumpAndSettle();
    expect(find.byType(EventCard).evaluate().length, lessThan(25));
  });

  group('source audit of what this plan added', () {
    test(
      'no stream, ticker, periodic timer or controller in the Explore feature',
      () {
        final files = Directory('lib/features/explore')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        expect(files, isNotEmpty);
        for (final f in files) {
          // TickerMode only reads whether this tab is the active one.
          final src = f.readAsStringSync().replaceAll('TickerMode', '');
          for (final banned in [
            'Timer.periodic',
            'Stream.periodic',
            'AnimationController',
            'Ticker',
            'getPositionStream',
          ]) {
            expect(src, isNot(contains(banned)), reason: '${f.path}: $banned');
          }
        }
      },
    );

    test(
      'the events port is future-based, so there is no listener to leak',
      () {
        final src = File('lib/data/events/nearby_events_repository.dart')
            .readAsStringSync();
        expect(src, isNot(contains('Stream<')));
      },
    );

    test(
      'Explore shows no network images, so there is nothing to decode oversize',
      () {
        for (final name in ['explore_screen.dart']) {
          final src = File('lib/features/explore/$name').readAsStringSync();
          expect(src, isNot(contains('Image.network')), reason: name);
          expect(src, isNot(contains('NetworkImage')), reason: name);
          expect(src, isNot(contains('NetworkPhoto')), reason: name);
        }
      },
    );
  });
}
