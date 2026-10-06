import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/badges/badge.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import '../../support/notifications_world.dart';
import '../../support/screen_host.dart';

Future<NotificationsWorld> _profile(
  WidgetTester tester, {
  List<String> earned = const [],
  double width = 390,
  double textScale = 1.0,
}) async {
  useNotificationsPhone(tester, width: width);
  final world = NotificationsWorld();
  await world.init();
  for (final id in earned) {
    world.badges.earn(
      world.uid,
      EarnedBadge(badgeId: id, awardedAt: DateTime.utc(2026, 9, 1)),
    );
  }
  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  world.router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, _) => const ProfileTab()),
      GoRoute(path: '/notifications', builder: stub),
      GoRoute(path: '/settings', builder: stub),
      GoRoute(path: '/u/:uid/badges', builder: stub),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(
      router: world.router,
      overrides: world.overrides,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
  return world;
}

void main() {
  testWidgets('S09.01 shows chips under the Thông báo row and Tất cả', (
    tester,
  ) async {
    final w = await _profile(
      tester,
      earned: ['top_rated', 'punctual', 'fast_reply', 'shoots_100'],
    );
    final row = find.byKey(const Key('profile-tab-badges'));
    expect(
      find.descendant(of: row, matching: find.byType(BadgeChip)),
      findsNWidgets(3),
    );
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('open-notifications'))).dy,
      ),
    );
    await tester.tap(find.descendant(of: row, matching: find.text('Tất cả')));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/${w.uid}/badges'), findsOneWidget);
  });

  testWidgets('S09.01 shows Tất cả alone when nothing is earned', (
    tester,
  ) async {
    final w = await _profile(tester);
    final row = find.byKey(const Key('profile-tab-badges'));
    expect(
      find.descendant(of: row, matching: find.byType(BadgeChip)),
      findsNothing,
    );
    await tester.tap(find.descendant(of: row, matching: find.text('Tất cả')));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/${w.uid}/badges'), findsOneWidget);
  });

  testWidgets('S09.01 badge row fits at 320 dp and 1.3x', (tester) async {
    await _profile(
      tester,
      earned: ['top_rated', 'punctual', 'fast_reply', 'shoots_100'],
      width: 320,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
