// test/core/widgets/step_progress_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

int _filled(WidgetTester tester) =>
    find.byKey(const Key('step-filled')).evaluate().length;

void main() {
  testWidgets('fills the segments up to the current step', (tester) async {
    await tester.pumpWidget(
      hostWidget(const StepProgress(current: 2, total: 4)),
    );
    expect(find.byKey(const Key('step-segment')), findsNWidgets(4));
    expect(_filled(tester), 2);
    expect(find.text('2 / 4'), findsOneWidget);
  });

  testWidgets('an optional label is shown with the count', (tester) async {
    await tester.pumpWidget(
      hostWidget(const StepProgress(current: 1, total: 3, label: 'Gói')),
    );
    expect(find.text('Gói'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('out-of-range values are clamped', (tester) async {
    await tester.pumpWidget(
      hostWidget(const StepProgress(current: 9, total: 4)),
    );
    expect(_filled(tester), 4);
    await tester.pumpWidget(
      hostWidget(const StepProgress(current: -1, total: 4)),
    );
    expect(_filled(tester), 0);
  });

  testWidgets('screen readers hear the step in words', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const StepProgress(current: 2, total: 4)),
    );
    expect(find.bySemanticsLabel('Bước 2 trên 4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const StepProgress(current: 3, total: 4, label: 'Xem lại và đặt cọc'),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
