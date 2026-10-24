import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/features/delivery/report_delivery_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_dispute_repository.dart';

void main() {
  late FakeDisputeRepository disputes;

  final testBooking = makeTestBooking(
    id: 'b-report-1',
    status: BookingStatus.approved,
    photographerId: 'p1',
    customerId: 'c1',
  );

  setUp(() {
    disputes = FakeDisputeRepository(uid: 'c1');
  });

  Widget buildApp(Widget child) {
    return ProviderScope(
      overrides: [
        disputeRepositoryProvider.overrideWithValue(disputes),
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

    // Under 10 characters the server would refuse it: still disabled
    await tester.enterText(find.byType(TextField), 'Thiếu ảnh');
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(confirmBtnFinder).onPressed, isNull);

    // Enter text
    await tester.enterText(find.byType(TextField), '  Ảnh thiếu nhiều so với hợp đồng ');
    await tester.pumpAndSettle();

    // Now enabled
    expect(tester.widget<AppButton>(confirmBtnFinder).onPressed, isNotNull);

    // Confirm opens a dispute on the booking with the reason "other"
    await tester.tap(confirmBtnFinder);
    await tester.pumpAndSettle();

    final draft = disputes.opened.single;
    expect(draft.subjectType, DisputeSubjectType.booking);
    expect(draft.subjectId, 'b-report-1');
    expect(draft.reason, DisputeReason.other);
    expect(draft.description, 'Ảnh thiếu nhiều so với hợp đồng');
    expect(draft.evidencePaths, isEmpty);
    expect(draft.disputeId, isNotEmpty);
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

    final draft = disputes.opened.single;
    expect(draft.subjectId, 'b-report-1');
    expect(draft.reason, DisputeReason.photosMissing);
    expect(draft.description, 'Thiếu ảnh so với cam kết');
  });

  testWidgets('a refused dispute keeps the sheet open with the dispute copy', (tester) async {
    disputes.failWith = const DisputeError('conflict');
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
    await tester.tap(find.text('Link hỏng hoặc không truy cập được'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Báo vấn đề'));
    await tester.pumpAndSettle();

    expect(find.text('Đã có một khiếu nại đang mở cho khoản này.'), findsOneWidget);
    expect(find.text('Báo vấn đề với ảnh gốc'), findsOneWidget);

    // A second try sends the same dispute id (the server answers it idempotently).
    disputes.failWith = null;
    await tester.tap(find.widgetWithText(AppButton, 'Báo vấn đề'));
    await tester.pumpAndSettle();
    expect(disputes.opened, hasLength(2));
    expect(disputes.opened[1].disputeId, disputes.opened[0].disputeId);
    expect(disputes.opened[1].reason, DisputeReason.linkBroken);
  });
}
