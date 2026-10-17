import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _stepper({
  int value = 2,
  int min = 1,
  int max = 4,
  String keyPrefix = 'qty',
  String label = '2 người',
  ValueChanged<int>? onChanged,
}) => hostWidget(
  QtyStepper(
    value: value,
    min: min,
    max: max,
    keyPrefix: keyPrefix,
    valueLabel: label,
    decrementLabel: 'Bớt một',
    incrementLabel: 'Thêm một',
    onChanged: onChanged ?? (_) {},
  ),
);

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  testWidgets('minus disabled at min, plus disabled at max', (tester) async {
    await tester.pumpWidget(_stepper(value: 1));
    expect(_enabled(tester, 'qty-minus'), isFalse);
    expect(_enabled(tester, 'qty-plus'), isTrue);

    await tester.pumpWidget(_stepper(value: 4));
    expect(_enabled(tester, 'qty-minus'), isTrue);
    expect(_enabled(tester, 'qty-plus'), isFalse);
  });

  testWidgets('taps call onChanged with value ∓ 1', (tester) async {
    final seen = <int>[];
    await tester.pumpWidget(_stepper(value: 2, onChanged: seen.add));
    await tester.tap(find.byKey(const Key('qty-minus')));
    await tester.tap(find.byKey(const Key('qty-plus')));
    expect(seen, [1, 3]);
  });

  testWidgets('keys use keyPrefix (register-minus, register-quantity, '
      'register-plus)', (tester) async {
    await tester.pumpWidget(_stepper(keyPrefix: 'register'));
    expect(find.byKey(const Key('register-minus')), findsOneWidget);
    expect(find.byKey(const Key('register-quantity')), findsOneWidget);
    expect(find.byKey(const Key('register-plus')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('value is announced through valueLabel', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_stepper(label: '2 người'));
    expect(find.bySemanticsLabel('2 người'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('enabled false disables both buttons', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        QtyStepper(
          value: 2,
          max: 4,
          enabled: false,
          valueLabel: '2',
          decrementLabel: '-',
          incrementLabel: '+',
          onChanged: (_) {},
        ),
      ),
    );
    expect(_enabled(tester, 'qty-minus'), isFalse);
    expect(_enabled(tester, 'qty-plus'), isFalse);
  });
}
