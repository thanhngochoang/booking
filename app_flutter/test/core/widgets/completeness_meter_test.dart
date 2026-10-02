import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('title, percentage, bar fill and hint', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const CompletenessMeter(
          percent: 72,
          nextHint: 'Thêm ảnh minh chứng cho Chân dung để lên 92%',
        ),
      ),
    );
    expect(find.text('Độ khớp hồ sơ'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(
      find.text('Thêm ảnh minh chứng cho Chân dung để lên 92%'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      0.72,
    );
  });

  testWidgets('one semantics node with value and hint', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const CompletenessMeter(percent: 40, nextHint: 'Gợi ý')),
    );
    expect(
      tester.getSemantics(find.byType(CompletenessMeter)),
      isSemantics(label: 'Độ khớp hồ sơ', value: '40%', hint: 'Gợi ý'),
    );
    handle.dispose();
  });

  testWidgets('clamps to 0..100 and works without a hint', (tester) async {
    await tester.pumpWidget(hostWidget(const CompletenessMeter(percent: 140)));
    expect(find.text('100%'), findsOneWidget);
    await tester.pumpWidget(hostWidget(const CompletenessMeter(percent: -5)));
    expect(find.text('0%'), findsOneWidget);
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      0,
    );
  });

  testWidgets(
    'not scored yet: "Chưa có điểm", empty bar, the hint still shows',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hostWidget(
          const CompletenessMeter(
            percent: null,
            nextHint: 'Lưu để tính độ khớp',
          ),
        ),
      );
      expect(find.text('Chưa có điểm'), findsOneWidget);
      expect(find.text('Lưu để tính độ khớp'), findsOneWidget);
      expect(
        tester
            .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        0,
      );
      expect(
        tester.getSemantics(find.byType(CompletenessMeter)),
        isSemantics(
          label: 'Độ khớp hồ sơ',
          value: 'Chưa có điểm',
          hint: 'Lưu để tính độ khớp',
        ),
      );
      handle.dispose();
    },
  );

  testWidgets('fits 320dp at 1.3x in both themes, no blur', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        hostWidget(
          const CompletenessMeter(
            percent: 85,
            nextHint: 'Chọn khách phù hợp để lên 95%',
          ),
          width: 320,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    }
  });
}
