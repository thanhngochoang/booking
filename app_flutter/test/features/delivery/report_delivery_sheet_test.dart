import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/delivery/report_delivery_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_booking_repository.dart';

void main() {
  late FakeBookingRepository fakeBookingRepo;

  final testBooking = makeTestBooking(
    id: 'b-report-1',
    status: BookingStatus.approved,
    photographerId: 'p1',
    customerId: 'c1',
  );

  setUp(() {
    fakeBookingRepo = FakeBookingRepository();
  });

  Widget buildApp(Widget child) {
    return ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('Báo vấn đề is red and disabled until a reason is picked', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportDeliverySheet(ctx, booking: testBooking),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Confirm sheet title
    expect(find.text('Báo vấn đề với ảnh gốc'), findsOneWidget);

    final confirmBtnFinder = find.widgetWithText(AppButton, 'Báo vấn đề');
    expect(confirmBtnFinder, findsOneWidget);

    // Initially disabled because no reason selected
    final appButton = tester.widget<AppButton>(confirmBtnFinder);
    expect(appButton.onPressed, isNull);

    // Pick first reason: "Link hỏng hoặc không truy cập được"
    await tester.tap(find.text('Link hỏng hoặc không truy cập được'));
    await tester.pumpAndSettle();

    final enabledBtn = tester.widget<AppButton>(confirmBtnFinder);
    expect(enabledBtn.onPressed, isNotNull);
  });

  testWidgets('Lý do khác requires text before button is enabled', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportDeliverySheet(ctx, booking: testBooking),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final confirmBtnFinder = find.widgetWithText(AppButton, 'Báo vấn đề');

    // Tap "Lý do khác"
    await tester.tap(find.text('Lý do khác'));
    await tester.pumpAndSettle();

    // Disabled because text input is empty
    expect(tester.widget<AppButton>(confirmBtnFinder).onPressed, isNull);

    // Enter text
    await tester.enterText(find.byType(TextField), 'Ảnh thiếu nhiều so với hợp đồng');
    await tester.pumpAndSettle();

    // Now enabled
    expect(tester.widget<AppButton>(confirmBtnFinder).onPressed, isNotNull);

    // Confirm submit calls openDispute
    await tester.tap(confirmBtnFinder);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.disputeCalls.length, 1);
    expect(fakeBookingRepo.disputeCalls.first.bookingId, 'b-report-1');
    expect(fakeBookingRepo.disputeCalls.first.reason, 'Ảnh thiếu nhiều so với hợp đồng');
  });

  testWidgets('Fixed reason calls openDispute with reason label', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportDeliverySheet(ctx, booking: testBooking),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thiếu ảnh so với cam kết'));
    await tester.pumpAndSettle();

    final confirmBtnFinder = find.widgetWithText(AppButton, 'Báo vấn đề');
    await tester.tap(confirmBtnFinder);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.disputeCalls.length, 1);
    expect(fakeBookingRepo.disputeCalls.first.bookingId, 'b-report-1');
    expect(fakeBookingRepo.disputeCalls.first.reason, 'Thiếu ảnh so với cam kết');
  });
}
