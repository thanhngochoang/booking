import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _items = [
  PostPickItem(postId: 'a', thumbUrl: 'u/a', imageCount: 4),
  PostPickItem(postId: 'b', thumbUrl: 'u/b'),
  PostPickItem(postId: 'c', thumbUrl: 'u/c', albumTitle: 'Cưới Đà Lạt'),
  PostPickItem(postId: 'd', thumbUrl: 'u/d'),
];

Widget _grid(
  List<String> selected, {
  int? max,
  ValueChanged<String>? onToggle,
}) => PhotoImageScope(
  builder: (context, url, fit, cacheWidth, retry) =>
      const ColoredBox(color: Colors.grey),
  child: PostPickerGrid(
    items: _items,
    selected: selected,
    onToggle: onToggle ?? (_) {},
    maxSelected: max,
  ),
);

void main() {
  testWidgets('picker numbers tiles in selection order', (tester) async {
    await tester.pumpWidget(hostWidget(_grid(['c', 'a'])));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('post-pick-c')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('post-pick-a')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('post-pick-b')),
        matching: find.text('1'),
      ),
      findsNothing,
    );
  });

  testWidgets('picker lays out three columns and reports taps', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      hostWidget(_grid(const [], onToggle: tapped.add), width: 300),
    );
    final a = tester.getTopLeft(find.byKey(const ValueKey('post-pick-a')));
    final c = tester.getTopLeft(find.byKey(const ValueKey('post-pick-c')));
    final d = tester.getTopLeft(find.byKey(const ValueKey('post-pick-d')));
    expect(c.dy, a.dy);
    expect(d.dy, greaterThan(a.dy));
    await tester.tap(find.byKey(const ValueKey('post-pick-b')));
    expect(tapped, ['b']);
    expect(find.text('4 ảnh'), findsOneWidget);
  });

  testWidgets('picker disables extra tiles at the maximum', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      hostWidget(_grid(['a', 'b'], max: 2, onToggle: tapped.add)),
    );
    await tester.tap(
      find.byKey(const ValueKey('post-pick-c')),
      warnIfMissed: false,
    );
    expect(tapped, isEmpty);
    // A selected tile can still be deselected.
    await tester.tap(find.byKey(const ValueKey('post-pick-a')));
    expect(tapped, ['a']);
  });

  testWidgets('picker labels a tile with its current album', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_grid(['c'])));
    expect(find.text('Cưới Đà Lạt'), findsOneWidget);
    final node = tester.getSemantics(find.byKey(const ValueKey('post-pick-c')));
    expect(node.label, contains('Cưới Đà Lạt'));
    expect(node.label, contains('thứ 1'));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('every tile has a non-empty label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_grid(const [])));
    for (final id in ['a', 'b', 'c', 'd']) {
      final node = tester.getSemantics(find.byKey(ValueKey('post-pick-$id')));
      expect(node.label, isNotEmpty, reason: id);
    }
    final b = tester.getSemantics(find.byKey(const ValueKey('post-pick-b')));
    expect(b.label, 'Bài 2 trên 4');
    handle.dispose();
  });

  testWidgets('a supplied label names the tile', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        PhotoImageScope(
          builder: (context, url, fit, cacheWidth, retry) =>
              const ColoredBox(color: Colors.grey),
          child: PostPickerGrid(
            items: const [
              PostPickItem(postId: 'z', thumbUrl: 'u/z', label: 'Hồ Tây'),
            ],
            selected: const [],
            onToggle: (_) {},
          ),
        ),
      ),
    );
    final node = tester.getSemantics(find.byKey(const ValueKey('post-pick-z')));
    expect(node.label, 'Hồ Tây');
    handle.dispose();
  });
}
