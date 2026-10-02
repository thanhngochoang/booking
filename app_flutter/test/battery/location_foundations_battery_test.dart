import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/geolocator_location_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/widgets/widget_host.dart';
import '../support/blur.dart';
import '../support/idle.dart';

class _CountingGateway implements LocationGateway {
  int positionCalls = 0;
  int requestCalls = 0;
  Duration? lastTimeout;

  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<RawPermission> checkPermission() async => RawPermission.granted;
  @override
  Future<RawPermission> requestPermission() async {
    requestCalls++;
    return RawPermission.granted;
  }

  @override
  Future<({double lat, double lng})> lowAccuracyPosition(
    Duration timeout,
  ) async {
    positionCalls++;
    lastTimeout = timeout;
    return (lat: 10.7769, lng: 106.7009);
  }

  @override
  Future<bool> openAppSettings() async => true;
}

void main() {
  group('widgets at rest do not keep the frame loop running', () {
    testWidgets('AppChip and SegmentedTabs', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          Column(
            children: [
              AppChip(label: 'Cuối tuần', selected: true, onChanged: (_) {}),
              SegmentedTabs<int>(
                options: const [
                  SegmentOption(value: 0, label: 'Dịch vụ'),
                  SegmentOption(value: 1, label: 'Địa điểm'),
                ],
                value: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      await expectIdle(tester);
    });

    for (final state in [LocationPromptState.ask, LocationPromptState.denied]) {
      testWidgets('LocationPromptCard ${state.name}', (tester) async {
        await tester.pumpWidget(
          hostWidget(
            LocationPromptCard(
              state: state,
              onAllow: () {},
              onLater: () {},
              onChooseArea: () {},
            ),
          ),
        );
        await expectIdle(tester);
        expectBlurBudget(max: 1);
      });
    }

    testWidgets('SliverAdaptiveRows and an open sheet', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showAppSheet<void>(
                    context,
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nội dung'),
                    ),
                  ),
                  child: const Text('mở'),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverAdaptiveRows(
                        itemCount: 20,
                        itemBuilder: (_, i) =>
                            SizedBox(height: 40, child: Text('Mục $i')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await expectIdle(tester);
      await tester.tap(find.text('mở'));
      await expectIdle(tester);
      expectBlurBudget(max: 1); // the sheet frame is the only blur
    });
  });

  testWidgets('SliverAdaptiveRows builds only what is on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      hostWidget(
        CustomScrollView(
          slivers: [
            SliverAdaptiveRows(
              itemCount: 2000,
              itemBuilder: (_, i) =>
                  SizedBox(height: 60, child: Text('Mục $i')),
            ),
          ],
        ),
      ),
    );
    final built = find.textContaining('Mục ').evaluate().length;
    expect(
      built,
      lessThan(40),
      reason: 'a lazy list, not a Column of all items',
    );
  });

  group('location is a one-shot, low-accuracy, foreground request', () {
    test(
      'one gateway position call per fix, with a deadline, and none for status',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final gateway = _CountingGateway();
        final repo = GeolocatorLocationRepository(
          gateway: gateway,
          prefs: prefs,
        );
        await repo.permissionStatus();
        expect(
          gateway.positionCalls,
          0,
          reason: 'checking permission never reads a position',
        );
        await repo.currentApproxLocation();
        expect(gateway.positionCalls, 1);
        expect(gateway.lastTimeout, const Duration(seconds: 8));
        await repo.request();
        expect(gateway.requestCalls, 1);
      },
    );

    test(
      'the adapter source has no stream, no high accuracy, no background',
      () {
        final src = File(
          'lib/data/location/geolocator_location_repository.dart',
        ).readAsStringSync();
        expect(src, contains('getCurrentPosition'));
        expect(src, contains('LocationAccuracy.low'));
        expect(src, contains('timeLimit'));
        for (final banned in [
          'getPositionStream',
          'getServiceStatusStream',
          'LocationAccuracy.high',
          'LocationAccuracy.best',
          'LocationAccuracy.medium',
          'requestAlways',
          'foregroundNotificationConfig',
          'Timer.periodic',
        ]) {
          expect(src, isNot(contains(banned)), reason: banned);
        }
      },
    );

    test('the port has no stream either', () {
      final src = File('lib/data/location/location_repository.dart')
          .readAsStringSync();
      expect(src, isNot(contains('Stream<')));
    });

    test('Android asks for approximate location only', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('ACCESS_COARSE_LOCATION'));
      for (final banned in [
        'ACCESS_FINE_LOCATION',
        'ACCESS_BACKGROUND_LOCATION',
      ]) {
        expect(manifest, isNot(contains(banned)), reason: banned);
      }
      // The foreground-service permission may only appear to be removed
      // (geolocator_android merges it in; we strip it on purpose).
      final fgs = RegExp(r'<[^>]*FOREGROUND_SERVICE_LOCATION[^>]*>')
          .allMatches(manifest);
      for (final m in fgs) {
        expect(
          m.group(0),
          contains('tools:node="remove"'),
          reason: 'FOREGROUND_SERVICE_LOCATION must only be removed',
        );
      }
    });

    test(
      'iOS asks for when-in-use location only, with a Vietnamese reason',
      () {
        final plist = File('ios/Runner/Info.plist').readAsStringSync();
        expect(
          plist,
          contains('<key>NSLocationWhenInUseUsageDescription</key>'),
        );
        final reason = RegExp(
          r'<key>NSLocationWhenInUseUsageDescription</key>\s*<string>([^<]+)</string>',
        ).firstMatch(plist)!.group(1)!;
        expect(reason, contains('vị trí gần đúng'));
        expect(reason, contains('không được lưu lên máy chủ'));
        for (final banned in [
          'NSLocationAlwaysAndWhenInUseUsageDescription',
          'NSLocationAlwaysUsageDescription',
          'NSLocationTemporaryUsageDescriptionDictionary',
        ]) {
          expect(plist, isNot(contains(banned)), reason: banned);
        }
        // No background mode may include location.
        final modes = RegExp(
          r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
          dotAll: true,
        ).firstMatch(plist);
        expect(modes?.group(1) ?? '', isNot(contains('location')));
      },
    );
  });
}
