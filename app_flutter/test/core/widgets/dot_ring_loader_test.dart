// test/core/widgets/dot_ring_loader_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

class _RecordingCanvas implements Canvas {
  final radii = <double>[];
  final alphas = <double>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    radii.add(radius);
    alphas.add(paint.color.a);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('the cycle: one eased turn over 75 %, then rest', () {
    expect(dotRingTurnAt(0), 0);
    expect(dotRingTurnAt(0.375), closeTo(0.5, 0.05));
    expect(dotRingTurnAt(0.75), 1);
    expect(dotRingTurnAt(0.9), 1);
    expect(dotRingTurnAt(1), 1);
    expect(dotRingTurnAt(0.1), inExclusiveRange(0, 0.5));
  });

  test(
    'twelve dots, head largest and opaque, the tail smaller and fainter',
    () {
      const painter = DotRingPainter(
        turn: 0.3,
        color: AppColors.primary,
        dotSize: 10,
      );
      final canvas = _RecordingCanvas();
      painter.paint(canvas, const Size(96, 96));
      expect(canvas.radii, hasLength(12));
      expect(canvas.radii.first, 5);
      expect(canvas.alphas.first, closeTo(1, 1e-6));
      for (var k = 1; k < 12; k++) {
        expect(canvas.radii[k], lessThan(canvas.radii[k - 1]));
        expect(canvas.alphas[k], lessThan(canvas.alphas[k - 1]));
      }
    },
  );

  testWidgets('sizes follow LoaderSize unless a dimension is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const Column(
          children: [
            DotRingLoader(key: Key('screen')),
            DotRingLoader(key: Key('block'), size: LoaderSize.block),
            DotRingLoader(key: Key('inline'), size: LoaderSize.inline),
            DotRingLoader(key: Key('custom'), dimension: 36, dotSize: 5),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('screen'))), const Size(96, 96));
    expect(tester.getSize(find.byKey(const Key('block'))), const Size(64, 64));
    expect(tester.getSize(find.byKey(const Key('inline'))), const Size(24, 24));
    expect(tester.getSize(find.byKey(const Key('custom'))), const Size(36, 36));
  });

  testWidgets('runs one ticker while active and stops when switched off', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const Center(child: DotRingLoader(semanticsLabel: 'Đang tải')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 1);
    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);

    await tester.pumpWidget(
      hostWidget(const Center(child: DotRingLoader(active: false))),
    );
    await expectIdle(tester);
  });

  testWidgets('reduced motion: still ring, no ticker', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: DotRingLoader(semanticsLabel: 'Đang tải')),
        ),
      ),
    );
    await expectIdle(tester);
    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);
  });
}
