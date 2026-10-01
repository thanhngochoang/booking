import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/area_picker_sheet.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/screen_host.dart';

final _t0 = DateTime.utc(2026, 10, 1, 5);

class _Delayed implements AreaRepository {
  final completer = Completer<List<AreaOption>>();
  @override
  Future<List<AreaOption>> list() => completer.future;
}

class _Throwing implements AreaRepository {
  @override
  Future<List<AreaOption>> list() async => throw StateError('offline');
}

Future<(Widget, SharedPreferences, FakeLocationRepository)> _app({
  LocationPermissionStatus status = LocationPermissionStatus.notAsked,
  Map<String, Object> prefsValues = const {},
  AreaRepository? areas,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final repo = FakeLocationRepository(
    status: status,
    location: ApproxLocation(lat: 10.7769, lng: 106.7009, capturedAt: _t0),
  );
  final widget = screenApp(
    textScale: textScale,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      locationRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _t0),
      if (areas != null) areaRepositoryProvider.overrideWithValue(areas),
    ],
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAreaPicker(context),
            child: const Text('mở'),
          ),
        ),
      ),
    ),
  );
  return (widget, prefs, repo);
}

Future<void> _open(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) =>
    tester
        .widget<FilledButton>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('lists the areas under the explanation, nothing chosen yet', (
    tester,
  ) async {
    final (app, _, _) = await _app();
    await _open(tester, app);
    expect(find.text('Chọn khu vực của bạn'), findsOneWidget);
    expect(
      find.text(
        'Vị trí đang tắt. Chọn khu vực để xem sự kiện quanh đó, hoặc bật vị trí trong Cài đặt.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('area-hcm-q1')), findsOneWidget);
    expect(_enabled(tester, 'area-use'), isFalse);
  });

  testWidgets(
    'choosing a row enables the button; confirming saves and closes',
    (tester) async {
      final (app, prefs, _) = await _app();
      await _open(tester, app);
      await tester.tap(find.byKey(const Key('area-hcm-q3')));
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'area-use'), isTrue);
      await tester.tap(find.byKey(const Key('area-use')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn khu vực của bạn'), findsNothing);
      final saved =
          jsonDecode(prefs.getString(LocationController.areaKey)!) as Map;
      expect(saved['id'], 'hcm-q3');
      expect(saved.containsKey('lat'), isFalse);
    },
  );

  testWidgets('closing without choosing changes nothing', (tester) async {
    final (app, prefs, _) = await _app();
    await _open(tester, app);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(prefs.getString(LocationController.areaKey), isNull);
  });

  testWidgets('the saved area is preselected', (tester) async {
    final (app, _, _) = await _app(
      prefsValues: {
        LocationController.areaKey: jsonEncode(
          builtInAreas[5].toSaved().toJson(),
        ),
      },
    );
    await _open(tester, app);
    // The list is lazy: rows below the fold are not built until scrolled to.
    await tester.scrollUntilVisible(
      find.byKey(const Key('area-hn-hoan-kiem')),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final selected = tester.getSemantics(
      find.byKey(const Key('area-hn-hoan-kiem')),
    );
    expect(selected.label, contains('Hoàn Kiếm'));
    expect(
      selected.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(_enabled(tester, 'area-use'), isTrue);
  });

  testWidgets('search ignores accents and shows a no-match message', (
    tester,
  ) async {
    final (app, _, _) = await _app();
    await _open(tester, app);
    expect(find.byKey(const Key('area-search')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('area-search')), 'quan 1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-hcm-q1')), findsOneWidget);
    expect(find.byKey(const Key('area-hcm-q3')), findsNothing);
    await tester.enterText(find.byKey(const Key('area-search')), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy khu vực'), findsOneWidget);
  });

  testWidgets('open-settings button only for denied-forever, and it works', (
    tester,
  ) async {
    final (app, _, repo) = await _app(
      status: LocationPermissionStatus.deniedForever,
    );
    await _open(tester, app);
    expect(find.byKey(const Key('area-use-device')), findsNothing);
    await tester.tap(find.byKey(const Key('area-open-settings')));
    expect(repo.openSettingsCalls, 1);

    final (plain, _, _) = await _app(status: LocationPermissionStatus.notAsked);
    await tester.pumpWidget(const SizedBox());
    await _open(tester, plain);
    expect(find.byKey(const Key('area-open-settings')), findsNothing);
  });

  testWidgets(
    '"Dùng vị trí của tôi" is offered and switches back to the device',
    (tester) async {
      final (app, prefs, _) = await _app(
        status: LocationPermissionStatus.granted,
        prefsValues: {
          LocationController.areaKey: jsonEncode(
            builtInAreas.first.toSaved().toJson(),
          ),
        },
      );
      await _open(tester, app);
      await tester.tap(find.byKey(const Key('area-use-device')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-use')));
      await tester.pumpAndSettle();
      expect(prefs.getString(LocationController.areaKey), isNull);
    },
  );

  testWidgets('a list that fails to load falls back to the built-in areas', (
    tester,
  ) async {
    final (app, _, _) = await _app(areas: _Throwing());
    await _open(tester, app);
    expect(find.byKey(const Key('area-hcm-q1')), findsOneWidget);
  });

  testWidgets('fits 320x568 at 1.3x with the main button always reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (app, _, _) = await _app(textScale: 1.3);
    await _open(tester, app);
    expect(tester.takeException(), isNull);
    final button = tester.getRect(find.byKey(const Key('area-use')));
    // Material scales button padding with the text, so 52 is a floor.
    expect(button.height, greaterThanOrEqualTo(52));
    expect(button.bottom, lessThanOrEqualTo(568));
  });

  testWidgets('while the list loads: skeleton, no no-match text', (
    tester,
  ) async {
    final delayed = _Delayed();
    final (app, _, _) = await _app(areas: delayed);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('mở'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AppSkeleton), findsWidgets);
    expect(find.text('Không tìm thấy khu vực'), findsNothing);
    delayed.completer.complete(builtInAreas);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('area-hcm-q1')), findsOneWidget);
    expect(find.byType(AppSkeleton), findsNothing);
  });

  testWidgets('a saved area missing from the list does not break confirm', (
    tester,
  ) async {
    final (app, prefs, _) = await _app(
      prefsValues: {
        LocationController.areaKey: jsonEncode({
          'id': 'gone',
          'name': 'Gone',
          'geohash5': 'w3gvk',
        }),
      },
    );
    await _open(tester, app);
    expect(_enabled(tester, 'area-use'), isTrue);
    await tester.tap(find.byKey(const Key('area-use')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Chọn khu vực của bạn'), findsNothing);
    expect(prefs.getString(LocationController.areaKey), contains('gone'));
  });

  testWidgets('device row that ends denied-forever keeps the sheet open', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = FakeLocationRepository(
      statusAfterRequest: LocationPermissionStatus.deniedForever,
    );
    await tester.pumpWidget(
      screenApp(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          locationRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => _t0),
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAreaPicker(context),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('area-use-device')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('area-use')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn khu vực của bạn'), findsOneWidget);
    expect(find.byKey(const Key('area-open-settings')), findsOneWidget);
    expect(_enabled(tester, 'area-use'), isTrue);
  });

  testWidgets('keyboard open at 320x568, 1.3x, denied-forever: no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final (app, _, _) = await _app(
      status: LocationPermissionStatus.deniedForever,
      textScale: 1.3,
    );
    await _open(tester, app);
    // The header scrolls with the list, so the field is reachable.
    await tester.ensureVisible(find.byKey(const Key('area-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('area-search')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
