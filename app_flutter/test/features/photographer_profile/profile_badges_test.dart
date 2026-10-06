import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/badges/badge.dart';

import '../../support/badges_world.dart';
import '../../support/profile_world.dart';

Future<ProfileWorld> _open(
  WidgetTester tester, {
  List<String> earned = const [],
}) async {
  usePhoneFor(tester);
  final w = ProfileWorld();
  await w.init();
  final at = DateTime.utc(2026, 9, 1);
  for (final id in earned) {
    w.badges.earn('p1', EarnedBadge(badgeId: id, awardedAt: at));
  }
  await tester.pumpWidget(w.app('/u/p1'));
  await tester.pumpAndSettle();
  return w;
}

void main() {
  testWidgets(
    'S03.01 shows up to 3 earned chips after the bio and Tất cả opens /u/:uid/badges',
    (tester) async {
      final w = await _open(
        tester,
        earned: ['top_rated', 'punctual', 'fast_reply', 'shoots_100'],
      );
      final row = find.byKey(const Key('profile-badges'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byType(BadgeChip)),
        findsNWidgets(3),
      );
      expect(
        find.descendant(of: row, matching: find.text('Được đánh giá cao')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('100+ buổi')),
        findsNothing,
      );
      // After the bio.
      expect(
        tester.getTopLeft(row).dy,
        greaterThan(tester.getTopLeft(find.text(profileBio)).dy),
      );
      await tester.tap(find.descendant(of: row, matching: find.text('Tất cả')));
      await tester.pumpAndSettle();
      expect(find.text('stub /u/p1/badges'), findsOneWidget);
      expect(w.router.state.uri.path, '/u/p1/badges');
    },
  );

  testWidgets('S03.01 hides the row when nothing is earned', (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('profile-badges')), findsNothing);
    expect(find.byType(BadgeChip), findsNothing);
    expect(find.text('Tất cả'), findsNothing);
  });

  testWidgets('S03.01 shows chips labelled with the short name', (
    tester,
  ) async {
    await _open(tester, earned: ['shoots_100']);
    expect(find.text('100+ buổi'), findsOneWidget);
    expect(badgeCatalogue().length, 12);
  });
}
