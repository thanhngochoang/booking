// test/support/idle.dart
import 'package:flutter_test/flutter_test.dart';

/// Fails when something keeps scheduling frames at rest (a running
/// animation, ticker or repeating timer drains battery).
Future<void> expectIdle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  expect(
    tester.binding.transientCallbackCount,
    0,
    reason: 'an animation or ticker keeps running at rest',
  );
  expect(
    tester.binding.hasScheduledFrame,
    isFalse,
    reason: 'a frame is scheduled while nothing changes',
  );
}
