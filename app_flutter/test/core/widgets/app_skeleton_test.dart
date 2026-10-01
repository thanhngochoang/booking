import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('box, line and card have the requested sizes', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const Column(
          children: [
            AppSkeleton.box(key: Key('box'), width: 80, height: 40),
            AppSkeleton.line(key: Key('line'), width: 120),
            AppSkeleton.card(key: Key('card'), height: 90),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('box'))), const Size(80, 40));
    expect(tester.getSize(find.byKey(const Key('line'))), const Size(120, 12));
    expect(tester.getSize(find.byKey(const Key('card'))).height, 90);
  });

  testWidgets('pulses normally, is static under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const AppSkeleton.box(height: 20, width: 20)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const AppSkeleton.box(height: 20, width: 20),
          ),
        ),
      ),
    );
    // The host rebuilds its theme object, which animates for a moment; let
    // that finish so only the skeleton's own ticker could still be running.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const AppSkeleton.line()));
    expect(
      find.descendant(
        of: find.byType(AppSkeleton),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('bones in one scope share a single animation', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const AppSkeletonScope(
          child: Column(
            children: [
              AppSkeleton.box(width: 20, height: 20),
              AppSkeleton.line(width: 40),
              AppSkeleton.card(),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final fades = tester
        .widgetList<FadeTransition>(
          find.descendant(
            of: find.byType(AppSkeleton),
            matching: find.byType(FadeTransition),
          ),
        )
        .toList();
    expect(fades, hasLength(3));
    expect(fades.map((f) => f.opacity).toSet(), hasLength(1));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('reduced motion toggled on a live widget stops at opaque', (
    tester,
  ) async {
    final reduce = ValueNotifier(false);
    addTearDown(reduce.dispose);
    await tester.pumpWidget(
      hostWidget(
        ValueListenableBuilder<bool>(
          valueListenable: reduce,
          builder: (context, r, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: r),
            child: const Column(
              children: [
                AppSkeletonScope(
                  child: AppSkeleton.box(key: Key('scoped'), height: 10),
                ),
                AppSkeleton.box(key: Key('own'), height: 10),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);

    reduce.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
    for (final k in ['scoped', 'own']) {
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byKey(Key(k)),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 1.0, reason: k);
    }
  });
}
