import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/explore_badge.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/features/shell/tab_badges.dart';
import 'package:photobooking/features/shell/tab_shell.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/events/nearby_events_repository_test.dart' show event;

final _now = DateTime.utc(2026, 10, 1, 5);

/// Three events created 1h, 2h, 3h ago, one 20 days ago, all in Ho Chi Minh City.
List<EventSummary> _events({int newEvents = 3}) => [
  for (var i = 0; i < newEvents; i++)
    event('e$i', createdAgo: Duration(hours: i + 1)),
  event('old', createdAgo: const Duration(days: 20)),
];

FakeNearbyEventsRepository _repo({int newEvents = 3}) =>
    FakeNearbyEventsRepository(_events(newEvents: newEvents));

Future<(ProviderContainer, SharedPreferences)> _make({
  Map<String, Object> prefsValues = const {},
  int newEvents = 3,
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => _now),
      nearbyEventsRepositoryProvider.overrideWithValue(
        _repo(newEvents: newEvents),
      ),
      locationRepositoryProvider.overrideWithValue(FakeLocationRepository()),
    ],
  );
  addTearDown(c.dispose);
  return (c, prefs);
}

void main() {
  test('never seen: counts every public event, no location needed', () async {
    final (c, _) = await _make();
    expect(await c.read(exploreBadgeCountProvider.future), 4);
  });

  test('counts only events created after the last visit', () async {
    final (c, _) = await _make(
      prefsValues: {
        ExploreSeenAtController.key: _now
            .subtract(const Duration(hours: 2, minutes: 30))
            .toIso8601String(),
      },
    );
    expect(await c.read(exploreBadgeCountProvider.future), 2);
  });

  test('markSeen stores the time and clears the count', () async {
    final (c, prefs) = await _make();
    expect(await c.read(exploreBadgeCountProvider.future), 4);
    await c.read(exploreSeenAtProvider.notifier).markSeen();
    expect(
      prefs.getString(ExploreSeenAtController.key),
      _now.toIso8601String(),
    );
    expect(await c.read(exploreBadgeCountProvider.future), 0);
  });

  test('the count is capped at ten', () async {
    final (c, _) = await _make(newEvents: 14);
    expect(await c.read(exploreBadgeCountProvider.future), 10);
  });

  test('with an area chosen only that area is counted', () async {
    final (c, _) = await _make();
    // Hoàn Kiếm (Hanoi): the fake events are in Ho Chi Minh City.
    await c
        .read(locationControllerProvider.notifier)
        .chooseArea(builtInAreas[5]);
    expect(await c.read(exploreBadgeCountProvider.future), 0);
  });

  test(
    'tabBadgesProvider shows Explore only when there is something new',
    () async {
      final (c, _) = await _make();
      await c.read(exploreBadgeCountProvider.future);
      expect(c.read(tabBadgesProvider), {AppTab.explore: 4});
      await c.read(exploreSeenAtProvider.notifier).markSeen();
      await c.read(exploreBadgeCountProvider.future);
      expect(c.read(tabBadgesProvider), isEmpty);
    },
  );

  Future<SharedPreferences> pumpShell(
    WidgetTester tester,
    NearbyEventsRepository repo,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, UserRole.customer);
    final router = GoRouter(
      initialLocation: AppTab.home.path,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => TabShell(shell),
          branches: [
            for (final t in AppTab.values)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: t.path,
                    builder: (_, _) => Text('page-${t.name}'),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => _now),
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          nearbyEventsRepositoryProvider.overrideWithValue(repo),
          locationRepositoryProvider.overrideWithValue(
            FakeLocationRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  testWidgets('choosing the Explore tab clears the badge and stores the time', (
    tester,
  ) async {
    final prefs = await pumpShell(tester, _repo());
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Khám phá'));
    await tester.pumpAndSettle();
    expect(find.text('page-explore'), findsOneWidget);
    expect(find.text('4'), findsNothing);
    expect(
      prefs.getString(ExploreSeenAtController.key),
      _now.toIso8601String(),
    );
  });

  testWidgets('the badge is gone while the count reloads after a visit', (
    tester,
  ) async {
    final repo = _GatedRepo(_events());
    await pumpShell(tester, repo);
    expect(find.text('4'), findsOneWidget);

    repo.gate = Completer<void>();
    await tester.tap(find.text('Khám phá'));
    await tester.pump();
    await tester.pump();
    expect(find.text('4'), findsNothing);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('4'), findsNothing);
  });

  testWidgets('a failing count shows the shell without a badge', (
    tester,
  ) async {
    final repo = _repo()..failWith = StateError('boom');
    await pumpShell(tester, repo);
    expect(find.text('Khám phá'), findsOneWidget);
    expect(find.text('4'), findsNothing);
  });
}

/// Delays `countCreatedSince` until [gate] completes.
class _GatedRepo extends FakeNearbyEventsRepository {
  _GatedRepo(super.events);

  Completer<void>? gate;

  @override
  Future<int> countCreatedSince({
    List<String>? cells,
    DateTime? since,
    int cap = 10,
  }) async {
    await gate?.future;
    return super.countCreatedSince(cells: cells, since: since, cap: cap);
  }
}
