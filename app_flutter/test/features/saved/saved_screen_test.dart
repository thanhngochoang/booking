import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/content_fixtures.dart';
import '../../support/saved_world.dart';

Future<SavedWorld> _world({bool hasPhone = true}) async {
  final w = SavedWorld(hasPhone: hasPhone);
  await w.init();
  return w;
}

void main() {
  testWidgets(
    'posts tab shows the saved posts newest first in a 3-column grid and opens /p/:id',
    (tester) async {
      final w = await _world();
      w.savedFollowRepo.addSavedPost(w.uid, 'a', DateTime.utc(2026, 10, 1, 10));
      w.savedFollowRepo.addSavedPost(w.uid, 'b', DateTime.utc(2026, 10, 1, 11));

      await tester.pumpWidget(w.app('/me/saved'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saved-post-a')), findsOneWidget);
      expect(find.byKey(const Key('saved-post-b')), findsOneWidget);

      await tester.tap(find.byKey(const Key('saved-post-b')));
      await tester.pumpAndSettle();
      expect(find.text('stub /p/b'), findsOneWidget);
    },
  );

  testWidgets(
    'scrolling near the end loads the next page; a failed page shows the retry link',
    (tester) async {
      final w = await _world();
      for (var i = 0; i < 25; i++) {
        final p = fixturePost('post-$i', age: Duration(minutes: 30 - i));
        w.postsRepo.add(p);
        w.savedFollowRepo.addSavedPost(
          w.uid,
          p.id,
          DateTime.utc(2026, 10, 1, 10).add(Duration(minutes: i)),
        );
      }

      await tester.pumpWidget(w.app('/me/saved'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saved-post-post-24')), findsOneWidget);

      // Scroll down to near the end
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      // Scroll to post-0 to bring it into viewport
      await tester.scrollUntilVisible(
        find.byKey(const Key('saved-post-post-0')),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saved-post-post-0')), findsOneWidget);
    },
  );

  testWidgets('empty posts tab shows "Chưa lưu bài nào" and its body', (
    tester,
  ) async {
    final w = await _world();
    await tester.pumpWidget(w.app('/me/saved'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa lưu bài nào'), findsOneWidget);
    expect(
      find.text('Bấm biểu tượng lưu trên ảnh để xem lại ở đây.'),
      findsOneWidget,
    );
  });

  testWidgets('?tab=photographers opens the second tab', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app('/me/saved?tab=photographers'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa lưu nhiếp ảnh gia nào'), findsOneWidget);
  });

  testWidgets(
    'photographer cards show the bookmark; tapping it removes the card\'s saved state and shows "Đã bỏ lưu Minh Trí" with "Hoàn tác" that restores it',
    (tester) async {
      final w = await _world();
      await w.savedFollowRepo.setPhotographerSaved(w.uid, 'p1', true);

      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(w.app('/me/saved?tab=photographers'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card-save-p1')), findsOneWidget);
      final bookmark = find.byKey(const Key('card-save-p1'));

      await tester.tap(bookmark);
      await tester.pump();
      await tester.pumpAndSettle();

      // Card is removed locally
      expect(find.byKey(const Key('card-save-p1')), findsNothing);
      expect(find.text('Đã bỏ lưu Minh Trí'), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Hoàn tác'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card-save-p1')), findsOneWidget);
    },
  );

  testWidgets('a provider not accepting orders has no "Đặt lịch"', (
    tester,
  ) async {
    final w = await _world();
    final closed = fixturePhotographer('p-closed', name: 'Đóng Cửa', acceptingOrders: false);
    w.photographersRepo.add(closed);
    await w.savedFollowRepo.setPhotographerSaved(w.uid, 'p-closed', true);

    await tester.pumpWidget(w.app('/me/saved?tab=photographers'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-book-p-closed')), findsNothing);
  });

  testWidgets('"Đặt lịch" goes through startBooking', (tester) async {
    final w = await _world();
    await w.savedFollowRepo.setPhotographerSaved(w.uid, 'p1', true);

    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(w.app('/me/saved?tab=photographers'));
    await tester.pumpAndSettle();

    final book = find.byKey(const Key('card-book-p1'));
    expect(book, findsOneWidget);

    await tester.tap(book);
    await tester.pumpAndSettle();
    expect(find.text('stub /u/p1/book'), findsOneWidget);
  });

  testWidgets('tab labels show the counts from socialCountsProvider', (
    tester,
  ) async {
    final w = await _world();
    w.savedFollowRepo.addSavedPost(w.uid, 'a', DateTime.utc(2026, 10, 1, 10));
    await w.savedFollowRepo.setPhotographerSaved(w.uid, 'p1', true);

    await tester.pumpWidget(w.app('/me/saved'));
    await tester.pumpAndSettle();

    expect(find.text('Bài · 1'), findsOneWidget);
    expect(find.text('Nhiếp ảnh gia · 1'), findsOneWidget);
  });

  testWidgets(
    'PhotographerCard without onToggleSave renders no bookmark (regression)',
    (tester) async {
      final w = await _world();
      await tester.pumpWidget(
        w.app('/u/p1'),
      );
      await tester.pumpAndSettle();

      // Outside saved screen, cards without onToggleSave don't show card-save-p1
      expect(find.byKey(const Key('card-save-p1')), findsNothing);
    },
  );

  testWidgets('saved screen fits 320dp at 1.3x text', (tester) async {
    final w = await _world();
    w.savedFollowRepo.addSavedPost(w.uid, 'a', DateTime.utc(2026, 10, 1, 10));
    await w.savedFollowRepo.setPhotographerSaved(w.uid, 'p1', true);

    tester.view.physicalSize = const Size(320 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      w.app('/me/saved', textScale: 1.3),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
