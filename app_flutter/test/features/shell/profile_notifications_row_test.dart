import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/features/shell/tab_shell.dart';

import '../../support/notifications_world.dart';
import '../../support/screen_host.dart';

Future<NotificationsWorld> _profile(
  WidgetTester tester,
  NotificationsWorld world, {
  double textScale = 1.0,
  double width = 390,
  Brightness brightness = Brightness.dark,
}) async {
  useNotificationsPhone(tester, width: width);
  await world.init();
  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  world.router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, _) => const ProfileTab()),
      GoRoute(path: '/notifications', builder: stub),
      GoRoute(path: '/settings', builder: stub),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(
      router: world.router,
      overrides: world.overrides,
      textScale: textScale,
      brightness: brightness,
    ),
  );
  await tester.pumpAndSettle();
  return world;
}

void main() {
  testWidgets('S09.01 row shows the newest title and opens /notifications', (
    tester,
  ) async {
    final seed = NotificationsWorld();
    await _profile(
      tester,
      NotificationsWorld(
        rows: [
          seed.note('old', title: 'Cũ hơn', minutesAgo: 90),
          seed.note('new', title: 'Minh Trí đã nhận lịch', minutesAgo: 3),
        ],
      ),
    );
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Minh Trí đã nhận lịch'), findsOneWidget);
    expect(find.text('Cũ hơn'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('notifications-count')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    final semantics = tester.getSemantics(
      find.byKey(const Key('open-notifications')),
    );
    expect(
      semantics.label,
      'Thông báo, 2 thông báo chưa đọc, Minh Trí đã nhận lịch',
    );
    await tester.tap(find.byKey(const Key('open-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('stub /notifications'), findsOneWidget);
  });

  testWidgets('S09.01 row is quiet when there is nothing', (tester) async {
    await _profile(tester, NotificationsWorld());
    expect(find.text('Chưa có thông báo nào'), findsOneWidget);
    expect(find.byKey(const Key('notifications-count')), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const Key('open-notifications'))).label,
      'Thông báo, Chưa có thông báo nào',
    );
  });

  testWidgets('S09.01 row re-fetches when the count changes, never listens', (
    tester,
  ) async {
    final seed = NotificationsWorld();
    final world = await _profile(
      tester,
      NotificationsWorld(rows: [seed.note('a', title: 'Một')]),
    );
    expect(find.text('Một'), findsOneWidget);
    expect(world.fake.listeners, 0, reason: 'no inbox listener on the tab');
    world.fake.add(world.note('b', title: 'Hai', minutesAgo: 1));
    await tester.pumpAndSettle();
    expect(find.text('Hai'), findsOneWidget);
    expect(find.text('Một'), findsNothing);
    expect(world.fake.listeners, 0);
  });

  for (final brightness in Brightness.values) {
    testWidgets('S09.01 row at 320 dp and 1.3× text (${brightness.name})', (
      tester,
    ) async {
      final seed = NotificationsWorld();
      await _profile(
        tester,
        NotificationsWorld(
          rows: [
            seed.note(
              'a',
              title: 'Minh Trí đã nhận lịch chụp chân dung ngoài trời ở Bến Bạch Đằng',
            ),
          ],
        ),
        textScale: 1.3,
        width: 320,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('open-notifications')), findsOneWidget);
    });
  }

  testWidgets('Hồ sơ tab shows 9+ for 12 unread and reads "12 thông báo chưa '
      'đọc"', (tester) async {
    useNotificationsPhone(tester);
    final seed = NotificationsWorld();
    final world = NotificationsWorld(
      rows: [for (var i = 0; i < 12; i++) seed.note('n$i', minutesAgo: 5 + i)],
    );
    await world.init();
    final handle = tester.ensureSemantics();
    final router = GoRouter(
      initialLocation: AppTab.home.path,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => TabShell(shell),
          branches: [
            for (final t in AppTab.values)
              StatefulShellBranch(
                routes: [
                  GoRoute(path: t.path, builder: (_, _) => Text(t.name)),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      screenRouterApp(router: router, overrides: world.overrides),
    );
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
    final badge = find.ancestor(
      of: find.text('9+'),
      matching: find.byType(TabBadge),
    );
    expect(badge, findsOneWidget);
    expect(tester.getSemantics(badge).value, contains('12 thông báo chưa đọc'));
    // Reading them clears the badge.
    await world.fake.markAllRead();
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsNothing);
    handle.dispose();
  });
}
