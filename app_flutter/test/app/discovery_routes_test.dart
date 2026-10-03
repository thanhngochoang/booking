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
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import '../support/booking_world.dart';
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
        '/u/:uid',
        '/u/:uid/book',
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

  testWidgets('a photographer\'s middle tab is the Create post screen', (
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
    expect(find.byType(CreatePostScreen), findsOneWidget);
  });

  testWidgets('/u/p1/book opens the booking sheet, /u/p1 still opens S03.01', (
    tester,
  ) async {
    final handles = await pumpBookingRoute(tester, path: '/u/p1');
    await tester.pumpAndSettle();

    expect(find.byType(PhotographerProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('app-sheet')), findsNothing);

    handles.router.push('/u/p1/book');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-sheet')), findsOneWidget);
  });

  testWidgets('date and serviceId query parameters reach the flow', (
    tester,
  ) async {
    final d = DateTime.utc(2026, 10, 5);
    final path = bookingPath(
      photographerId: 'p1',
      serviceId: 's1',
      date: d,
    );

    await pumpBookingRoute(tester, path: path);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-sheet')), findsOneWidget);
    expect(find.text('DateTimeStep'), findsOneWidget);
  });
}
