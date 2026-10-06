import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/content_fixtures.dart';
import '../../support/profile_world.dart';

Finder _key(String k) => find.byKey(Key(k));

/// Album `al1` of [owner] with three posts filed out of order: x1, x2, x3
/// by `albumPosition`; x3 has three images.
Future<ProfileWorld> _world(
  WidgetTester tester, {
  UserRole role = UserRole.customer,
  bool mine = false,
  double width = 390,
  bool withPosts = true,
}) async {
  usePhoneFor(tester, width: width, height: width < 390 ? 640 : 1400);
  final w = ProfileWorld(role: role);
  await w.init();
  final owner = mine ? w.uid : 'p1';
  if (mine) {
    w.profiles.add(
      PhotographerProfile(
        summary: fixturePhotographer(w.uid, name: 'Lan Anh'),
        intro: const PhotographerIntro(onboardingComplete: true),
      ),
    );
  }
  w.albums.add(
    fixtureAlbum(
      'al1',
      photographerId: owner,
      title: 'Tác phẩm đạt giải',
      description: 'Những khung hình đã đi thi.',
      postCount: 3,
      mediaCount: 5,
    ),
  );
  if (withPosts) {
    for (final (id, pos, images) in [
      ('x3', 3, 3),
      ('x1', 1, 1),
      ('x2', 2, 1),
    ]) {
      w.discovery.posts.add(
        fixturePost(
          id,
          photographerId: owner,
          albumId: 'al1',
          albumPosition: pos,
          images: images,
          caption: 'Bài $id',
        ),
      );
    }
  }
  return w;
}

void main() {
  testWidgets(
    'posts appear in album order, with a count on multi-image posts',
    (tester) async {
      final w = await _world(tester);
      await tester.pumpWidget(w.app('/u/p1/albums/al1'));
      await tester.pumpAndSettle();
      expect(find.text('Tác phẩm đạt giải'), findsOneWidget);
      expect(find.text('Những khung hình đã đi thi.'), findsOneWidget);
      expect(find.textContaining('3 bài · 5 ảnh'), findsOneWidget);
      expect(find.byKey(const Key('album-author')), findsOneWidget);
      final x1 = tester.getTopLeft(_key('album-post-x1'));
      final x2 = tester.getTopLeft(_key('album-post-x2'));
      final x3 = tester.getTopLeft(_key('album-post-x3'));
      // Two columns, filled in order: x1 | x2, then x3 under x1.
      expect(x1.dy, x2.dy);
      expect(x1.dx, lessThan(x2.dx));
      expect(x3.dx, x1.dx);
      expect(x3.dy, greaterThan(x1.dy));
      expect(_key('album-post-count-x3'), findsOneWidget);
      expect(tester.widget<Text>(_key('album-post-count-x3')).data, '3');
      expect(_key('album-post-count-x1'), findsNothing);
      await tester.tap(_key('album-post-x2'));
      await tester.pumpAndSettle();
      expect(find.text('stub /p/x2'), findsOneWidget);
    },
  );

  testWidgets('a long album pages by 24', (tester) async {
    final w = await _world(tester, withPosts: false);
    for (var i = 1; i <= 30; i++) {
      w.discovery.posts.add(
        fixturePost(
          'm$i',
          photographerId: 'p1',
          albumId: 'al1',
          albumPosition: i,
        ),
      );
    }
    await tester.pumpWidget(w.app('/u/p1/albums/al1'));
    await tester.pumpAndSettle();
    expect(_key('album-post-m24'), findsOneWidget);
    expect(_key('album-post-m25'), findsNothing);
    await tester.scrollUntilVisible(
      _key('album-more'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(_key('album-more'));
    await tester.pumpAndSettle();
    await tester.tap(_key('album-more'));
    await tester.pumpAndSettle();
    expect(_key('album-post-m30'), findsOneWidget);
    expect(_key('album-more'), findsNothing);
  });

  testWidgets('the bottom bar books this photographer', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1/albums/al1'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt lịch · từ 1,5M'), findsOneWidget);
    await tester.tap(_key('profile-book'));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/p1/book'), findsOneWidget);
  });

  testWidgets('a visitor sees no owner actions; share copies the link', (
    tester,
  ) async {
    final w = await _world(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(w.app('/u/p1/albums/al1'));
    await tester.pumpAndSettle();
    expect(_key('album-menu'), findsNothing);
    await tester.tap(_key('album-share'));
    await tester.pump();
    expect(copied, '/u/p1/albums/al1');
    expect(find.text('Đã sao chép liên kết album'), findsOneWidget);
  });

  testWidgets('an empty album shows its owner the add action', (tester) async {
    final w = await _world(
      tester,
      role: UserRole.photographer,
      mine: true,
      withPosts: false,
    );
    await tester.pumpWidget(w.app('/u/${w.uid}/albums/al1'));
    await tester.pumpAndSettle();
    expect(find.text('Album chưa có bài'), findsOneWidget);
    expect(_key('profile-book'), findsNothing);
    await tester.tap(find.text('Thêm bài'));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/albums'), findsOneWidget);
  });

  testWidgets('a missing album shows Album này không còn', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1/albums/nope'));
    await tester.pumpAndSettle();
    expect(find.text('Album này không còn'), findsOneWidget);
    expect(_key('profile-book'), findsNothing);
    expect(find.text('Xem hồ sơ'), findsOneWidget);
  });

  testWidgets('an empty album is gone for visitors', (tester) async {
    final w = await _world(tester, withPosts: false);
    w.albums.add(
      fixtureAlbum(
        'hidden',
        photographerId: 'p1',
        visible: false,
        postCount: 0,
      ),
    );
    await tester.pumpWidget(w.app('/u/p1/albums/hidden'));
    await tester.pumpAndSettle();
    expect(find.text('Album này không còn'), findsOneWidget);
  });

  testWidgets('arranging saves the new order and offers undo', (tester) async {
    final w = await _world(tester, role: UserRole.photographer, mine: true);
    await tester.pumpWidget(w.app('/u/${w.uid}/albums/al1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('album-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sắp xếp bài'));
    await tester.pumpAndSettle();
    expect(_key('album-arrange-list'), findsOneWidget);
    expect(find.text('Bài x1'), findsOneWidget);

    await tester.tap(find.byTooltip('Thao tác với mục này').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển xuống'));
    await tester.pumpAndSettle();
    expect(w.albums.calls, contains('reorderPosts:al1:x2,x1,x3'));
    expect(find.text('Đã đổi thứ tự'), findsOneWidget);

    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(w.albums.calls.last, 'reorderPosts:al1:x1,x2,x3');

    await tester.tap(_key('album-arrange-done'));
    await tester.pumpAndSettle();
    expect(_key('album-arrange-list'), findsNothing);
    expect(_key('album-post-x1'), findsOneWidget);
  });

  testWidgets('a failed save puts the order back and says so', (tester) async {
    final w = await _world(tester, role: UserRole.photographer, mine: true);
    await tester.pumpWidget(w.app('/u/${w.uid}/albums/al1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('album-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sắp xếp bài'));
    await tester.pumpAndSettle();
    w.albums.failWith = const AlbumError('unavailable');
    await tester.tap(find.byTooltip('Thao tác với mục này').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển xuống'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu được thứ tự'), findsOneWidget);
    final titles = tester
        .widgetList<Text>(find.textContaining('Bài x'))
        .map((t) => t.data)
        .toList();
    expect(titles, ['Bài x1', 'Bài x2', 'Bài x3']);
  });

  testWidgets('deleting asks first, in red, then leaves the album', (
    tester,
  ) async {
    final w = await _world(tester, role: UserRole.photographer, mine: true);
    await tester.pumpWidget(w.app('/u/${w.uid}/albums/al1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('album-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá album'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá album này?'), findsOneWidget);
    expect(w.albums.calls, isNot(contains('delete:al1')));
    await tester.tap(find.widgetWithText(FilledButton, 'Xoá album'));
    await tester.pumpAndSettle();
    expect(w.albums.calls, contains('delete:al1'));
    expect(w.router.state.uri.path, '/u/${w.uid}');
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      final w = await _world(tester, width: 320);
      await tester.pumpWidget(
        w.app('/u/p1/albums/al1', brightness: b, textScale: 1.3),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_key('album-post-x1'), findsOneWidget);
    });

    testWidgets('owner arranging fits 320dp at 1.3x text (${b.name})', (
      tester,
    ) async {
      final w = await _world(
        tester,
        width: 320,
        role: UserRole.photographer,
        mine: true,
      );
      await tester.pumpWidget(
        w.app('/u/${w.uid}/albums/al1', brightness: b, textScale: 1.3),
      );
      await tester.pumpAndSettle();
      await tester.tap(_key('album-menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sắp xếp bài'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_key('album-arrange-list'), findsOneWidget);
    });
  }
}
