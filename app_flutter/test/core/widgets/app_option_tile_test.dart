// test/core/widgets/app_option_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

ShapeDecoration _decoration(WidgetTester tester) {
  final box = tester.widget<Ink>(
    find.descendant(of: find.byType(AppOptionTile), matching: find.byType(Ink)),
  );
  return box.decoration! as ShapeDecoration;
}

void main() {
  for (final b in Brightness.values) {
    final dark = b == Brightness.dark;
    testWidgets('unselected and selected looks on ${b.name}', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        hostWidget(
          StatefulBuilder(
            builder: (context, set) => AppOptionTile(
              label: 'Quận 1, TP.HCM',
              selected: selected,
              onTap: () => set(() => selected = true),
            ),
          ),
          brightness: b,
        ),
      );
      final scheme = Theme.of(tester.element(find.byType(AppOptionTile)))
          .colorScheme;
      var d = _decoration(tester);
      var shape = d.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppRadius.xl));
      expect(shape.side.color, scheme.outline);
      expect(d.color, dark ? AppColorsDark.glass : AppColors.glass);
      expect(find.byKey(const Key('option-radio-dot')), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.tap(find.byType(AppOptionTile));
      await tester.pump();
      d = _decoration(tester);
      shape = d.shape as RoundedRectangleBorder;
      expect(shape.side.color, scheme.primary);
      expect(
        d.color,
        dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
      );
      expect(find.byKey(const Key('option-radio-dot')), findsOneWidget);
    });
  }

  testWidgets('radio semantics and a 48dp row', (tester) async {
    await tester.pumpWidget(
      hostWidget(AppOptionTile(label: 'Quận 3', selected: true, onTap: () {})),
    );
    expect(
      tester.getSemantics(find.byType(AppOptionTile)),
      matchesSemantics(
        label: 'Quận 3',
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    expect(
      tester.getSize(find.byType(AppOptionTile)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a long label wraps at 320dp and 1.3x', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        AppOptionTile(
          label: 'Thành phố Thủ Đức, Thành phố Hồ Chí Minh, Việt Nam',
          leading: const Icon(Icons.my_location_outlined),
          selected: false,
          onTap: () {},
        ),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
