import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Blur is the most expensive effect on a phone. A screen may have at most
/// [max] BackdropFilters, and none may sit inside another one (a card in a
/// blurred panel must use a translucent fill, not blur again).
void expectBlurBudget({int max = 4}) {
  final all = find.byType(BackdropFilter).evaluate().length;
  expect(
    all,
    lessThanOrEqualTo(max),
    reason: '$all BackdropFilters; the budget is $max per screen',
  );
  final nested = find.descendant(
    of: find.byType(BackdropFilter),
    matching: find.byType(BackdropFilter),
  );
  expect(
    nested,
    findsNothing,
    reason: 'a BackdropFilter inside another BackdropFilter',
  );
}
