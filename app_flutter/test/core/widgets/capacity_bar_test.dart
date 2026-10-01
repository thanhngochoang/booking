// test/core/widgets/capacity_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

double _fillFraction(WidgetTester tester) {
  final bar = tester.getSize(find.byKey(const Key('capacity-track'))).width;
  final fill = tester.getSize(find.byKey(const Key('capacity-fill'))).width;
  return fill / bar;
}

void main() {
  testWidgets('shows the text next to the bar', (tester) async {
    await tester.pumpWidget(hostWidget(const CapacityBar(used: 14, total: 20)));
    expect(find.text('14 / 20 đã đăng ký'), findsOneWidget);
    expect(_fillFraction(tester), closeTo(0.7, 0.001));
  });

  testWidgets('a custom label replaces the default text', (tester) async {
    await tester.pumpWidget(
      hostWidget(const CapacityBar(used: 3, total: 5, label: '3 / 5')),
    );
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.textContaining('đã đăng ký'), findsNothing);
  });

  testWidgets('over-full and empty totals stay inside the track', (
    tester,
  ) async {
    await tester.pumpWidget(hostWidget(const CapacityBar(used: 25, total: 20)));
    expect(_fillFraction(tester), 1.0);
    await tester.pumpWidget(hostWidget(const CapacityBar(used: 0, total: 0)));
    expect(find.byKey(const Key('capacity-fill')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the value is available to screen readers as text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const CapacityBar(used: 14, total: 20)));
    expect(find.bySemanticsLabel('14 / 20 đã đăng ký'), findsOneWidget);
    handle.dispose();
  });
}
