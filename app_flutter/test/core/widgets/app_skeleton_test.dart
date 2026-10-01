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
}
