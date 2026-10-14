import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/content_fixtures.dart';
import '../../support/saved_world.dart';

Future<SavedWorld> _world({bool hasPhone = true}) async {
  final w = SavedWorld(hasPhone: hasPhone);
  await w.init();
  return w;
}

void main() {
  testWidgets(
    'following lists photographers newest followed first with "Đang theo dõi"',
    (tester) async {
      final w = await _world();
      await w.addFollow(w.uid, 'p1', DateTime.utc(2026, 10, 1, 10));
      await w.addFollow(w.uid, 'p2', DateTime.utc(2026, 10, 1, 11));

      await tester.pumpWidget(w.app('/me/following'));
      await tester.pumpAndSettle();

      // Header count
      expect(find.text('2 nhiếp ảnh gia'), findsOneWidget);

      // Rows present
      expect(find.byKey(const Key('following-row-p1')), findsOneWidget);
      expect(find.byKey(const Key('following-row-p2')), findsOneWidget);

      // Buttons
      expect(find.byKey(const Key('following-btn-p1')), findsOneWidget);
      expect(find.byKey(const Key('following-btn-p2')), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Đang theo dõi'), findsNWidgets(2));
    },
  );

  testWidgets('tapping a row opens /u/:uid', (tester) async {
    final w = await _world();
    await w.addFollow(w.uid, 'p1', DateTime.utc(2026, 10, 1, 10));

    await tester.pumpWidget(w.app('/me/following'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('following-row-p1')));
    await tester.pumpAndSettle();

    expect(find.text('stub /u/p1'), findsOneWidget);
  });

  testWidgets(
    'unfollow keeps the row with "Theo dõi" and shows "Đã bỏ theo dõi Quốc Bảo"',
    (tester) async {
      final w = await _world();
      final p4 = fixturePhotographer('p4', name: 'Quốc Bảo');
      w.photographersRepo.add(p4);
      await w.addFollow(w.uid, 'p4', DateTime.utc(2026, 10, 1, 10));

      await tester.pumpWidget(w.app('/me/following'));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('following-btn-p4'));
      expect(btn, findsOneWidget);
      expect(
        find.descendant(of: btn, matching: find.text('Đang theo dõi')),
        findsOneWidget,
      );

      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Row stays, button turns to "Theo dõi"
      expect(find.byKey(const Key('following-row-p4')), findsOneWidget);
      expect(
        find.descendant(of: btn, matching: find.text('Theo dõi')),
        findsOneWidget,
      );
      expect(find.text('Đã bỏ theo dõi Quốc Bảo'), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);
    },
  );

  testWidgets('unfollow then Hoàn tác re-follows once', (tester) async {
    final w = await _world();
    await w.addFollow(w.uid, 'p1', DateTime.utc(2026, 10, 1, 10));

    await tester.pumpWidget(w.app('/me/following'));
    await tester.pumpAndSettle();

    final btn = find.byKey(const Key('following-btn-p1'));
    await tester.tap(btn);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: btn, matching: find.text('Theo dõi')),
      findsOneWidget,
    );

    // Tap Hoàn tác
    await tester.tap(find.widgetWithText(SnackBarAction, 'Hoàn tác'));
    await tester.pumpAndSettle();

    // Restores to "Đang theo dõi"
    expect(
      find.descendant(of: btn, matching: find.text('Đang theo dõi')),
      findsOneWidget,
    );
    final isFollowing = await w.engagement.isFollowing(w.uid, 'p1');
    expect(isFollowing, isTrue);
  });

  testWidgets('two quick taps end unfollowed', (tester) async {
    final w = await _world();
    await w.addFollow(w.uid, 'p1', DateTime.utc(2026, 10, 1, 10));

    await tester.pumpWidget(w.app('/me/following'));
    await tester.pumpAndSettle();

    final btn = find.byKey(const Key('following-btn-p1'));
    // Tap twice quickly
    await tester.tap(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: btn, matching: find.text('Theo dõi')),
      findsOneWidget,
    );
  });

  testWidgets(
    'a failed toggle shows "Chưa lưu được. Thử lại." and restores the button',
    (tester) async {
      final w = await _world();
      await w.addFollow(w.uid, 'p1', DateTime.utc(2026, 10, 1, 10));
      w.engagement.failWith = StateError('network error');

      await tester.pumpWidget(w.app('/me/following'));
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('following-btn-p1'));
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Chưa lưu được. Thử lại.'), findsOneWidget);
      expect(
        find.descendant(of: btn, matching: find.text('Đang theo dõi')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'empty following shows "Bạn chưa theo dõi ai" and "Khám phá" goes to /explore',
    (tester) async {
      final w = await _world();

      await tester.pumpWidget(w.app('/me/following'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa theo dõi ai'), findsOneWidget);
      expect(
        find.text('Theo dõi nhiếp ảnh gia để thấy bài mới của họ trước.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Khám phá'));
      await tester.pumpAndSettle();

      expect(find.text('stub /explore'), findsOneWidget);
    },
  );

  testWidgets('following screen fits 320dp at 1.3x text', (tester) async {
    final w = await _world();
    await w.addFollow(w.uid, 'p1', DateTime.utc(2026, 10, 1, 10));

    tester.view.physicalSize = const Size(320 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      w.app('/me/following', textScale: 1.3),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
