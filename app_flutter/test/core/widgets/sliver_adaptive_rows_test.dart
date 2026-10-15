// test/core/widgets/sliver_adaptive_rows_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _list(double width, int count) => hostWidget(
  CustomScrollView(
    slivers: [
      SliverAdaptiveRows(
        itemCount: count,
        itemBuilder: (_, i) =>
            SizedBox(key: Key('item$i'), height: 40, child: Text('Mục $i')),
      ),
    ],
  ),
  width: width,
);

void main() {
  testWidgets('one item per row on a phone', (tester) async {
    await tester.pumpWidget(_list(390, 3));
    final tops = [
      for (var i = 0; i < 3; i++)
        tester.getTopLeft(find.byKey(Key('item$i'))).dy,
    ];
    expect(tops.toSet(), hasLength(3));
    expect(tester.getTopLeft(find.byKey(const Key('item1'))).dx, 0);
  });

  testWidgets('two items per row from 600dp, odd last row is half empty', (
    tester,
  ) async {
    await tester.pumpWidget(_list(640, 3));
    final a = tester.getRect(find.byKey(const Key('item0')));
    final b = tester.getRect(find.byKey(const Key('item1')));
    final c = tester.getRect(find.byKey(const Key('item2')));
    expect(a.top, b.top);
    expect(b.left, greaterThan(a.right));
    expect(c.top, greaterThan(a.top));
    expect(c.left, 0);
    expect(a.width, closeTo(b.width, 0.01));
    expect(a.width, lessThan(640 / 2));
  });

  testWidgets('an empty list builds nothing and does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(_list(640, 0));
    expect(tester.takeException(), isNull);
  });
}
