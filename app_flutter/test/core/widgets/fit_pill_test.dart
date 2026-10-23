// test/core/widgets/fit_pill_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/fit_pill.dart';

import 'widget_host.dart';

void main() {
  testWidgets('shows Hợp 92% and announces it', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const FitPill(percent: 92)),
    );

    expect(find.text('Hợp 92%'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Hợp 92%'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
