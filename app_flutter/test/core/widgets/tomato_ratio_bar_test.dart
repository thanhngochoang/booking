import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _tomatoSeg = Key('ratio-tomato');
const _brickSeg = Key('ratio-brick');

void main() {
  testWidgets('segments are proportional (56:2)', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const TomatoRatioBar(tomatoCount: 56, brickCount: 2),
        width: 300,
      ),
    );
    final t = tester.getSize(find.byKey(_tomatoSeg)).width;
    final b = tester.getSize(find.byKey(_brickSeg)).width;
    expect(t / b, closeTo(28, 0.01));
    // Whole bar = both segments + the 2 dp gap.
    expect(t + b + 2, closeTo(300, 0.01));
    expect(tester.getSize(find.byType(TomatoRatioBar)).height, 8);
  });

  testWidgets('segments use the token colours', (tester) async {
    await tester.pumpWidget(
      hostWidget(const TomatoRatioBar(tomatoCount: 3, brickCount: 1)),
    );
    Color? colorOf(Key k) =>
        (tester.widget<DecoratedBox>(find.byKey(k)).decoration as BoxDecoration)
            .color;
    expect(colorOf(_tomatoSeg), AppColorsDark.tomato);
    expect(colorOf(_brickSeg), AppColorsDark.brick);
  });

  testWidgets('zero reviews draws an empty track', (tester) async {
    await tester.pumpWidget(
      hostWidget(const TomatoRatioBar(tomatoCount: 0, brickCount: 0)),
    );
    expect(find.byKey(_tomatoSeg), findsNothing);
    expect(find.byKey(_brickSeg), findsNothing);
    expect(find.byKey(const Key('ratio-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only tomatoes fill the whole bar', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const TomatoRatioBar(tomatoCount: 5, brickCount: 0),
        width: 200,
      ),
    );
    expect(tester.getSize(find.byKey(_tomatoSeg)).width, 200);
    expect(find.byKey(_brickSeg), findsNothing);
  });

  testWidgets('is read as "56 cà chua, 2 gạch"', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const TomatoRatioBar(tomatoCount: 56, brickCount: 2)),
    );
    expect(
      tester.getSemantics(find.byType(TomatoRatioBar)),
      matchesSemantics(label: '56 cà chua, 2 gạch'),
    );
    handle.dispose();
  });
}
