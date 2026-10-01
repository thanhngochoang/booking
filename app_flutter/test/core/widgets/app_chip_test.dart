import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Color _fill(WidgetTester tester) => tester
    .widget<Material>(
      find.descendant(
        of: find.byType(AppChip),
        matching: find.byType(Material),
      ),
    )
    .color!;

void main() {
  testWidgets('tapping reports the opposite of the current value', (
    tester,
  ) async {
    bool? seen;
    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'Cuối tuần',
          selected: false,
          onChanged: (v) => seen = v,
        ),
      ),
    );
    await tester.tap(find.text('Cuối tuần'));
    expect(seen, isTrue);

    await tester.pumpWidget(
      hostWidget(
        AppChip(label: 'Cuối tuần', selected: true, onChanged: (v) => seen = v),
      ),
    );
    await tester.tap(find.text('Cuối tuần'));
    expect(seen, isFalse);
  });

  testWidgets('selected filter chip is solid primary, context chip is subtle', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(AppChip(label: 'A', selected: true, onChanged: (_) {})),
    );
    expect(_fill(tester), AppColorsDark.primary);

    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'A',
          selected: true,
          kind: AppChipKind.context,
          onChanged: (_) {},
        ),
      ),
    );
    expect(_fill(tester), AppColorsDark.primarySubtle);

    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'A',
          selected: true,
          kind: AppChipKind.context,
          onChanged: (_) {},
        ),
        brightness: Brightness.light,
      ),
    );
    await tester.pumpAndSettle(); // the theme change animates
    expect(_fill(tester), AppColors.primarySubtle);
  });

  testWidgets('keeps a 48dp touch target around a 32dp pill', (tester) async {
    await tester.pumpWidget(
      hostWidget(AppChip(label: 'A', selected: false, onChanged: (_) {})),
    );
    expect(tester.getSize(find.byType(AppChip)).height, 48);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(AppChip),
              matching: find.byType(Material),
            ),
          )
          .height,
      32,
    );
  });

  testWidgets('semantics say button, selected and the label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        AppChip(label: 'Không thu phí', selected: true, onChanged: (_) {}),
      ),
    );
    final node = tester.getSemantics(find.byType(AppChip));
    expect(node.label, 'Không thu phí');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('a leading widget is shown before the label', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'Quận 1',
          selected: false,
          onChanged: (_) {},
          leading: const Icon(Icons.place_outlined, key: Key('lead')),
        ),
      ),
    );
    expect(find.byKey(const Key('lead')), findsOneWidget);
  });

  testWidgets('the whole 48dp box is the tap target, not just the pill', (
    tester,
  ) async {
    bool? seen;
    await tester.pumpWidget(
      hostWidget(
        AppChip(label: 'A', selected: false, onChanged: (v) => seen = v),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(AppChip)) + const Offset(24, 4),
    );
    expect(seen, isTrue);
  });

  testWidgets('a long label ellipsizes at 320dp and 1.3x without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'Một nhãn rất dài rất dài rất dài rất dài rất dài rất dài',
          selected: true,
          leading: const Icon(Icons.place_outlined),
          onChanged: (_) {},
        ),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppChip)).width, lessThanOrEqualTo(320));
  });

  testWidgets('stays 48dp tall inside a taller parent', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        SizedBox(
          height: 200,
          child: Align(
            alignment: Alignment.topLeft,
            child: AppChip(label: 'A', selected: false, onChanged: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppChip)).height, 48);
  });

  testWidgets('selected chip without leading shows a check', (tester) async {
    await tester.pumpWidget(
      hostWidget(AppChip(label: 'A', selected: true, onChanged: (_) {})),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.pumpWidget(
      hostWidget(AppChip(label: 'A', selected: false, onChanged: (_) {})),
    );
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'A',
          selected: true,
          onChanged: (_) {},
          leading: const Icon(Icons.place_outlined),
        ),
      ),
    );
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
  });
}
