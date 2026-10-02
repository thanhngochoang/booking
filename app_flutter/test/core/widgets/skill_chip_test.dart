import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('a context-kind chip that reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      hostWidget(
        SkillChip(label: 'Chân dung', selected: true, onTap: () => taps++),
      ),
    );
    expect(
      tester.widget<AppChip>(find.byType(AppChip)).kind,
      AppChipKind.context,
    );
    expect(tester.widget<AppChip>(find.byType(AppChip)).selected, isTrue);
    await tester.tap(find.text('Chân dung'));
    expect(taps, 1);
  });

  testWidgets('at the limit: dimmed, hint read out, taps still reported', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      hostWidget(
        SkillChip(
          label: 'Cưới',
          selected: false,
          disabled: true,
          onTap: () => taps++,
        ),
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(SkillChip),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.5);
    expect(
      tester.getSemantics(find.byType(SkillChip)),
      isSemantics(label: 'Cưới', hint: 'Đã đủ số lượng', isButton: true),
    );
    await tester.tap(find.text('Cưới'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a selected chip is never dimmed', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        SkillChip(label: 'Cưới', selected: true, disabled: true, onTap: () {}),
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(SkillChip),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1);
  });

  testWidgets('no blur inside a chip; fits 320dp at 1.3x in both themes', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        hostWidget(
          Wrap(
            children: [
              for (final l in [
                'Người ngại ống kính',
                'Gia đình có bé nhỏ',
                'Chỉ đạo tạo dáng',
                'Ánh sáng tự nhiên',
              ])
                SkillChip(
                  label: l,
                  selected: l.length.isEven,
                  disabled: true,
                  onTap: () {},
                ),
            ],
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
