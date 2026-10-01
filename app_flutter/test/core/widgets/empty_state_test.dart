import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/empty_state.dart';

void main() {
  testWidgets('shows title, body and calls action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'Tiêu đề',
            body: 'Nội dung',
            actionLabel: 'Làm gì đó',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('Tiêu đề'), findsOneWidget);
    expect(find.text('Nội dung'), findsOneWidget);
    await tester.tap(find.text('Làm gì đó'));
    expect(tapped, isTrue);
  });
  testWidgets('hides the button when there is no action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(title: 'a', body: 'b'),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });
}
