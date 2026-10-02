// test/features/explore/explore_mock_layout_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/explore_screen.dart';
import 'package:photobooking/features/explore/location_controller.dart';

import '../../support/explore_world.dart';
import '../../support/screen_host.dart';

/// S13 and S35 laid out as in `docs/design/ui-mock.html` (mock parity 1,
/// Task 9), on a 390×844 phone.
Future<ExploreWorld> _open(
  WidgetTester tester, {
  ExploreWorld? world,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = world ?? ExploreWorld();
  await w.init();
  await tester.pumpWidget(
    screenApp(home: const ExploreScreen(), overrides: w.overrides),
  );
  await tester.pumpAndSettle();
  return w;
}

ExploreWorld _nearbyWorld({bool routesReady = false}) => ExploreWorld(
  status: LocationPermissionStatus.granted,
  routesReady: routesReady,
  prefsValues: {
    LocationController.areaKey: jsonEncode(
      builtInAreas.first.toSaved().toJson(),
    ),
  },
);

Finder _tiles() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('category-services-'),
);

void main() {
  group('S13 category grid', () {
    testWidgets('four short 21:9 tiles in two columns on a phone', (
      tester,
    ) async {
      await _open(tester);
      expect(_tiles(), findsNWidgets(4));
      final a = tester.getRect(_tiles().at(0));
      final b = tester.getRect(_tiles().at(1));
      final c = tester.getRect(_tiles().at(2));
      expect(a.top, b.top);
      expect(b.left, greaterThan(a.right));
      expect(c.top, greaterThan(a.bottom));
      expect(a.width / a.height, closeTo(21 / 9, 0.05));
    });

    testWidgets('four columns from 600dp', (tester) async {
      await _open(tester, size: const Size(900, 900));
      final first = tester.getRect(_tiles().at(0));
      final fourth = tester.getRect(_tiles().at(3));
      expect(fourth.top, first.top);
    });

    testWidgets('"Xem tất cả" opens the rest of the tab in place', (
      tester,
    ) async {
      await _open(tester);
      expect(
        find.byKey(const Key('category-services-graduation')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('category-see-all')));
      await tester.pumpAndSettle();
      expect(_tiles(), findsWidgets);
      expect(
        find.byKey(const Key('category-services-graduation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('category-see-all')), findsNothing);
    });

    testWidgets('the location card is on the first screen', (tester) async {
      await _open(tester);
      final allow = tester.getRect(find.byKey(const Key('location-allow')));
      expect(allow.bottom, lessThan(844));
    });
  });

  group('LocationPromptCard', () {
    testWidgets('compact buttons in the text column, 13px title, 36dp icon', (
      tester,
    ) async {
      await _open(tester);
      final allow = tester.widget<AppButton>(
        find.byKey(const Key('location-allow')),
      );
      final later = tester.widget<AppButton>(
        find.byKey(const Key('location-later')),
      );
      expect(allow.size, AppButtonSize.xsmall);
      expect(later.size, AppButtonSize.xsmall);
      final title = tester.widget<Text>(find.text('Sự kiện gần bạn'));
      expect(title.style?.fontSize, 13);
      expect(title.style?.fontWeight, FontWeight.w700);
      final icon = find.byKey(const Key('location-prompt-icon'));
      expect(tester.getSize(icon), const Size(36, 36));
      // Buttons start under the body text, right of the icon.
      final body = tester.getRect(find.textContaining('Cho phép dùng vị trí'));
      expect(
        tester.getTopLeft(find.byKey(const Key('location-allow'))).dx,
        closeTo(body.left, 0.5),
      );
    });
  });

  group('section headers', () {
    testWidgets('serif 17 title and an accent 12px "Xem tất cả"', (
      tester,
    ) async {
      await _open(tester, world: _nearbyWorld(routesReady: true));
      final title = tester.widget<Text>(find.text('Sự kiện gần bạn'));
      expect(title.style?.fontFamily, AppFonts.display);
      expect(title.style?.fontSize, 17);
      final seeAll = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('explore-see-all')),
          matching: find.byType(Text),
        ),
      );
      expect(seeAll.style?.fontSize, AppText.sm);
      expect(seeAll.style?.color, AppColorsDark.primary);
    });
  });

  group('S35', () {
    testWidgets('the location line has a 15dp accent pin', (tester) async {
      await _open(tester, world: _nearbyWorld());
      final pin = tester.widget<Icon>(find.byKey(const Key('explore-pin')));
      expect(pin.size, 15);
      expect(pin.color, AppColorsDark.primary);
    });

    testWidgets('event rows: accent day, #type tag, price and seats right', (
      tester,
    ) async {
      await _open(tester, world: _nearbyWorld());
      final row = find.byKey(const Key('event-tile-near'));
      final day = tester.widget<Text>(
        find.descendant(of: row, matching: find.byKey(const Key('event-day'))),
      );
      expect(day.style?.color, AppColorsDark.primary);
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining(RegExp(r'^#[a-z]+$')),
        ),
        findsOneWidget,
      );
      final title = tester.getRect(
        find.descendant(
          of: row,
          matching: find.byKey(const Key('event-title')),
        ),
      );
      final seats = tester.getRect(
        find.descendant(
          of: row,
          matching: find.byKey(const Key('event-seats')),
        ),
      );
      expect(seats.left, greaterThan(title.right));
    });
  });

  testWidgets('section header goes nowhere without event routes', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const ExploreScreen())],
    );
    final w = _nearbyWorld();
    await w.init();
    await tester.pumpWidget(
      screenRouterApp(router: router, overrides: w.overrides),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('explore-see-all')), findsNothing);
  });

  testWidgets('a tab root keeps the 22px left-aligned title', (tester) async {
    await _open(tester);
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.centerTitle, isFalse);
    expect(bar.titleTextStyle?.fontSize, 22);
  });
}
