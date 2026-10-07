// test/core/widgets/orders_closed_tag_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('renders the text and the lock icon (${b.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostWidget(const OrdersClosedTag(), brightness: b),
      );
      expect(find.text('Chưa nhận đơn'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OrdersClosedTag),
          matching: find.byIcon(AppIcons.lock),
        ),
        findsOneWidget,
      );
      final text = tester.widget<Text>(find.text('Chưa nhận đơn'));
      expect(
        text.style?.color,
        b == Brightness.dark
            ? AppColorsDark.foregroundSecondary
            : AppColors.foregroundSecondary,
      );
      expect(
        find.descendant(
          of: find.byType(OrdersClosedTag),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
        reason: 'the dashed outline is painted',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('its accessible name is the tag text', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const OrdersClosedTag()));
    expect(find.bySemanticsLabel('Chưa nhận đơn'), findsOneWidget);
    h.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets(
      'the locked button style is the mock .btn.out.dis: 60% ink-2 and line-2 (${b.name})',
      (tester) async {
        late ButtonStyle style;
        late ColorScheme scheme;
        await tester.pumpWidget(
          hostWidget(
            Builder(
              builder: (context) {
                style = ordersClosedButtonStyle(context);
                scheme = Theme.of(context).colorScheme;
                return AppButton.outline(
                  'Chưa nhận đặt lịch',
                  onPressed: null,
                  style: style,
                );
              },
            ),
            brightness: b,
          ),
        );
        final secondary = b == Brightness.dark
            ? AppColorsDark.foregroundSecondary
            : AppColors.foregroundSecondary;
        expect(
          style.foregroundColor?.resolve({WidgetState.disabled}),
          secondary.withValues(alpha: 0.6),
        );
        expect(
          style.side?.resolve({WidgetState.disabled})?.color,
          scheme.outline.withValues(alpha: 0.6),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
