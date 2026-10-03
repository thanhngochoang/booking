import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('23:30 UTC on the 11th shows 12 (Vietnam day)', (tester) async {
    // 2026-10-11 23:30 UTC is 2026-10-12 06:30 in Vietnam (UTC+7)
    final utc = DateTime.utc(2026, 10, 11, 23, 30);

    await tester.pumpWidget(
      hostWidget(DateBlock(day: utc)),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('T10'), findsOneWidget);
  });

  testWidgets("reads 'Thứ …, 12 tháng 10'", (tester) async {
    final handle = tester.ensureSemantics();
    // 2026-10-12 is Monday (Thứ hai)
    final day = DateTime.utc(2026, 10, 12, 10, 0);

    await tester.pumpWidget(
      hostWidget(DateBlock(day: day)),
    );

    expect(
      find.bySemanticsLabel('Thứ hai, ngày 12 tháng 10'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('skeleton has the same size as real widget at 390 and 320dp', (
    tester,
  ) async {
    final day = DateTime.utc(2026, 10, 12, 10, 0);

    for (final width in [390.0, 320.0]) {
      await tester.pumpWidget(
        hostWidget(
          DateBlock(day: day),
          width: width,
        ),
      );
      final realSize = tester.getSize(find.byType(DateBlock));

      await tester.pumpWidget(
        hostWidget(
          AppSkeletonScope(child: DateBlock.skeleton()),
          width: width,
        ),
      );
      final skeletonSize = tester.getSize(
        find.byType(DateBlock.skeleton().runtimeType),
      );

      expect(skeletonSize.width, realSize.width);
      expect(skeletonSize.height, realSize.height);
    }
  });

  for (final b in Brightness.values) {
    testWidgets('renders in ${b.name} mode at 320dp with 1.3x text', (
      tester,
    ) async {
      final day = DateTime.utc(2026, 10, 12, 10, 0);

      await tester.pumpWidget(
        hostWidget(
          DateBlock(day: day),
          brightness: b,
          width: 320,
          textScale: 1.3,
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('T10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
