import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _list({
  required int index,
  required int count,
  required void Function(int) onMove,
  List<PopupMenuEntry<VoidCallback>> extra = const [],
}) {
  return SizedBox(
    height: 300,
    child: ReorderableListView(
      buildDefaultDragHandles: false,
      onReorderItem: (_, _) {},
      children: [
        for (var i = 0; i < count; i++)
          if (i == index)
            ReorderableRow(
              key: ValueKey(i),
              index: i,
              count: count,
              title: 'Album $i',
              subtitle: '4 ảnh',
              onMove: onMove,
              extraMenu: extra,
            )
          else
            SizedBox(key: ValueKey(i), height: 40),
      ],
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_horiz_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menu moves call onMove with the new index', (tester) async {
    final moves = <int>[];
    await tester.pumpWidget(
      hostWidget(_list(index: 2, count: 5, onMove: moves.add)),
    );
    await _open(tester);
    await tester.tap(find.text('Chuyển lên'));
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.tap(find.text('Chuyển xuống'));
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.tap(find.text('Lên đầu'));
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.tap(find.text('Xuống cuối'));
    await tester.pumpAndSettle();
    expect(moves, [1, 3, 0, 4]);
  });

  testWidgets('up from the first and down from the last are disabled', (
    tester,
  ) async {
    final moves = <int>[];
    await tester.pumpWidget(
      hostWidget(_list(index: 0, count: 3, onMove: moves.add)),
    );
    await _open(tester);
    await tester.tap(find.text('Chuyển lên'), warnIfMissed: false);
    await tester.tap(find.text('Lên đầu'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(moves, isEmpty);
    expect(find.text('Chuyển xuống'), findsOneWidget);
    await tester.tap(find.text('Chuyển xuống'));
    await tester.pumpAndSettle();
    expect(moves, [1]);

    await tester.pumpWidget(
      hostWidget(_list(index: 2, count: 3, onMove: moves.add)),
    );
    await _open(tester);
    await tester.tap(find.text('Chuyển xuống'), warnIfMissed: false);
    await tester.tap(find.text('Xuống cuối'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(moves, [1]);
  });

  testWidgets('extra menu entries run their callback', (tester) async {
    var edited = 0;
    await tester.pumpWidget(
      hostWidget(
        _list(
          index: 1,
          count: 3,
          onMove: (_) {},
          extra: [
            PopupMenuItem<VoidCallback>(
              value: () => edited++,
              child: const Text('Sửa'),
            ),
          ],
        ),
      ),
    );
    await _open(tester);
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    expect(edited, 1);
  });

  testWidgets('row announces n of m', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(_list(index: 1, count: 4, onMove: (_) {})),
    );
    final node = tester.getSemantics(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.value == '2 trên 4',
      ),
    );
    expect(node.label, contains('Album 1'));
    expect(node.value, '2 trên 4');
    handle.dispose();
  });

  testWidgets('drag handle and menu have 48dp hit areas', (tester) async {
    await tester.pumpWidget(
      hostWidget(_list(index: 1, count: 3, onMove: (_) {})),
    );
    final handle = tester.getSize(find.byKey(ReorderableRow.handleKey));
    expect(handle.width, greaterThanOrEqualTo(48));
    expect(handle.height, greaterThanOrEqualTo(48));
    final menu = tester.getSize(find.byType(PopupMenuButton<VoidCallback>));
    expect(menu.width, greaterThanOrEqualTo(48));
    expect(menu.height, greaterThanOrEqualTo(48));
    expect(
      find.ancestor(
        of: find.byKey(ReorderableRow.handleKey),
        matching: find.byType(ReorderableDelayedDragStartListener),
      ),
      findsOneWidget,
    );
  });
}
