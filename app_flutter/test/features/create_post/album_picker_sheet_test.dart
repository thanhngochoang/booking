// test/features/create_post/album_picker_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/features/create_post/album_picker_sheet.dart';

import '../../support/create_post_world.dart';
import '../../support/screen_host.dart';

/// Opens the picker from a button and records what it returns.
class _Host extends StatelessWidget {
  const _Host({required this.selected, required this.results});
  final String? selected;
  final List<AlbumPick?> results;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const Key('open'),
        onPressed: () async =>
            results.add(await showAlbumPicker(context, selected: selected)),
        child: const Text('mở'),
      ),
    ),
  );
}

Future<(CreatePostWorld, List<AlbumPick?>)> _open(
  WidgetTester tester, {
  String? selected,
  bool albums = true,
}) async {
  final w = CreatePostWorld();
  await w.init();
  if (albums) {
    w.addAlbum('al1', title: 'Hà Giang 2025', postCount: 7);
    w.addAlbum('al2', title: 'Mùa lúa', postCount: 10, position: 2);
  }
  final results = <AlbumPick?>[];
  await tester.pumpWidget(
    screenApp(
      home: _Host(selected: selected, results: results),
      overrides: w.overrides,
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return (w, results);
}

void main() {
  testWidgets('lists "Không xếp album" first, then the albums with counts', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(ScreenCode), findsWidgets);
    expect(find.text('Xếp vào album'), findsOneWidget);
    final none = tester.getTopLeft(find.byKey(const Key('album-pick-none')));
    final first = tester.getTopLeft(find.byKey(const Key('album-pick-al1')));
    final second = tester.getTopLeft(find.byKey(const Key('album-pick-al2')));
    expect(none.dy, lessThan(first.dy));
    expect(first.dy, lessThan(second.dy));
    expect(find.text('7 bài'), findsOneWidget);
    expect(find.text('10 bài'), findsOneWidget);
    expect(find.text('Album mới'), findsOneWidget);
  });

  testWidgets('the current choice is the selected radio', (tester) async {
    await _open(tester, selected: 'al2');
    expect(
      find.descendant(
        of: find.byKey(const Key('album-pick-al2')),
        matching: find.byKey(const Key('option-radio-dot')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('album-pick-none')),
        matching: find.byKey(const Key('option-radio-dot')),
      ),
      findsNothing,
    );
  });

  testWidgets('"Không xếp album" returns none and closes', (tester) async {
    final (_, results) = await _open(tester, selected: 'al1');
    await tester.tap(find.byKey(const Key('album-pick-none')));
    await tester.pumpAndSettle();
    expect(find.text('Xếp vào album'), findsNothing);
    expect(results.single, isNotNull);
    expect(results.single!.albumId, isNull);
  });

  testWidgets('an album returns its id and closes', (tester) async {
    final (_, results) = await _open(tester);
    await tester.tap(find.byKey(const Key('album-pick-al2')));
    await tester.pumpAndSettle();
    expect(results.single!.albumId, 'al2');
  });

  testWidgets('dismissing returns null', (tester) async {
    final (_, results) = await _open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(results.single, isNull);
  });

  testWidgets('without albums only "Không xếp album" and "Album mới" show', (
    tester,
  ) async {
    await _open(tester, albums: false);
    expect(find.byKey(const Key('album-pick-none')), findsOneWidget);
    expect(find.byKey(const Key('album-pick-new')), findsOneWidget);
    expect(find.textContaining('bài'), findsNothing);
  });

  testWidgets('Album mới: the title is required, a limit error is shown', (
    tester,
  ) async {
    final (w, results) = await _open(tester, albums: false);
    w.albums.failWith = const AlbumError('limit_exceeded');
    await tester.tap(find.byKey(const Key('album-pick-new')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('album-edit-save')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('album-edit-title')),
      '  Phố  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('album-edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã có đủ 30 album.'), findsOneWidget);
    expect(results, isEmpty);

    w.albums.failWith = null;
    await tester.tap(find.byKey(const Key('album-edit-save')));
    await tester.pumpAndSettle();
    expect(w.albums.calls, ['create:Phố']);
    expect(results.single!.albumId, 'new1');
  });
}
