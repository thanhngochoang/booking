// test/core/widgets/countdown_pill_test.dart
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

  testWidgets('semantics is a live region "QR còn hiệu lực 14 phút 32 giây"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        const CountdownPill(remaining: Duration(minutes: 14, seconds: 32)),
      ),
    );

    final node = tester.getSemantics(
      find.bySemanticsLabel('QR còn hiệu lực 14 phút 32 giây'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });
}
