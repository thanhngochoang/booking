import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  Future<TextEditingController> pump(
    WidgetTester tester, {
    ValueChanged<String>? onChanged,
    GlobalKey<FormState>? form,
  }) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      hostWidget(
        Form(
          key: form,
          child: PhoneField(controller: c, onChanged: onChanged),
        ),
      ),
    );
    return c;
  }

  testWidgets('typing groups digits as 903 123 456', (tester) async {
    final c = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '903123456');
    expect(c.text, '903 123 456');
  });

  testWidgets(
    'a pasted 0903… or +84… number is turned into the national form',
    (tester) async {
      final c = await pump(tester);
      await tester.enterText(find.byType(TextFormField), '0903123456');
      expect(c.text, '903 123 456');
      await tester.enterText(find.byType(TextFormField), '+84 903 123 456');
      expect(c.text, '903 123 456');
    },
  );

  testWidgets('letters are dropped and input stops at nine digits', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '90a31234567890');
    expect(c.text, '903 123 456');
  });

  testWidgets('uses the phone keyboard and shows the label', (tester) async {
    await pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.phone);
    expect(find.text('Số điện thoại'), findsOneWidget);
  });

  testWidgets('validation message is specific and sits under the field', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    await pump(tester, form: form);
    await tester.enterText(find.byType(TextFormField), '90312345');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('Số điện thoại chưa đúng. Ví dụ: 903 123 456'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), '903123456');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('onChanged receives the formatted text', (tester) async {
    String? last;
    await pump(tester, onChanged: (v) => last = v);
    await tester.enterText(find.byType(TextFormField), '0903123456');
    expect(last, '903 123 456');
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    final c = TextEditingController(text: '903 123 456');
    addTearDown(c.dispose);
    await tester.pumpWidget(
      hostWidget(PhoneField(controller: c), width: 320, textScale: 1.3),
    );
    expect(tester.takeException(), isNull);
  });
}
