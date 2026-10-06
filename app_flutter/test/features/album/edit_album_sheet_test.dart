// test/features/album/edit_album_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';

import '../../support/content_fixtures.dart';
import '../../support/my_albums_world.dart';
import '../../support/screen_host.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<MyAlbumsWorld> _open(
  WidgetTester tester, {
  AlbumSummary? Function(MyAlbumsWorld w)? album,
  bool addPosts = true,
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
  void Function(MyAlbumsWorld w)? seed,
}) async {
  usePhone(tester, width: width, height: width < 390 ? 640 : 900);
  SheetHost.results.clear();
  final w = MyAlbumsWorld();
  await w.init();
  seed?.call(w);
  await tester.pumpWidget(
    screenApp(
      home: SheetHost.edit(album: album?.call(w), addPosts: addPosts),
      overrides: w.overrides,
      textScale: textScale,
      brightness: brightness,
    ),
  );
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
  return w;
}

AlbumSummary _existing(MyAlbumsWorld w) => fixtureAlbum(
  'al1',
  photographerId: w.uid,
  title: 'Hà Giang 2025',
  description: 'Mùa hoa tam giác mạch',
  postCount: 2,
  mediaCount: 3,
);

void _seedAlbum(MyAlbumsWorld w) {
  w.albums.add(_existing(w));
  w.posts
    ..add(
      fixturePost(
        'x1',
        photographerId: w.uid,
        albumId: 'al1',
        albumPosition: 1,
        images: 2,
      ),
    )
    ..add(
      fixturePost(
        'x2',
        photographerId: w.uid,
        albumId: 'al1',
        albumPosition: 2,
        age: const Duration(hours: 2),
      ),
    );
}

Future<void> _type(WidgetTester tester, String k, String text) async {
  await tester.enterText(_key(k), text);
  await tester.pump();
}

void main() {
  testWidgets('a new album asks for a name and shows n / 40', (tester) async {
    await _open(tester);
    expect(find.text('Album mới'), findsOneWidget);
    expect(find.text('0 / 40'), findsOneWidget);
    expect(find.text('0 / 300'), findsOneWidget);
    expect(find.text('Tạo và thêm bài'), findsOneWidget);
    expect(find.text('Tự động: ảnh đầu tiên của album'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: _key('album-edit-save'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    // The cover cannot be picked while the album is empty.
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: _key('album-edit-cover-pick'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await _type(tester, 'album-edit-title', 'Phố cổ');
    expect(find.text('6 / 40'), findsOneWidget);
    await _type(tester, 'album-edit-title', '');
    expect(find.text('Nhập tên album'), findsOneWidget);
  });

  testWidgets('duplicate title shows the error under the field', (
    tester,
  ) async {
    final w = await _open(tester);
    w.albums.failWith = const AlbumError('conflict');
    await _type(tester, 'album-edit-title', 'Phố cổ');
    await tester.tap(_key('album-edit-save'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã có album tên này'), findsOneWidget);
    expect(_key('album-edit-title'), findsOneWidget);
    expect(SheetHost.results, isEmpty);
    // Editing the name clears the error.
    await _type(tester, 'album-edit-title', 'Phố cổ 2');
    expect(find.text('Bạn đã có album tên này'), findsNothing);
  });

  testWidgets('creating opens the add-posts sheet for the new album', (
    tester,
  ) async {
    final w = await _open(
      tester,
      seed: (w) => w.posts.add(fixturePost('free1', photographerId: w.uid)),
    );
    await _type(tester, 'album-edit-title', '  Phố cổ  ');
    await tester.tap(_key('album-edit-save'));
    await tester.pumpAndSettle();
    expect(w.albums.calls, ['create:Phố cổ']);
    expect(find.text('Thêm bài vào album'), findsOneWidget);
    expect(find.text('Tên album · bắt buộc'), findsNothing);
    await tester.tap(_key('add-posts-close'));
    await tester.pumpAndSettle();
    expect(SheetHost.results.single, 'new1');
  });

  testWidgets('from the picker the new album returns without add-posts', (
    tester,
  ) async {
    final w = await _open(tester, addPosts: false);
    expect(find.text('Tạo'), findsOneWidget);
    await _type(tester, 'album-edit-title', 'Phố cổ');
    await tester.tap(_key('album-edit-save'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm bài vào album'), findsNothing);
    expect(SheetHost.results.single, 'new1');
    expect(w.albums.calls, ['create:Phố cổ']);
  });

  testWidgets('hitting the album limit says so', (tester) async {
    final w = await _open(tester);
    w.albums.failWith = const AlbumError('limit_exceeded');
    await _type(tester, 'album-edit-title', 'Phố cổ');
    await tester.tap(_key('album-edit-save'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã có đủ 30 album.'), findsOneWidget);
  });

  testWidgets('edit mode saves only what changed', (tester) async {
    final w = await _open(tester, seed: _seedAlbum, album: _existing);
    expect(find.text('Sửa album'), findsOneWidget);
    expect(find.text('Lưu'), findsOneWidget);
    expect(find.text('Xoá album'), findsOneWidget);
    expect(find.text('13 / 40'), findsOneWidget);
    // Nothing changed yet: Lưu is off.
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: _key('album-edit-save'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await _type(tester, 'album-edit-title', 'Hà Giang 2026');
    await tester.tap(_key('album-edit-save'));
    await tester.pumpAndSettle();
    expect(w.albums.calls, ['update:al1']);
    expect(SheetHost.results.single, 'al1');
    expect((await w.albums.album('al1'))!.title, 'Hà Giang 2026');
    expect((await w.albums.album('al1'))!.description, 'Mùa hoa tam giác mạch');
  });

  testWidgets('Chọn ảnh opens the album images and keeps the choice', (
    tester,
  ) async {
    final w = await _open(tester, seed: _seedAlbum, album: _existing);
    await tester.tap(_key('album-edit-cover-pick'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn ảnh bìa'), findsOneWidget);
    // x1 has two images, x2 one.
    expect(_key('cover-x1-0'), findsOneWidget);
    expect(_key('cover-x1-1'), findsOneWidget);
    expect(_key('cover-x2-0'), findsOneWidget);
    await tester.tap(_key('cover-x1-1'));
    await tester.pumpAndSettle();
    expect(find.text('Đã chọn một ảnh làm bìa'), findsOneWidget);
    await tester.tap(_key('album-edit-save'));
    await tester.pumpAndSettle();
    final saved = (await w.albums.album('al1'))!;
    expect((saved.coverPostId, saved.coverImageIndex), ('x1', 1));
  });

  testWidgets('deleting asks first and uses the red confirm', (tester) async {
    final w = await _open(tester, seed: _seedAlbum, album: _existing);
    await tester.tap(_key('album-edit-delete'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá album này?'), findsOneWidget);
    expect(
      find.text('Bài trong album không bị xoá, chuyển về Chưa xếp album.'),
      findsOneWidget,
    );
    expect(w.albums.calls, isEmpty);
    // The red button is the danger style, not the gradient primary.
    final confirm = find.widgetWithText(FilledButton, 'Xoá album');
    expect(confirm, findsOneWidget);
    final bg = tester
        .widget<FilledButton>(confirm)
        .style!
        .backgroundColor!
        .resolve({});
    expect(bg, AppColors.destructive);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(w.albums.calls, ['delete:al1']);
    expect(find.text('Sửa album'), findsNothing);
    expect(SheetHost.results.single, isNull);
  });

  testWidgets('closing with changes asks to discard', (tester) async {
    final w = await _open(tester);
    await _type(tester, 'album-edit-title', 'Phố cổ');
    await tester.tap(_key('album-edit-close'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);
    // Keep editing.
    await tester.tap(find.text('Tiếp tục sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsNothing);
    expect(_key('album-edit-title'), findsOneWidget);
    // Discard.
    await tester.tap(_key('album-edit-close'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bỏ'));
    await tester.pumpAndSettle();
    expect(_key('album-edit-title'), findsNothing);
    expect(SheetHost.results.single, isNull);
    expect(w.albums.calls, isEmpty);
  });

  testWidgets('dragging the sheet down keeps the edits', (tester) async {
    final w = await _open(tester);
    await _type(tester, 'album-edit-title', 'Phố cổ');
    await tester.drag(
      find.byKey(const Key('app-sheet-handle')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    expect(_key('album-edit-title'), findsOneWidget);
    expect(find.text('Phố cổ'), findsOneWidget);
    expect(w.albums.calls, isEmpty);
  });

  testWidgets('closing an untouched sheet does not ask', (tester) async {
    await _open(tester);
    await tester.tap(_key('album-edit-close'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsNothing);
    expect(_key('album-edit-title'), findsNothing);
  });

  testWidgets('tapping outside with changes asks to discard', (tester) async {
    await _open(tester);
    await _type(tester, 'album-edit-title', 'Phố cổ');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      await _open(
        tester,
        width: 320,
        textScale: 1.3,
        brightness: b,
        seed: _seedAlbum,
        album: _existing,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(_key('album-edit-cover-pick'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
