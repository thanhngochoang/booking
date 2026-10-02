import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import '../support/discovery_world.dart';
import '../support/screen_host.dart';

void _collect(Iterable<RouteBase> routes, List<String> out) {
  for (final r in routes) {
    if (r is GoRoute) {
      out.add(r.path);
      _collect(r.routes, out);
    } else if (r is StatefulShellRoute) {
      for (final b in r.branches) {
        _collect(b.routes, out);
      }
    } else {
      _collect(r.routes, out);
    }
  }
}

void main() {
  test('the router knows the five tabs and the photo route', () {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    addTearDown(c.dispose);
    final paths = <String>[];
    _collect(c.read(routerProvider).configuration.routes, paths);
    expect(
      paths,
      containsAll([
        for (final t in AppTab.values) t.path,
        '/p/:postId',
        '/settings',
        '/login',
      ]),
    );
  });

  testWidgets(
    'a customer\'s middle tab is Find, and it takes the filters of the link',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = DiscoveryWorld();
      await w.init();
      await tester.pumpWidget(
        screenApp(
          home: const ActionTab(specialty: 'wedding'),
          overrides: w.overrides,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FindPhotographerScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('find-service')),
          matching: find.text('Cưới'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a photographer\'s middle tab is still the create placeholder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = DiscoveryWorld(role: UserRole.photographer);
    await w.init();
    await tester.pumpWidget(
      screenApp(home: const ActionTab(), overrides: w.overrides),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FindPhotographerScreen), findsNothing);
    expect(find.text('Cho mọi người thấy bạn chụp gì'), findsOneWidget);
  });
}
