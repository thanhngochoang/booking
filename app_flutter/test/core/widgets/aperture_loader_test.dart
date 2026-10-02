// test/core/widgets/aperture_loader_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

void main() {
  test('the cycle: open, closed and held 45–55 %, open again', () {
    expect(apertureClosureAt(0), 0);
    expect(apertureClosureAt(0.45), closeTo(1, 1e-9));
    expect(apertureClosureAt(0.5), 1);
    expect(apertureClosureAt(0.55), closeTo(1, 1e-9));
    expect(apertureClosureAt(1), closeTo(0, 1e-9));
    expect(apertureClosureAt(0.2), inExclusiveRange(0, 1));
  });

  testWidgets(
    'while active there is exactly one ticker; the mark is white on the CTA fill',
    (tester) async {
      await tester.pumpWidget(
        hostWidget(
          const Center(child: ApertureLoader(semanticsLabel: 'Đang tìm')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 1);
      expect(find.byType(CtaSurface), findsOneWidget);
      expect(
        tester.widget<ApertureMark>(find.byType(ApertureMark)).color,
        Colors.white,
      );
      expect(find.bySemanticsLabel('Đang tìm'), findsOneWidget);
    },
  );

  testWidgets('inactive: stopped, open, idle', (tester) async {
    await tester.pumpWidget(
      hostWidget(const Center(child: ApertureLoader(active: false))),
    );
    await expectIdle(tester);
    expect(tester.widget<ApertureMark>(find.byType(ApertureMark)).closure, 0);
  });

  testWidgets('switching active off stops the controller', (tester) async {
    await tester.pumpWidget(hostWidget(const Center(child: ApertureLoader())));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      hostWidget(const Center(child: ApertureLoader(active: false))),
    );
    await expectIdle(tester);
  });

  testWidgets('reduced motion: static and open, still labelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: ApertureLoader(semanticsLabel: 'Đang chờ thanh toán'),
          ),
        ),
      ),
    );
    await expectIdle(tester);
    expect(tester.widget<ApertureMark>(find.byType(ApertureMark)).closure, 0);
    expect(find.bySemanticsLabel('Đang chờ thanh toán'), findsOneWidget);
  });

  testWidgets('a muted TickerMode (screen not visible) runs no ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const TickerMode(
          enabled: false,
          child: Center(child: ApertureLoader()),
        ),
      ),
    );
    await expectIdle(tester);
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
