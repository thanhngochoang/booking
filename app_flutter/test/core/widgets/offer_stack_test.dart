// test/core/widgets/offer_stack_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

List<Widget> _cards(int n) => [
  for (var i = 1; i <= n; i++)
    SizedBox(key: Key('card-$i'), height: 120, child: Text('Thẻ $i')),
];

Future<void> _pump(WidgetTester tester, int n) => tester.pumpWidget(
  hostWidget(
    Padding(
      padding: const EdgeInsets.only(top: 40),
      child: OfferStack(offers: _cards(n)),
    ),
  ),
);

void main() {
  testWidgets('shows one full card and two edges for three offers', (
    tester,
  ) async {
    await _pump(tester, 3);

    expect(find.text('Thẻ 1'), findsOneWidget);
    // The next two are edges only, never their content.
    expect(find.text('Thẻ 2'), findsNothing);
    expect(find.text('Thẻ 3'), findsNothing);
    final edge1 = find.byKey(const Key('offer-edge-1'));
    final edge2 = find.byKey(const Key('offer-edge-2'));
    expect(edge1, findsOneWidget);
    expect(edge2, findsOneWidget);

    // Mock `.ostk`: each edge peeks above the card, the second one higher
    // and narrower.
    final card = tester.getRect(find.byKey(const Key('card-1')));
    final r1 = tester.getRect(edge1);
    final r2 = tester.getRect(edge2);
    expect(r1.top, lessThan(card.top));
    expect(r2.top, lessThan(r1.top));
    expect(r1.width, lessThan(card.width));
    expect(r2.width, lessThan(r1.width));
  });

  testWidgets('one offer shows no edges', (tester) async {
    await _pump(tester, 1);

    expect(find.text('Thẻ 1'), findsOneWidget);
    expect(find.byKey(const Key('offer-edge-1')), findsNothing);
    expect(find.byKey(const Key('offer-edge-2')), findsNothing);
  });

  testWidgets('two offers show one edge', (tester) async {
    await _pump(tester, 2);

    expect(find.byKey(const Key('offer-edge-1')), findsOneWidget);
    expect(find.byKey(const Key('offer-edge-2')), findsNothing);
  });

  testWidgets('more than three shows three', (tester) async {
    await _pump(tester, 5);

    expect(find.text('Thẻ 1'), findsOneWidget);
    expect(find.byKey(const Key('offer-edge-1')), findsOneWidget);
    expect(find.byKey(const Key('offer-edge-2')), findsOneWidget);
    expect(find.byKey(const Key('offer-edge-3')), findsNothing);
  });

  testWidgets('no offers draw nothing', (tester) async {
    await _pump(tester, 0);

    expect(find.byKey(const Key('offer-edge-1')), findsNothing);
    expect(tester.getSize(find.byType(OfferStack)).height, 0);
  });

  testWidgets(
    'the space for the edges is part of the stack (no overlap above)',
    (tester) async {
      await _pump(tester, 3);

      final stack = tester.getRect(find.byType(OfferStack));
      final edge2 = tester.getRect(find.byKey(const Key('offer-edge-2')));
      expect(edge2.top, greaterThanOrEqualTo(stack.top));
    },
  );
}
