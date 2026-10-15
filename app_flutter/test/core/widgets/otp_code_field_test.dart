// test/core/widgets/otp_code_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<List<String>> pump(
    WidgetTester tester, {
    String? errorText,
    double width = 390,
    double textScale = 1.0,
  }) async {
    final completed = <String>[];
    await tester.pumpWidget(
      hostWidget(
        OtpCodeField(
          controller: controller,
          labelText: 'Mã OTP',
          errorText: errorText,
          onCompleted: completed.add,
        ),
        width: width,
        textScale: textScale,
      ),
    );
    return completed;
  }

  testWidgets('accepts only 6 digits', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '12a3-45 6789');
    await tester.pump();
    expect(controller.text, '123456');
  });

  testWidgets('calls onCompleted at the 6th digit', (tester) async {
    final completed = await pump(tester);
    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    expect(completed, isEmpty);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(completed, ['123456']);
  });

  testWidgets('shows errorText', (tester) async {
    await pump(tester, errorText: 'Mã chưa đúng');
    expect(find.text('Mã chưa đúng'), findsOneWidget);
    expect(find.text('Mã OTP'), findsOneWidget);
  });

  testWidgets('has AutofillHints.oneTimeCode and a number keyboard', (
    tester,
  ) async {
    await pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(field.keyboardType, TextInputType.number);
    expect(
      field.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('fits 320 dp at 1.3× text', (tester) async {
    await pump(tester, width: 320, textScale: 1.3, errorText: 'Mã chưa đúng');
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
