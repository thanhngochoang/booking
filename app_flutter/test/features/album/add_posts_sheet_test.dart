// test/features/album/add_posts_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/content/post_summary.dart';

import '../../support/content_fixtures.dart';
import '../../support/create_post_world.dart';
import '../../support/my_albums_world.dart';
import '../../support/screen_host.dart';

Finder _key(String k) => find.byKey(Key(k));

/// Fails the n-th and later `movePosts` calls.
class _FlakyAlbums extends OwnedFakeAlbumRepository {
  _FlakyAlbums(super.ownerUid, {required this.failFrom});
  final int failFrom;
  var _n = 0;

  @override
  Future<void> movePosts(String? albumId, List<String> postIds) async {
    if (++_n >= failFrom) {
      throw const AlbumError('unavailable');
    }
    return super.movePosts(albumId, postIds);
  }
}

Future<(MyAlbumsWorld, AlbumSummary)> _open(
  WidgetTester tester, {
  int albumPosts = 3,
  void Function(MyAlbumsWorld w)? seed,
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
  Object? flakyFrom,
}) async {
  usePhone(tester, width: width, height: width < 390 ? 700 : 900);
  SheetHost.results.clear();
  final w = MyAlbumsWorld();
  await w.init();
  if (flakyFrom is int) {
    w.albums = _FlakyAlbums(w.uid, failFrom: flakyFrom);
  }
  final target = fixtureAlbum(
    'dest',
    photographerId: w.uid,
    title: 'Đám cưới 2026',
    postCount: albumPosts,
  );
  w.albums.add(target);
  w.albums.add(
    fixtureAlbum(
      'old',
      photographerId: w.uid,
      title: 'Hà Giang 2025',
      position: 2,
    ),
  );
  seed?.call(w);
  await tester.pumpWidget(
    screenApp(
      home: SheetHost.addPosts(addTo: target),
      overrides: w.overrides,
      textScale: textScale,
      brightness: brightness,
    ),
  );
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
  return (w, target);
}

void _posts(MyAlbumsWorld w) {
  w.posts
    ..add(fixturePost('u1', photographerId: w.uid, caption: 'Bài u1'))
    ..add(
      fixturePost(
        'u2',
        photographerId: w.uid,
        caption: 'Bài u2',
        images: 4,
        age: const Duration(hours: 2),
      ),
    )
    ..add(
      fixturePost(
        'a1',
        photographerId: w.uid,
        caption: 'Bài a1',
        albumId: 'old',
        albumPosition: 1,
        age: const Duration(hours: 3),
      ),
    )
    ..add(
      fixturePost(
        'a2',
        photographerId: w.uid,
        caption: 'Bài a2',
        albumId: 'old',
        albumPosition: 2,
        age: const Duration(hours: 4),
      ),
    )
    ..add(
      fixturePost(
        'in',
        photographerId: w.uid,
        caption: 'Đã ở đây',
        albumId: 'dest',
        albumPosition: 1,
        age: const Duration(hours: 5),
      ),
    )
    ..add(
      fixturePost(
        'shoot',
        kind: PostKind.realShoot,
        photographerId: w.uid,
        age: const Duration(hours: 6),
      ),
    );
}

Future<void> _tapTile(WidgetTester tester, String id) async {
  await tester.ensureVisible(_key('post-pick-$id'));
  await tester.pump();
  await tester.tap(_key('post-pick-$id'));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_key('add-posts-submit'));
  await tester.tap(_key('add-posts-submit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unsorted tab lists only posts without an album', (tester) async {
    await _open(tester, seed: _posts);
    expect(find.text('Thêm bài vào album'), findsOneWidget);
    expect(find.text('0 đã chọn'), findsOneWidget);
    expect(find.text('Chưa xếp · 2'), findsOneWidget);
    // Posts of other albums, of this album and non-work posts are not counted
    // as unsorted; "Tất cả" leaves out what is already in this album.
    expect(find.text('Tất cả bài · 4'), findsOneWidget);
    expect(_key('post-pick-u1'), findsOneWidget);
    expect(_key('post-pick-u2'), findsOneWidget);
    expect(_key('post-pick-a1'), findsNothing);
    expect(_key('post-pick-in'), findsNothing);
    expect(_key('post-pick-shoot'), findsNothing);
    expect(find.text('4 ảnh'), findsOneWidget);

    await tester.tap(find.text('Tất cả bài · 4'));
    await tester.pumpAndSettle();
    expect(_key('post-pick-a1'), findsOneWidget);
    expect(find.text('Hà Giang 2025'), findsWidgets);
    expect(_key('post-pick-in'), findsNothing);
  });

  testWidgets('selecting a post from another album shows the move warning', (
    tester,
  ) async {
    await _open(tester, seed: _posts);
    await tester.tap(find.text('Tất cả bài · 4'));
    await tester.pumpAndSettle();
    expect(_key('add-posts-warn'), findsNothing);
    await _tapTile(tester, 'a1');
    expect(
      find.text('1 bài đang ở "Hà Giang 2025" sẽ chuyển sang album này.'),
      findsOneWidget,
    );
    await _tapTile(tester, 'u1');
    expect(find.text('2 đã chọn'), findsOneWidget);
    expect(find.textContaining('1 bài đang ở'), findsOneWidget);
    await _tapTile(tester, 'a1'); // deselect
    expect(_key('add-posts-warn'), findsNothing);
  });

  testWidgets('adding sends the posts in the order picked and closes', (
    tester,
  ) async {
    final (w, _) = await _open(tester, seed: _posts);
    expect(find.text('Chọn bài để thêm'), findsOneWidget);
    await _tapTile(tester, 'u2');
    await _tapTile(tester, 'u1');
    expect(find.text('Thêm 2 bài'), findsOneWidget);
    await _submit(tester);
    expect(w.albums.moves.length, 1);
    expect(w.albums.moves.single.$1, 'dest');
    expect(w.albums.moves.single.$2, ['u2', 'u1']);
    expect(SheetHost.results.single, 2);
    expect(_key('add-posts-submit'), findsNothing);
  });

  testWidgets('more than 50 selected are sent in ordered batches', (
    tester,
  ) async {
    final (w, _) = await _open(
      tester,
      albumPosts: 0,
      seed: (w) {
        for (var i = 1; i <= 55; i++) {
          w.posts.add(
            fixturePost(
              'p${i.toString().padLeft(2, '0')}',
              photographerId: w.uid,
              age: Duration(minutes: i),
            ),
          );
        }
      },
    );
    // Pages of 30: the rest comes with "Xem thêm bài".
    expect(find.text('Chưa xếp · 30+'), findsOneWidget);
    final ids = [
      for (var i = 1; i <= 55; i++) 'p${i.toString().padLeft(2, '0')}',
    ];
    for (final id in ids.take(30)) {
      await _tapTile(tester, id);
    }
    await tester.ensureVisible(_key('add-posts-more'));
    await tester.tap(_key('add-posts-more'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa xếp · 55'), findsOneWidget);
    for (final id in ids.skip(30)) {
      await _tapTile(tester, id);
    }
    expect(find.text('55 đã chọn'), findsOneWidget);
    await _submit(tester);
    expect(w.albums.moves.length, 2);
    expect(w.albums.moves[0].$1, 'dest');
    expect(w.albums.moves[0].$2, ids.take(50).toList());
    expect(w.albums.moves[1].$2, ids.skip(50).toList());
    expect(SheetHost.results.single, 55);
  });

  testWidgets('a failing later batch keeps the rest selected and says so', (
    tester,
  ) async {
    final (w, _) = await _open(
      tester,
      albumPosts: 148,
      flakyFrom: 2,
      seed: (w) {
        for (var i = 1; i <= 52; i++) {
          w.posts.add(
            fixturePost(
              'p${i.toString().padLeft(2, '0')}',
              photographerId: w.uid,
              age: Duration(minutes: i),
            ),
          );
        }
      },
    );
    final ids = [
      for (var i = 1; i <= 52; i++) 'p${i.toString().padLeft(2, '0')}',
    ];
    for (final id in ids.take(30)) {
      await _tapTile(tester, id);
    }
    await tester.ensureVisible(_key('add-posts-more'));
    await tester.tap(_key('add-posts-more'));
    await tester.pumpAndSettle();
    for (final id in ids.skip(30)) {
      await _tapTile(tester, id);
    }
    await _submit(tester);
    expect(w.albums.moves.length, 1);
    expect(
      find.text('Đã thêm 50 bài, còn 2 bài chưa thêm được.'),
      findsOneWidget,
    );
    expect(find.text('2 đã chọn'), findsOneWidget);
    // Room is recomputed from what landed: 148 + 50 leaves 2.
    expect(find.text('Album đã đủ 200 bài'), findsOneWidget);
    await tester.tap(_key('add-posts-close'));
    await tester.pumpAndSettle();
    expect(SheetHost.results.single, 50);
  });

  testWidgets('a failed add shows an error and keeps the selection', (
    tester,
  ) async {
    final (w, _) = await _open(tester, seed: _posts);
    await _tapTile(tester, 'u1');
    w.albums.failWith = const AlbumError('unavailable');
    await _submit(tester);
    expect(find.text('Chưa thêm được bài. Thử lại sau.'), findsOneWidget);
    expect(find.text('1 đã chọn'), findsOneWidget);
    expect(SheetHost.results, isEmpty);
  });

  testWidgets('at 200 posts the other tiles are disabled', (tester) async {
    final (w, _) = await _open(tester, albumPosts: 199, seed: _posts);
    expect(_key('add-posts-full'), findsNothing);
    await _tapTile(tester, 'u1');
    expect(find.text('Album đã đủ 200 bài'), findsOneWidget);
    await _tapTile(tester, 'u2'); // disabled
    expect(find.text('1 đã chọn'), findsOneWidget);
    await _submit(tester);
    expect(w.albums.moves.single.$2, ['u1']);
  });

  testWidgets('a full album selects nothing', (tester) async {
    await _open(tester, albumPosts: 200, seed: _posts);
    expect(find.text('Album đã đủ 200 bài'), findsOneWidget);
    await _tapTile(tester, 'u1');
    expect(find.text('0 đã chọn'), findsOneWidget);
  });

  testWidgets('without posts it asks to post first and opens S10.01', (
    tester,
  ) async {
    usePhone(tester);
    final w = MyAlbumsWorld();
    await w.init();
    final target = fixtureAlbum('dest', photographerId: w.uid, postCount: 0);
    w.albums.add(target);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => SheetHost.addPosts(addTo: target),
        ),
        GoRoute(path: '/action', builder: (_, _) => const Text('stub /action')),
      ],
    );
    await tester.pumpWidget(
      screenRouterApp(router: router, overrides: w.overrides),
    );
    await tester.tap(_key('open'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng bài trước'), findsOneWidget);
    expect(_key('add-posts-submit'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng bài'));
    await tester.pumpAndSettle();
    expect(find.text('stub /action'), findsOneWidget);
  });

  testWidgets('no empty text or 0+ while unsorted posts may still follow', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (w) {
        for (var i = 0; i < 100; i++) {
          w.posts.add(
            fixturePost(
              'p$i',
              photographerId: w.uid,
              albumId: 'old',
              albumPosition: i + 1,
              age: Duration(minutes: i),
            ),
          );
        }
      },
    );
    expect(find.text('Mọi bài của bạn đã nằm trong album.'), findsNothing);
    expect(find.text('Chưa xếp · 0+'), findsNothing);
    expect(find.text('Chưa xếp · …'), findsOneWidget);
    expect(_key('add-posts-more'), findsOneWidget);
  });

  testWidgets('everything already sorted says so on the unsorted tab', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (w) => w.posts.add(
        fixturePost(
          'a1',
          photographerId: w.uid,
          albumId: 'old',
          albumPosition: 1,
        ),
      ),
    );
    expect(find.text('Chưa xếp · 0'), findsOneWidget);
    expect(find.text('Mọi bài của bạn đã nằm trong album.'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      await _open(
        tester,
        width: 320,
        textScale: 1.3,
        brightness: b,
        seed: _posts,
      );
      await tester.tap(find.textContaining('Tất cả bài'));
      await tester.pumpAndSettle();
      await _tapTile(tester, 'a1');
      expect(tester.takeException(), isNull);
      expect(_key('add-posts-warn'), findsOneWidget);
    });
  }
}
