import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Color? _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(VerdictBadge),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color;
}

Color? _text(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining('×')).style?.color;

void main() {
  testWidgets('shows the icon and ×10, read as "Cà chua, 10 trên 10"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const VerdictBadge(kind: VerdictKind.tomato, hits: 10)),
    );
    expect(find.text('×10'), findsOneWidget);
    expect(find.byType(VerdictIcon), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(VerdictBadge)),
      matchesSemantics(label: 'Cà chua, 10 trên 10'),
    );
    handle.dispose();
  });

  testWidgets('brick reads "Gạch, 3 trên 10"', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const VerdictBadge(kind: VerdictKind.brick, hits: 3)),
    );
    expect(find.text('×3'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(VerdictBadge)),
      matchesSemantics(label: 'Gạch, 3 trên 10'),
    );
    handle.dispose();
  });

  testWidgets('brick colour differs from tomato, fill is a soft tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const VerdictBadge(kind: VerdictKind.tomato, hits: 5)),
    );
    final tomatoText = _text(tester);
    final tomatoFill = _fill(tester);
    await tester.pumpWidget(
      hostWidget(const VerdictBadge(kind: VerdictKind.brick, hits: 5)),
    );
    expect(tomatoText, AppColorsDark.tomato);
    expect(_text(tester), AppColorsDark.brick);
    expect(_text(tester), isNot(tomatoText));
    expect(_fill(tester), isNot(tomatoFill));
    expect(_fill(tester)!.a, lessThan(0.3));
  });

  testWidgets('light theme uses the light tokens', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const VerdictBadge(kind: VerdictKind.tomato, hits: 5),
        brightness: Brightness.light,
      ),
    );
    expect(_text(tester), AppColors.tomato);
  });

  for (final b in Brightness.values) {
    testWidgets('golden: both kinds, ${b.name}', tags: ['golden'], (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(220, 64));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        hostWidget(
          RepaintBoundary(
            key: const Key('golden'),
            child: Container(
              color: b == Brightness.dark
                  ? AppColorsDark.background
                  : AppColors.background,
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VerdictBadge(kind: VerdictKind.tomato, hits: 10),
                  SizedBox(width: 12),
                  VerdictBadge(kind: VerdictKind.brick, hits: 3),
                ],
              ),
            ),
          ),
          brightness: b,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('golden')),
        matchesGoldenFile('goldens/verdict_badge_${b.name}.png'),
      );
    });
  }
}
