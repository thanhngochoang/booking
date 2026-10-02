// test/core/widgets/money_breakdown_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/money_breakdown.dart';

import 'widget_host.dart';

const _sampleLines = [
  MoneyLine(label: 'Gói Chân dung 2 giờ', vnd: 1500000),
  MoneyLine(
    label: 'Đặt cọc hôm nay (30%)',
    vnd: 450000,
    style: MoneyLineStyle.strong,
  ),
  MoneyLine(
    label: 'Còn lại trả tại buổi chụp',
    vnd: 1050000,
    style: MoneyLineStyle.muted,
  ),
];

void main() {
  testWidgets(
    'formats with formatMoney, strong row bold, muted row secondary, numbers tabular',
    (tester) async {
      await tester.pumpWidget(
        hostWidget(const MoneyBreakdown(lines: _sampleLines)),
      );

      expect(find.text('1.500.000₫'), findsOneWidget);
      expect(find.text('450.000₫'), findsOneWidget);
      expect(find.text('1.050.000₫'), findsOneWidget);

      // Strong line has bold font weight
      final strongText = tester.widget<Text>(find.text('450.000₫'));
      expect(
        strongText.style?.fontWeight,
        anyOf(FontWeight.bold, FontWeight.w700, FontWeight.w600),
      );

      // Numbers have tabular figures
      final normalNum = tester.widget<Text>(find.text('1.500.000₫'));
      expect(
        normalNum.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );

      // Muted label has muted/secondary color
      final mutedLabel = tester.widget<Text>(
        find.text('Còn lại trả tại buổi chụp'),
      );
      expect(
        mutedLabel.style?.color,
        anyOf(
          AppColorsDark.foregroundSecondary,
          AppColorsDark.foregroundMuted,
          AppColors.foregroundSecondary,
          AppColors.foregroundMuted,
        ),
      );
    },
  );

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          const MoneyBreakdown(lines: _sampleLines),
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
        hostWidget(const MoneyBreakdown(lines: _sampleLines), width: width),
      );
      final realSize = tester.getSize(find.byType(MoneyBreakdown));

      await tester.pumpWidget(
        hostWidget(
          AppSkeletonScope(child: MoneyBreakdown.skeleton(lines: 3)),
          width: width,
        ),
      );
      final skeletonSize = tester.getSize(
        find.byWidgetPredicate(
          (w) => w.key == const ValueKey('money_breakdown_skeleton'),
        ),
      );

      expect(skeletonSize.width, realSize.width);
      expect(skeletonSize.height, realSize.height);
    }
  });
}
