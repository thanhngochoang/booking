import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/review/widgets/star_rating.dart';

void main() {
  group('StarRating', () {
    testWidgets('tap selects the tapped star', (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => StarRating(
                value: selected,
                onChanged: (v) => setState(() => selected = v),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('star_4')));
      await tester.pump();
      expect(selected, 4);

      await tester.tap(find.byKey(const Key('star_2')));
      await tester.pump();
      expect(selected, 2);
    });

    testWidgets('dragging across selects continuously', (tester) async {
      final history = <int>[];
      int current = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => StarRating(
                  value: current,
                  size: 40,
                  onChanged: (v) {
                    setState(() => current = v);
                    history.add(v);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byKey(const Key('star_1')));
      final gesture = await tester.startGesture(topLeft);
      // Drag across to star 5
      await gesture.moveBy(const Offset(180, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(history, isNotEmpty);
      expect(current, greaterThan(1));
    });

    testWidgets('semantics expose a slider with increase/decrease', (tester) async {
      final handle = tester.ensureSemantics();
      int value = 3;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => StarRating(
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(StarRating));
      expect(node.getSemanticsData().flagsCollection.isSlider, isTrue);
      expect(node.value, '3 trên 5 sao');
      expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);

      handle.dispose();
    });

    testWidgets('read-only ignores taps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(
              value: 4,
              onChanged: null,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('star_1')));
      await tester.pump();

      // Remains 4 stars filled
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });
  });
}
