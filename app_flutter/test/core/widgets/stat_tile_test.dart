// test/core/widgets/stat_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _tiles = [
  StatTile(value: '12,4M', label: 'Đang giữ'),
  StatTile(value: '3,2M', label: 'Sắp nhận'),
  StatTile(value: '5', label: 'Đã nhận trong tháng'),
];

void main() {
  testWidgets('three tiles share one row and one height at 320dp, 1.3x', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const StatTileRow(tiles: _tiles), width: 320, textScale: 1.3),
    );
    expect(tester.takeException(), isNull);
    final rects = [
      for (final t in _tiles)
        tester.getRect(find.widgetWithText(StatTile, t.label)),
    ];
    expect(rects.map((r) => r.top).toSet().length, 1, reason: 'same row');
    expect(rects.map((r) => r.height).toSet().length, 1, reason: 'same height');
  });

  testWidgets('a long label scales down to one line instead of wrapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const StatTileRow(tiles: _tiles), width: 320, textScale: 1.3),
    );
    final label = tester.getSize(find.text('Đã nhận trong tháng'));
    final short = tester.getSize(find.text('Đang giữ'));
    expect(label.height, closeTo(short.height, 1));
  });

  testWidgets('the number uses tabular figures', (tester) async {
    await tester.pumpWidget(
      hostWidget(const StatTile(value: '12,4M', label: 'x')),
    );
    final style = tester.widget<Text>(find.text('12,4M')).style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontFamily, AppFonts.display);
  });

  testWidgets('screen readers read value then label as one item', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const StatTile(value: '5', label: 'Đã nhận')),
    );
    expect(find.bySemanticsLabel('5, Đã nhận'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tile is left-aligned, radius 16, content pinned to the bottom', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const SizedBox(
          width: 160,
          height: 120,
          child: StatTile(value: '5', label: 'Đã nhận'),
        ),
      ),
    );
    final deco =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(StatTile),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(AppRadius.xl));
    final tile = tester.getRect(find.byType(StatTile));
    final value = tester.getRect(find.text('5'));
    final label = tester.getRect(find.text('Đã nhận'));
    expect(value.left - tile.left, lessThan(20));
    expect(label.left, closeTo(value.left, 0.5));
    expect(tile.bottom - label.bottom, lessThan(20));
    expect(value.top - tile.top, greaterThan(30));
  });
}
