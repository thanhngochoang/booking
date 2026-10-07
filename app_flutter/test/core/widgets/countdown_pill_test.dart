// test/core/widgets/countdown_pill_test.dart
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('14:32 left reads "Còn 14:32"', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const CountdownPill(remaining: Duration(minutes: 14, seconds: 32)),
      ),
    );

    expect(find.text('Còn 14:32'), findsOneWidget);
  });

  testWidgets('seconds are zero-padded', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const CountdownPill(remaining: Duration(minutes: 3, seconds: 5)),
      ),
    );

    expect(find.text('Còn 03:05'), findsOneWidget);
  });

  testWidgets('zero reads "Hết hạn"', (tester) async {
    await tester.pumpWidget(
      hostWidget(const CountdownPill(remaining: Duration.zero)),
    );

    expect(find.text('Hết hạn'), findsOneWidget);
    expect(find.textContaining('Còn'), findsNothing);
  });

  Future<SemanticsNode> pillNode(
    WidgetTester tester,
    Duration d,
    String label,
  ) async {
    await tester.pumpWidget(hostWidget(CountdownPill(remaining: d)));
    return tester.getSemantics(find.bySemanticsLabel(label));
  }

  testWidgets('semantics reads "QR còn hiệu lực 14 phút 32 giây", not live', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final node = await pillNode(
      tester,
      const Duration(minutes: 14, seconds: 32),
      'QR còn hiệu lực 14 phút 32 giây',
    );
    expect(node.flagsCollection.isLiveRegion, isFalse);
    handle.dispose();
  });

  testWidgets('live region at the announce thresholds (5 min, 1 min, 10 s)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final (d, label) in [
      (const Duration(minutes: 5), 'QR còn hiệu lực 5 phút 0 giây'),
      (const Duration(minutes: 1), 'QR còn hiệu lực 1 phút 0 giây'),
      (const Duration(seconds: 10), 'QR còn hiệu lực 0 phút 10 giây'),
    ]) {
      final node = await pillNode(tester, d, label);
      expect(node.flagsCollection.isLiveRegion, isTrue, reason: label);
    }
    handle.dispose();
  });

  testWidgets('live region when it reaches zero', (tester) async {
    final handle = tester.ensureSemantics();
    final node = await pillNode(tester, Duration.zero, 'QR đã hết hạn');
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('not live one second past a threshold', (tester) async {
    final handle = tester.ensureSemantics();
    final node = await pillNode(
      tester,
      const Duration(minutes: 4, seconds: 59),
      'QR còn hiệu lực 4 phút 59 giây',
    );
    expect(node.flagsCollection.isLiveRegion, isFalse);
    handle.dispose();
  });
}
