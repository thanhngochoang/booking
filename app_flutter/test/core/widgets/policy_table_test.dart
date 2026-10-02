// test/core/widgets/policy_table_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/policy_table.dart';

import 'widget_host.dart';

const _sampleRows = [
  PolicyRow(when: 'Trước 12/10 15:30 hơn 48 giờ', outcome: 'Hoàn 100%'),
  PolicyRow(when: 'Trong 24–48 giờ', outcome: 'Hoàn 50%'),
  PolicyRow(when: 'Dưới 24 giờ', outcome: 'Không hoàn'),
];

void main() {
  testWidgets('active row highlighted and announced "Đang áp dụng"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const PolicyTable(rows: _sampleRows, activeIndex: 0)),
    );

    expect(find.text('Hoàn 100%'), findsOneWidget);
    expect(find.text('Hoàn 50%'), findsOneWidget);
    expect(find.text('Không hoàn'), findsOneWidget);

    // Active row has semantics announcement "Đang áp dụng"
    expect(
      find.bySemanticsLabel(RegExp(r'Đang áp dụng.*Hoàn 100%')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          const PolicyTable(rows: _sampleRows, activeIndex: 0),
          width: 320,
          textScale: 1.3,
          brightness: brightness,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('skeleton has same size as real widget at 390 and 320 dp', (
    tester,
  ) async {
    for (final width in [390.0, 320.0]) {
      await tester.pumpWidget(
        hostWidget(
          const PolicyTable(rows: _sampleRows, activeIndex: 0),
          width: width,
        ),
      );
      final realSize = tester.getSize(find.byType(PolicyTable));

      await tester.pumpWidget(
        hostWidget(
          AppSkeletonScope(child: PolicyTable.skeleton(rows: 3)),
          width: width,
        ),
      );
      final skeletonSize = tester.getSize(
        find.byWidgetPredicate(
          (w) => w.key == const ValueKey('policy_table_skeleton'),
        ),
      );

      expect(skeletonSize.width, realSize.width);
      expect(skeletonSize.height, realSize.height);
    }
  });
}
