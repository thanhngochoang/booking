// test/features/album/my_albums_screen_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';

import '../../support/content_fixtures.dart';
import '../../support/my_albums_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<MyAlbumsWorld> _world(
  WidgetTester tester, {
  int albums = 3,
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  usePhone(tester, width: width);
  final w = MyAlbumsWorld();
  await w.init();
  // Added out of order on purpose: the list follows `position`.
  for (final i in [for (var n = albums; n >= 1; n--) n]) {
    w.albums.add(
      fixtureAlbum(
        'al$i',
        photographerId: w.uid,
        title: 'Album $i',
        position: i,
        postCount: i == 3 ? 0 : i * 3,
        mediaCount: i * 4,
        visible: i != 3,
      ),
    );
  }
  w.posts
    ..add(fixturePost('free1', photographerId: w.uid))
    ..add(
      fixturePost(
        'free2',
        photographerId: w.uid,
        age: const Duration(hours: 2),
      ),
    )
    ..add(
      fixturePost(
        'inalb',
        photographerId: w.uid,
        albumId: 'al1',
        albumPosition: 1,
        age: const Duration(hours: 3),
      ),
    );
  await tester.pumpWidget(w.app(brightness: brightness, textScale: textScale));
  await tester.pumpAndSettle();
  return w;
}

List<String> _titles(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.textContaining('Album ')))
    if (RegExp(r'^Album \d+$').hasMatch(t.data ?? '')) t.data!,
];

/// Long-presses the handle of row [row] and drags it by [dy].
Future<void> _drag(WidgetTester tester, int row, double dy) async {
  final handle = find.byKey(ReorderableRow.handleKey).at(row);
  final g = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  for (var i = 0; i < 6; i++) {
    await g.moveBy(Offset(0, dy / 6));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('albums list in position order, with counts and notes', (
    tester,
  ) async {
    await _world(tester);
    expect(find.text('Album của tôi'), findsWidgets);
    expect(_titles(tester), ['Album 1', 'Album 2', 'Album 3']);
    expect(find.text('3 bài · 4 ảnh · hiện rộng'), findsOneWidget);
    expect(find.text('6 bài · 8 ảnh'), findsOneWidget);
    expect(find.text('Trống · chưa hiện công khai'), findsOneWidget);
    expect(find.textContaining('Giữ ≡ rồi kéo'), findsOneWidget);
    // Fixed last row: the two posts that are in no album.
    expect(find.text('Chưa xếp album'), findsOneWidget);
    expect(find.text('2 bài · chỉ ở Dòng thời gian'), findsOneWidget);
    expect(find.text('Album mới'), findsOneWidget);
  });

  testWidgets('drop saves the new order and undo restores it', (tester) async {
    final w = await _world(tester);
    await _drag(tester, 0, 75);
    expect(w.albums.calls.where((c) => c.startsWith('reorder')), [
      'reorder:al2,al1,al3',
    ]);
    expect(_titles(tester), ['Album 2', 'Album 1', 'Album 3']);
    expect(find.text('Đã đổi thứ tự'), findsOneWidget);

    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(w.albums.calls.last, 'reorder:al1,al2,al3');
    expect(_titles(tester), ['Album 1', 'Album 2', 'Album 3']);
  });

  testWidgets('move up saves the new order', (tester) async {
    final w = await _world(tester);
    await tester.tap(find.byTooltip('Thao tác với mục này').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển lên'));
    await tester.pumpAndSettle();
    expect(w.albums.calls, contains('reorder:al2,al1,al3'));
    expect(_titles(tester), ['Album 2', 'Album 1', 'Album 3']);
  });

  testWidgets('a failed save puts the old order back and says so', (
    tester,
  ) async {
    final w = await _world(tester);
    w.albums.failWith = const AlbumError('unavailable');
    await tester.tap(find.byTooltip('Thao tác với mục này').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xuống cuối'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu được thứ tự'), findsOneWidget);
    expect(_titles(tester), ['Album 1', 'Album 2', 'Album 3']);
  });

  testWidgets('the unsorted row opens the picker, then the posts', (
    tester,
  ) async {
    await _world(tester);
    await tester.tap(_key('my-albums-unsorted'));
    await tester.pumpAndSettle();
    expect(find.text('Xếp vào album'), findsOneWidget);
    // An album is required here: no "Không xếp album" choice.
    expect(_key('album-pick-none'), findsNothing);
    await tester.tap(_key('album-pick-al2'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm bài vào album'), findsOneWidget);
    expect(_key('post-pick-free1'), findsOneWidget);
    expect(_key('post-pick-free2'), findsOneWidget);
    expect(_key('post-pick-inalb'), findsNothing);
  });

  testWidgets('the 30th album disables + with a reason', (tester) async {
    final w = await _world(tester, albums: 29);
    expect(
      tester.widget<IconButton>(_key('my-albums-add')).onPressed,
      isNotNull,
    );
    w.albums.add(
      fixtureAlbum(
        'al30',
        photographerId: w.uid,
        title: 'Album 30',
        position: 30,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(_key('my-albums-add')).onPressed, isNull);
    expect(find.byTooltip('Bạn đã có đủ 30 album.'), findsOneWidget);
    expect(_key('my-albums-limit'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: _key('my-albums-new'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('no albums shows the empty state with the primary action', (
    tester,
  ) async {
    final w = await _world(tester, albums: 0);
    expect(
      find.text('Gom bài thành album để khách xem theo bộ'),
      findsOneWidget,
    );
    expect(_key('my-albums-new'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Album mới'));
    await tester.pumpAndSettle();
    expect(find.text('Tên album · bắt buộc'), findsOneWidget);
    expect(w.albums.calls, isEmpty);
  });

  testWidgets('the + button and the row menu open the edit sheet', (
    tester,
  ) async {
    await _world(tester);
    await tester.tap(_key('my-albums-add'));
    await tester.pumpAndSettle();
    expect(find.text('Album mới'), findsWidgets);
    expect(_key('album-edit-title'), findsOneWidget);
    await tester.tap(_key('album-edit-close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Thao tác với mục này').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa album'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('album-edit-title')).controller!.text,
      'Album 2',
    );
  });

  testWidgets('deleting from the row menu asks first, in red', (tester) async {
    final w = await _world(tester);
    await tester.tap(find.byTooltip('Thao tác với mục này').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá album'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá album này?'), findsOneWidget);
    expect(w.albums.calls, isNot(contains('delete:al3')));
    await tester.tap(find.widgetWithText(FilledButton, 'Xoá album'));
    await tester.pumpAndSettle();
    expect(w.albums.calls, contains('delete:al3'));
    expect(_titles(tester), ['Album 1', 'Album 2']);
  });

  testWidgets('tapping a row opens the album', (tester) async {
    final w = await _world(tester);
    await tester.tap(find.text('Album 2'));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/${w.uid}/albums/al2'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      await _world(tester, width: 320, textScale: 1.3, brightness: b);
      expect(tester.takeException(), isNull);
      expect(find.text('Chưa xếp album'), findsOneWidget);
    });
  }
}
