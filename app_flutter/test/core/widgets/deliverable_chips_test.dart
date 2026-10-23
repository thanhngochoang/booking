// test/core/widgets/deliverable_chips_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/deliverable_chips.dart';

import 'widget_host.dart';

void main() {
  group('DeliverableChips', () {
    testWidgets('row shows each chip and the positive one uses the success colour', (tester) async {
      final items = [
        const DeliverableItem(label: 'ảnh chỉnh', value: '60'),
        const DeliverableItem(label: 'giao 5 ngày'),
        const DeliverableItem(label: 'sửa 2 lần'),
        const DeliverableItem(label: 'Rảnh 20/10', positive: true),
      ];

      await tester.pumpWidget(
        hostWidget(
          DeliverableChips(items: items),
          brightness: Brightness.light,
        ),
      );

      expect(find.text('60 ảnh chỉnh'), findsOneWidget);
      expect(find.text('giao 5 ngày'), findsOneWidget);
      expect(find.text('sửa 2 lần'), findsOneWidget);
      expect(find.text('Rảnh 20/10'), findsOneWidget);

      final positiveText = tester.widget<Text>(find.text('Rảnh 20/10'));
      expect(positiveText.style?.color, AppColors.freeInk);
    });

    testWidgets('grid shows four tiles with the value above the label', (tester) async {
      final items = [
        const DeliverableItem(label: 'ảnh chỉnh', value: '60'),
        const DeliverableItem(label: 'ảnh gốc', value: '300+'),
        const DeliverableItem(label: 'ngày giao', value: '5'),
        const DeliverableItem(label: 'lần sửa', value: '2'),
      ];

      await tester.pumpWidget(
        hostWidget(
          DeliverableChips(items: items, grid: true),
          width: 320,
        ),
      );

      expect(find.text('60'), findsOneWidget);
      expect(find.text('300+'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      final valFinder = find.text('60');
      final valWidget = tester.widget<Text>(valFinder);
      expect(valWidget.style?.fontFamily, AppFonts.display);

      expect(find.text('ảnh chỉnh'), findsOneWidget);
      expect(find.text('ảnh gốc'), findsOneWidget);
      expect(find.text('ngày giao'), findsOneWidget);
      expect(find.text('lần sửa'), findsOneWidget);
    });

    testWidgets('a missing value shows —', (tester) async {
      final items = [
        const DeliverableItem(label: 'ảnh chỉnh', value: null),
        const DeliverableItem(label: 'ảnh gốc', value: ''),
      ];

      await tester.pumpWidget(
        hostWidget(
          DeliverableChips(items: items, grid: true),
          width: 320,
        ),
      );

      expect(find.text('—'), findsNWidgets(2));
    });
  });
}
