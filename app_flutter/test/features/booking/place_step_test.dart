// test/features/booking/place_step_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/booking/steps/place_step.dart';

import '../../support/booking_world.dart';
import '../../support/spot_booking_fixtures.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';

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

  group('S04.06 with add-ons', () {
    /// S04.01 with the portrait package preselected: picks [car] (and makeup
    /// ×1), then S04.02 → S04.06.
    Future<void> toPlace(WidgetTester tester, {required bool car}) async {
      await pumpBookingRoute(
        tester,
        packages: [bookingPortrait2h],
        addons: <ServiceAddon>[addonMakeup, addonTransport],
        days: testDays,
        now: now,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.ensureVisible(find.byKey(const Key('addon-a_makeup-plus')));
      await tester.tap(find.byKey(const Key('addon-a_makeup-plus')));
      await tester.pump();
      if (car) {
        await tester.ensureVisible(find.byKey(const Key('addon-a_car-check')));
        await tester.tap(find.byKey(const Key('addon-a_car-check')));
        await tester.pump();
      }
      final total = car ? '2.600.000₫' : '2.300.000₫';
      await tester.tap(find.widgetWithText(AppButton, 'Tiếp tục · $total'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('15 tháng 10, rảnh'));
      await tester.pumpAndSettle();
      final slotChip = find.widgetWithText(AppChip, '06:00');
      await tester.ensureVisible(slotChip);
      await tester.tap(slotChip);
      await tester.pumpAndSettle();
      final next = find.widgetWithText(AppButton, 'Tiếp tục · $total');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byType(PlaceStep), findsOneWidget);
    }

    testWidgets('pickup field and lock note show only with transport', (
      tester,
    ) async {
      await toPlace(tester, car: true);
      expect(find.text('Điểm đón'), findsWidgets);
      expect(find.text('Xe đón trong nội thành'), findsOneWidget);
      expect(find.byKey(const Key('book-pickup-field')), findsOneWidget);
      expect(find.text('Chỉ thợ chụp cho bạn thấy điểm đón.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await toPlace(tester, car: false);
      expect(find.byKey(const Key('book-pickup-field')), findsNothing);
      expect(find.text('Chỉ thợ chụp cho bạn thấy điểm đón.'), findsNothing);
    });

    testWidgets('Tiếp tục waits for a pickup of 3 characters; chips fill it', (
      tester,
    ) async {
      await toPlace(tester, car: true);
      final next = find.widgetWithText(AppButton, 'Tiếp tục · 2.600.000₫');
      await tester.enterText(
        find.byType(TextField).first,
        'Bến Bạch Đằng, Quận 1',
      );
      await tester.pump();
      expect(tester.widget<AppButton>(next).onPressed, isNull);

      await tester.ensureVisible(find.byKey(const Key('book-pickup-chip-Quận 3')));
      await tester.tap(find.byKey(const Key('book-pickup-chip-Quận 3')));
      await tester.pump();
      expect(
        find.widgetWithText(TextField, 'Quận 3'),
        findsOneWidget,
      );
      expect(tester.widget<AppButton>(next).onPressed, isNotNull);
    });

    testWidgets('pickup shorter than 3 characters shows bookPlaceTooShort', (
      tester,
    ) async {
      await toPlace(tester, car: true);
      await tester.enterText(find.byKey(const Key('book-pickup-field')), 'Ga');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('book-pickup-field')),
          matching: find.text('Nhập ít nhất 3 ký tự'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the step reports screen code S04.06', (tester) async {
      await toPlace(tester, car: true);
      expect(
        find.ancestor(
          of: find.byKey(const Key('book-pickup-field')),
          matching: find.byWidgetPredicate(
            (w) => w is ScreenCode && w.code == 'S04.06',
          ),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'spot context shows the locked field and the note; pickup still appears with transport',
    (tester) async {
      await walkSpotPackage(tester, until: BookingStep.place, car: true);

      final place = tester.widget<TextField>(
        find.byKey(const Key('book-place-locked')),
      );
      expect(place.controller!.text, 'Hồ Tây');
      expect(place.readOnly, isTrue);
      expect(find.text('Địa điểm là điểm chụp, không đổi được.'), findsOneWidget);
      // Suggestions are for the pickup only.
      expect(find.widgetWithText(AppChip, 'Quận 3'), findsOneWidget);
      expect(find.byKey(const Key('book-pickup-chip-Quận 3')), findsOneWidget);
      expect(find.byKey(const Key('book-pickup-field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('book-pickup-field')),
        'Ga Hà Nội',
      );
      await tester.pump();
      final next = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Tiếp tục · 1.800.000₫'),
      );
      expect(next.onPressed, isNotNull);
    },
  );
}
