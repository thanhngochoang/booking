import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/badges/badge.dart';
import 'package:photobooking/data/badges/badge_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/badges_world.dart';

void _phone(WidgetTester tester, {double width = 390, double height = 1600}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<BadgesWorld> _open(
  WidgetTester tester, {
  BadgesWorld? world,
  String? location,
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
  Map<String, Object> prefs = const {},
}) async {
  _phone(tester, width: width);
  final w = world ?? BadgesWorld();
  await w.init(prefsValues: prefs);
  await tester.pumpWidget(
    w.app(location: location, textScale: textScale, brightness: brightness),
  );
  await tester.pumpAndSettle();
  return w;
}

void main() {
  testWidgets("header reads '5 / 12' and sections '2 / 3', '3 / 9'", (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Huy hiệu'), findsOneWidget);
    expect(find.byKey(const Key('badges-meta')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('badges-meta'))).data,
      '5 / 12',
    );
    expect(find.text('Từ đánh giá'), findsOneWidget);
    expect(find.text('Từ hệ thống'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('3 / 9'), findsOneWidget);
    expect(find.text('97% cà chua từ 58 đánh giá'), findsOneWidget);
    expect(find.text('Hoàn thành 112 buổi'), findsOneWidget);
    expect(find.byType(ScreenCode), findsWidgets);
  });

  testWidgets('locked tile shows 3 / 5', (tester) async {
    await _open(tester);
    expect(find.text('Nhận xét chi tiết'), findsOneWidget);
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('Chưa đạt'), findsWidgets);
  });

  testWidgets('the Mới dot shows now and is gone on the next visit', (
    tester,
  ) async {
    final world = await _open(tester, prefs: {'badgesSeenAt:placeholder': 0});
    // Nothing stored for this uid: every earned badge is new on the first visit.
    expect(find.text('Mới'), findsNWidgets(5));
    final stored = world.sharedPrefs.getInt('badgesSeenAt:${world.uid}');
    expect(stored, badgesNow.millisecondsSinceEpoch);
    // Next visit: seenAt is after every award.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    expect(find.text('Mới'), findsNothing);
  });

  testWidgets("others with no badges see 'Chưa có huy hiệu nào'", (
    tester,
  ) async {
    await _open(tester, location: '/u/nobody/badges');
    expect(find.text('Chưa có huy hiệu nào'), findsOneWidget);
    expect(find.byKey(const Key('badges-meta')), findsNothing);
  });

  testWidgets('others see earned badges only, without counts or Mới', (
    tester,
  ) async {
    await _open(tester, location: '/u/${BadgesWorld.otherUid}/badges');
    expect(find.text('Được đánh giá cao'), findsOneWidget);
    expect(find.text('96% cà chua từ 30 đánh giá'), findsOneWidget);
    expect(find.text('Nhận xét chi tiết'), findsNothing);
    expect(find.text('Chưa đạt'), findsNothing);
    expect(find.byKey(const Key('badges-meta')), findsNothing);
    expect(find.text('Mới'), findsNothing);
    expect(find.textContaining(' / '), findsNothing);
  });

  testWidgets('own view with nothing earned shows the nearest card', (
    tester,
  ) async {
    final world = BadgesWorld(role: UserRole.customer);
    await world.init();
    world.repo = FakeBadgeRepository(
      catalog: badgeCatalogue(),
      progress: {
        world.uid: const {
          'loyal_customer': BadgeProgressEntry(current: 2, target: 3),
          'sharer': BadgeProgressEntry(current: 1, target: 5),
        },
      },
    );
    _phone(tester);
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('badges-nearest'))).data,
      'Gần đạt nhất: Khách thân thiết · 2 / 3',
    );
  });

  testWidgets('tile tap shows the earned date', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Được đánh giá cao'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('badge-sheet')), findsOneWidget);
    expect(find.text('Đạt ngày 1/9/2026'), findsOneWidget);
    expect(find.text('Từ 95% cà chua với ít nhất 20 đánh giá'), findsOneWidget);
  });

  testWidgets('tile tap on a locked badge shows the progress line', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Hồ sơ đầy đủ'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('badge-sheet')),
        matching: find.text('4 / 6'),
      ),
      findsWidgets,
    );
  });

  testWidgets('no Verified tick on this screen', (tester) async {
    await _open(tester);
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == AppIcons.verified),
      findsNothing,
    );
  });

  testWidgets('skeleton while loading', (tester) async {
    final world = BadgesWorld(repository: HangingBadgeRepository());
    _phone(tester);
    await world.init();
    await tester.pumpWidget(world.app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('badge_tile_skeleton')), findsNWidgets(8));
  });

  for (final dark in [true, false]) {
    testWidgets(
      '320 dp and 1.3x without overflow (${dark ? 'dark' : 'light'})',
      (tester) async {
        await _open(
          tester,
          width: 320,
          textScale: 1.3,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Huy hiệu'), findsOneWidget);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
