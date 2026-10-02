import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  Finder button(Type t) =>
      find.descendant(of: find.byType(AppButton), matching: find.byType(t));

  for (final (name, size, h) in [
    ('regular', AppButtonSize.regular, controlHeight),
    ('small', AppButtonSize.small, 38.0),
    ('xsmall', AppButtonSize.xsmall, 30.0),
  ]) {
    testWidgets('$name primary is ${h}dp tall with a 48dp hit area', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        hostWidget(
          AppButton.primary('Đặt', size: size, onPressed: () => taps++),
        ),
      );
      expect(tester.getSize(button(FilledButton)).height, h);
      final outer = tester.getRect(find.byType(AppButton));
      expect(outer.height, greaterThanOrEqualTo(48));
      expect(outer.width, greaterThanOrEqualTo(48));
      // Tap in the padding above the visual button.
      await tester.tapAt(Offset(outer.center.dx, outer.top + 2));
      expect(taps, 1);
      await tester.tap(find.text('Đặt'));
      expect(taps, 2);
    });

    testWidgets('$name outline and text keep their height', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          Column(
            children: [
              AppButton.outline('A', size: size, onPressed: () {}),
              AppButton.text('B', size: size, onPressed: () {}),
            ],
          ),
        ),
      );
      if (size != AppButtonSize.regular) {
        expect(tester.getSize(button(OutlinedButton)).height, h);
        expect(tester.getSize(button(TextButton)).height, h);
      } else {
        expect(tester.getSize(button(OutlinedButton)).height, h);
      }
    });
  }

  testWidgets('xsmall is not stretched in a wide parent; small is', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        Column(
          children: [
            AppButton.outline(
              'Nhỏ',
              size: AppButtonSize.xsmall,
              onPressed: () {},
            ),
            AppButton.outline(
              'Vừa',
              size: AppButtonSize.small,
              onPressed: () {},
            ),
          ],
        ),
        width: 390,
      ),
    );
    final x = tester.getSize(button(OutlinedButton).first);
    final s = tester.getSize(button(OutlinedButton).last);
    expect(x.width, lessThan(200));
    expect(s.width, 390);
  });

  testWidgets('loading keeps the label semantics at every size', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        AppButton.primary(
          'Đặt',
          size: AppButtonSize.xsmall,
          loading: true,
          onPressed: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Đặt'), findsOneWidget);
    handle.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('320dp x1.3 does not overflow (${b.name})', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          Column(
            children: [
              for (final s in AppButtonSize.values)
                AppButton.primary(
                  'Xác nhận đặt lịch chụp ảnh',
                  size: s,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  onPressed: () {},
                ),
            ],
          ),
          width: 320,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(AppButton).last).right,
        lessThanOrEqualTo(320),
      );
    });
  }

  group('compact text and shape follow the size', () {
    TextStyle paint(WidgetTester tester, String label) =>
        tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

    for (final (size, font, radius) in [
      (AppButtonSize.small, AppText.sm, AppRadius.control),
      (AppButtonSize.xsmall, AppText.xs2, AppRadius.lg),
    ]) {
      testWidgets('${size.name}: every kind uses the brand font at $font', (
        tester,
      ) async {
        await tester.pumpWidget(
          hostWidget(
            Column(
              children: [
                AppButton.primary('P', size: size, onPressed: () {}),
                AppButton.outline('O', size: size, onPressed: () {}),
                AppButton.text('T', size: size, onPressed: () {}),
              ],
            ),
          ),
        );
        for (final l in ['P', 'O', 'T']) {
          final st = paint(tester, l);
          expect(st.fontSize, font, reason: l);
          expect(st.fontFamily, AppFonts.body, reason: l);
        }
      });

      testWidgets('${size.name}: the gradient has radius $radius', (
        tester,
      ) async {
        await tester.pumpWidget(
          hostWidget(AppButton.primary('P', size: size, onPressed: () {})),
        );
        final cta = tester.widget<CtaSurface>(find.byType(CtaSurface));
        expect(cta.borderRadius, BorderRadius.circular(radius));
      });
    }
  });
}
