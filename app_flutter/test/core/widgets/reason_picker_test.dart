// test/core/widgets/reason_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/app_chip.dart';
import 'package:photobooking/core/widgets/app_option_tile.dart';
import 'package:photobooking/core/widgets/reason_picker.dart';

import 'widget_host.dart';

void main() {
  const reasons = ['Đổi kế hoạch', 'Tìm được thợ khác', 'Lý do khác'];

  testWidgets('chips style renders AppChips and selects on tap', (
    tester,
  ) async {
    int? selected = 0;

    await tester.pumpWidget(
      hostWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return ReasonPicker(
              reasons: reasons,
              selected: selected,
              onSelected: (i) => setState(() => selected = i),
              style: ReasonPickerStyle.chips,
            );
          },
        ),
      ),
    );

    expect(find.byType(AppChip), findsNWidgets(3));
    expect(find.text('Đổi kế hoạch'), findsOneWidget);
    expect(find.text('Tìm được thợ khác'), findsOneWidget);
    expect(find.text('Lý do khác'), findsOneWidget);

    // Other field not visible initially
    expect(
      find.byKey(const ValueKey('reason_picker_other_field')),
      findsNothing,
    );

    // Tap on second chip
    await tester.tap(find.text('Tìm được thợ khác'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('radio style renders AppOptionTiles and selects on tap', (
    tester,
  ) async {
    int? selected;

    await tester.pumpWidget(
      hostWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return ReasonPicker(
              reasons: reasons,
              selected: selected,
              onSelected: (i) => setState(() => selected = i),
              style: ReasonPickerStyle.radio,
            );
          },
        ),
      ),
    );

    expect(find.byType(AppOptionTile), findsNWidgets(3));

    await tester.tap(find.text('Đổi kế hoạch'));
    await tester.pumpAndSettle();
    expect(selected, 0);
  });

  testWidgets(
    'selecting Lý do khác reveals text field with counter and callbacks',
    (tester) async {
      int? selected;
      String otherText = '';

      await tester.pumpWidget(
        hostWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return ReasonPicker(
                reasons: reasons,
                selected: selected,
                onSelected: (i) => setState(() => selected = i),
                onOtherText: (val) => otherText = val,
                otherMinLength: 10,
                otherMaxLength: 100,
              );
            },
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('reason_picker_other_field')),
        findsNothing,
      );

      // Select "Lý do khác" (index 2)
      await tester.tap(find.text('Lý do khác'));
      await tester.pumpAndSettle();
      expect(selected, 2);

      final fieldFinder = find.byKey(
        const ValueKey('reason_picker_other_field'),
      );
      expect(fieldFinder, findsOneWidget);

      // Helper text for minimum characters is displayed when below minimum
      expect(find.text('Tối thiểu 10 ký tự'), findsOneWidget);

      // Enter text
      await tester.enterText(fieldFinder, 'Thời tiết xấu');
      await tester.pumpAndSettle();

      expect(otherText, 'Thời tiết xấu');
      // Once length >= 10, helper text disappears
      expect(find.text('Tối thiểu 10 ký tự'), findsNothing);
    },
  );

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          ReasonPicker(
            reasons: reasons,
            selected: 2,
            onSelected: (_) {},
            style: ReasonPickerStyle.radio,
            otherMinLength: 5,
          ),
          width: 320,
          textScale: 1.3,
          brightness: brightness,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
