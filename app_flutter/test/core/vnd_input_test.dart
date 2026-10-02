import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/vnd_input.dart';

void main() {
  test('parseVnd reads the digits only', () {
    expect(parseVnd('3.200.000'), 3200000);
    expect(parseVnd(' 1500000 ₫'), 1500000);
    expect(parseVnd(''), isNull);
    expect(parseVnd('abc'), isNull);
    expect(parseVnd('12345678901'), isNull, reason: 'more than 10 digits');
  });

  test('groupVnd groups thousands with dots', () {
    expect(groupVnd(1500000), '1.500.000');
    expect(groupVnd(500), '500');
    expect(groupVnd(0), '0');
  });

  testWidgets('VndInputFormatter keeps a money field grouped', (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: TextField(
            controller: c,
            inputFormatters: const [VndInputFormatter()],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '3200000');
    expect(c.text, '3.200.000');
    await tester.enterText(find.byType(TextField), '00a15');
    expect(c.text, '15');
    await tester.enterText(find.byType(TextField), '123456789012');
    expect(c.text, '1.234.567.890');
    await tester.enterText(find.byType(TextField), '');
    expect(c.text, '');
  });
}
