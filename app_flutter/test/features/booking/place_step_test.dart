// test/features/booking/place_step_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/booking/steps/place_step.dart';

import '../../support/booking_world.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5);
  final freeDay = DateTime.utc(2026, 10, 15);
  final testDays = {
    freeDay: AvailabilityDay(day: freeDay, state: DayState.free),
  };

  Future<void> navigateToPlaceStep(WidgetTester tester, {String path = '/u/p1/book?serviceId=s1'}) async {
    await pumpBookingRoute(
      tester,
      path: path,
      days: testDays,
      now: now,
    );
    await tester.pumpAndSettle();

    // On DateTimeStep: select day 15 and first slot
    await tester.tap(find.bySemanticsLabel('15 tháng 10, rảnh'));
    await tester.pumpAndSettle();

    final slotChip = find.widgetWithText(AppChip, '06:00');
    await tester.ensureVisible(slotChip);
    await tester.tap(slotChip);
    await tester.pumpAndSettle();

    final continueBtn = find.widgetWithText(AppButton, 'Tiếp tục · 1.500.000₫');
    await tester.ensureVisible(continueBtn);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    expect(find.byType(PlaceStep), findsOneWidget);
  }

  testWidgets('Tiếp tục stays disabled under 3 characters and shows the hint after editing', (tester) async {
    await navigateToPlaceStep(tester);

    final continueBtn = find.widgetWithText(AppButton, 'Tiếp tục · 1.500.000₫');
    expect(tester.widget<AppButton>(continueBtn).onPressed, isNull);

    // Initial state: no error shown
    expect(find.text('Nhập ít nhất 3 ký tự'), findsNothing);

    // Enter 2 chars
    final input = find.byType(TextField);
    await tester.enterText(input, 'SG');
    await tester.pumpAndSettle();

    expect(find.text('Nhập ít nhất 3 ký tự'), findsOneWidget);
    expect(tester.widget<AppButton>(continueBtn).onPressed, isNull);

    // Enter 3 chars -> valid
    await tester.enterText(input, 'Sài');
    await tester.pumpAndSettle();

    expect(find.text('Nhập ít nhất 3 ký tự'), findsNothing);
    expect(tester.widget<AppButton>(continueBtn).onPressed, isNotNull);

    // Backspace to 2 chars -> error shown again
    await tester.enterText(input, 'S');
    await tester.pumpAndSettle();

    expect(find.text('Nhập ít nhất 3 ký tự'), findsOneWidget);
    expect(tester.widget<AppButton>(continueBtn).onPressed, isNull);
  });

  testWidgets('a suggestion chip fills the field and enables Tiếp tục', (tester) async {
    await navigateToPlaceStep(tester);

    final continueBtn = find.widgetWithText(AppButton, 'Tiếp tục · 1.500.000₫');
    expect(tester.widget<AppButton>(continueBtn).onPressed, isNull);

    // Photographer summary area is 'Quận 3'
    final chip = find.widgetWithText(AppChip, 'Quận 3');
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Quận 3'), findsOneWidget);
    expect(tester.widget<AppButton>(continueBtn).onPressed, isNotNull);
  });

  testWidgets('the S02.06 area is offered as a chip', (tester) async {
    await navigateToPlaceStep(tester, path: '/u/p1/book?serviceId=s1&area=Th%E1%BA%A3o%20C%E1%BA%A7m%20Vi%C3%AAn');

    expect(find.widgetWithText(AppChip, 'Thảo Cầm Viên'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'Quận 3'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppChip, 'Thảo Cầm Viên'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Thảo Cầm Viên'), findsOneWidget);
    final continueBtn = find.widgetWithText(AppButton, 'Tiếp tục · 1.500.000₫');
    expect(tester.widget<AppButton>(continueBtn).onPressed, isNotNull);
  });

  testWidgets('the field stops at 120 characters', (tester) async {
    await navigateToPlaceStep(tester);

    final longText = 'A' * 150;
    final input = find.byType(TextField);
    await tester.enterText(input, longText);
    await tester.pumpAndSettle();

    final tf = tester.widget<TextField>(input);
    expect(tf.controller?.text.length, 120);
    expect(tf.controller?.text, 'A' * 120);
  });
}
