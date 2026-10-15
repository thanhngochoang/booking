// test/core/widgets/signature_loader_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

class _RecordingCanvas implements Canvas {
  int circleCount = 0;
  int pathCount = 0;

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circleCount++;
  }

  @override
  void drawPath(Path path, Paint paint) {
    pathCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('the cycle: open, closed and held 45–55 %, open again', () {
    expect(apertureClosureAt(0), 0);
    expect(apertureClosureAt(0.45), closeTo(1, 1e-9));
    expect(apertureClosureAt(0.5), 1);
    expect(apertureClosureAt(0.55), closeTo(1, 1e-9));
    expect(apertureClosureAt(1), closeTo(0, 1e-9));
    expect(apertureClosureAt(0.2), inExclusiveRange(0, 1));
  });

  test('ripple draws three circles and no wavy ring', () {
    const painter = SignatureWavesPainter(
      t: 0.5,
      wave: LoaderWave.ripple,
      size: LoaderSize.screen,
      waveColor: AppColors.primary,
    );
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(150, 150));
    expect(canvas.circleCount, 3);
    expect(canvas.pathCount, 0);
  });

  test('vibration draws two wavy rings and no circles', () {
    const painter = SignatureWavesPainter(
      t: 0.5,
      wave: LoaderWave.vibration,
      size: LoaderSize.screen,
      waveColor: AppColors.spectrumCyan,
    );
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(150, 150));
    expect(canvas.circleCount, 0);
    expect(canvas.pathCount, 2);
  });

  test('inline size draws no waves', () {
    const painter = SignatureWavesPainter(
      t: 0.5,
      wave: LoaderWave.ripple,
      size: LoaderSize.inline,
      waveColor: AppColors.primary,
    );
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(56, 56));
    expect(canvas.circleCount, 0);
    expect(canvas.pathCount, 0);
  });

  testWidgets(
    'no filled disc or gradient behind the aperture; blade color equals the wave color (primary for ripple, focus for vibration)',
    (tester) async {
      // Test ripple
      await tester.pumpWidget(
        hostWidget(
          const Center(child: SignatureLoader(wave: LoaderWave.ripple)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.descendant(
          of: find.byType(SignatureLoader),
          matching: find.byType(CtaSurface),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(SignatureLoader),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );

      final rippleMark = tester.widget<ApertureMark>(find.byType(ApertureMark));
      expect(rippleMark.color, AppColorsDark.primary);

      // Test vibration
      await tester.pumpWidget(
        hostWidget(
          const Center(child: SignatureLoader(wave: LoaderWave.vibration)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final vibMark = tester.widget<ApertureMark>(find.byType(ApertureMark));
      expect(vibMark.color, AppColors.spectrumCyan);
    },
  );

  testWidgets('one ticker while active; none when active is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const Center(child: SignatureLoader(semanticsLabel: 'Đang tải')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 1);
    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);

    await tester.pumpWidget(
      hostWidget(const Center(child: SignatureLoader(active: false))),
    );
    await expectIdle(tester);
    expect(tester.widget<ApertureMark>(find.byType(ApertureMark)).closure, 0);
  });

  testWidgets('switching active off stops the controller', (tester) async {
    await tester.pumpWidget(hostWidget(const Center(child: SignatureLoader())));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      hostWidget(const Center(child: SignatureLoader(active: false))),
    );
    await expectIdle(tester);
  });

  testWidgets(
    'reduced motion: open aperture, one still ring, no waves, no ticker',
    (tester) async {
      await tester.pumpWidget(
        hostWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Center(
              child: SignatureLoader(semanticsLabel: 'Đang chờ thanh toán'),
            ),
          ),
        ),
      );
      await expectIdle(tester);
      expect(tester.widget<ApertureMark>(find.byType(ApertureMark)).closure, 0);
      expect(find.bySemanticsLabel('Đang chờ thanh toán'), findsOneWidget);

      const painter = SignatureWavesPainter(
        t: 0.0,
        wave: LoaderWave.ripple,
        size: LoaderSize.screen,
        waveColor: AppColors.primary,
        reduced: true,
      );
      final canvas = _RecordingCanvas();
      painter.paint(canvas, const Size(150, 150));
      expect(canvas.circleCount, 1);
      expect(canvas.pathCount, 0);
    },
  );

  testWidgets('a muted TickerMode (screen not visible) runs no ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const TickerMode(
          enabled: false,
          child: Center(child: SignatureLoader()),
        ),
      ),
    );
    await expectIdle(tester);
  });

  testWidgets('semantics label is read', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const Center(child: SignatureLoader(semanticsLabel: 'Đang tìm')),
      ),
    );
    expect(find.bySemanticsLabel('Đang tìm'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    for (final closure in [0.0, 0.5, 1.0]) {
      testWidgets('golden: closure $closure, ${b.name}', tags: ['golden'], (
        tester,
      ) async {
        await tester.pumpWidget(
          hostWidget(
            Center(
              child: RepaintBoundary(
                key: const Key('mark'),
                child: SizedBox.square(
                  dimension: 100,
                  child: ColoredBox(
                    color: b == Brightness.dark
                        ? AppColorsDark.background
                        : AppColors.background,
                    child: Center(
                      child: ApertureMark(size: 80, closure: closure),
                    ),
                  ),
                ),
              ),
            ),
            brightness: b,
          ),
        );
        await expectLater(
          find.byKey(const Key('mark')),
          matchesGoldenFile(
            'goldens/aperture_mark_${(closure * 10).round()}_${b.name}.png',
          ),
        );
      });
    }
  }
}
