import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/booking/late_cancel_sheet.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/screen_host.dart';

final _shotAt = DateTime.utc(2026, 10, 12, 10, 30);
final _lateNow = DateTime.utc(2026, 10, 20, 10, 30);

Booking _lateBooking({int deposit = 1500000, int? depositRefunded}) =>
    makeTestBooking(
      id: 'b1',
      status: BookingStatus.shot,
      deposit: deposit,
      remaining: 0,
      serviceSnapshot: BookingServiceSnapshot(
        name: 'Chân dung 2 giờ',
        price: deposit,
        durationMinutes: 120,
      ),
    ).copyWith(
      shotAt: _shotAt,
      deliveryDays: 5,
      depositRefunded: depositRefunded,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _sheet = find.byKey(const Key('app-sheet'));
Finder _inSheet(Finder f) => find.descendant(of: _sheet, matching: f);

void main() {
  testWidgets(
    'rows show milestone 2 amount and milestone 1 amount from BookingMilestones; without milestones shows 50/50 of deposit − depositRefunded',
    (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_lateBooking());
      await tester.pumpWidget(
        screenApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showLateCancelSheet(
                    context,
                    booking: _lateBooking(),
                    providerName: 'Lan Anh',
                    milestones: const BookingMilestones(
                      shootAmount: 600000,
                      deliveryAmount: 900000,
                      shootStatus: 'released',
                      deliveryStatus: 'held',
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);

      expect(
        _inSheet(
          find.byWidgetPredicate(
            (w) => w is ScreenCode && w.code == ScreenCodes.cancelLateDelivery,
          ),
        ),
        findsOneWidget,
      );
      expect(_inSheet(find.text('Huỷ phần bàn giao?')), findsOneWidget);
      expect(_inSheet(find.text('Hoàn mốc 2 cho bạn')), findsOneWidget);
      expect(_inSheet(find.text('900.000₫')), findsOneWidget);
      expect(
        _inSheet(find.text('Lan Anh giữ mốc 1 (buổi chụp)')),
        findsOneWidget,
      );
      expect(_inSheet(find.text('600.000₫')), findsOneWidget);

      await tester.tap(_inSheet(find.byKey(const Key('late-cancel-wait'))));
      await _settle(tester);

      // Without milestones: 50/50 of deposit - depositRefunded (1.200.000 - 200.000 = 1.000.000 -> 500.000 each).
      await tester.pumpWidget(
        screenApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showLateCancelSheet(
                    context,
                    booking: _lateBooking(
                      deposit: 1200000,
                      depositRefunded: 200000,
                    ),
                    providerName: 'Lan Anh',
                  ),
                  child: const Text('open-fallback'),
                ),
              ),
            ),
          ),
          overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.tap(find.text('open-fallback'));
      await _settle(tester);

      expect(_inSheet(find.text('500.000₫')), findsNWidgets(2));
    },
  );

  testWidgets(
    '"Chờ thêm" returns LateCancelOutcome.kept; "Huỷ phần bàn giao" (AppColors.error) calls cancelLateDelivery once and returns cancelled',
    (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_lateBooking());
      LateCancelOutcome? result;
      await tester.pumpWidget(
        screenApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showLateCancelSheet(
                      context,
                      booking: _lateBooking(),
                      providerName: 'Lan Anh',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.tap(_inSheet(find.text('Chờ thêm')));
      await _settle(tester);
      expect(result, LateCancelOutcome.kept);
      expect(repo.cancelLateCalls, isEmpty);

      await tester.tap(find.text('open'));
      await _settle(tester);
      final confirmBtn = _inSheet(find.byKey(const Key('late-cancel-confirm')));
      final filled = tester.widget<FilledButton>(
        find.descendant(of: confirmBtn, matching: find.byType(FilledButton)),
      );
      expect(
        filled.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.error,
      );

      await tester.tap(confirmBtn);
      await _settle(tester);
      expect(result, LateCancelOutcome.cancelled);
      expect(repo.cancelLateCalls, ['b1']);
    },
  );

  testWidgets(
    'alreadyDelivered closes the sheet and S05.02 toasts lateCancelAlreadyDelivered',
    (tester) async {
      final repo = RecordingBookingRepository()
        ..seedBooking(_lateBooking())
        ..nextError = BookingErrorCode.alreadyDelivered;
      await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        now: _lateNow,
        bookings: repo,
      );
      await _settle(tester);

      final open = find.byKey(const Key('late-delivery-cancel'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await _settle(tester);
      expect(_sheet, findsOneWidget);

      await tester.tap(_inSheet(find.byKey(const Key('late-cancel-confirm'))));
      await _settle(tester);

      expect(_sheet, findsNothing);
      expect(
        find.text(
          'Minh Trí vừa nộp bàn giao. Xem bàn giao trước khi quyết định.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('notLate closes and toasts lateCancelNotLate', (tester) async {
    final repo = RecordingBookingRepository()
      ..seedBooking(_lateBooking())
      ..nextError = BookingErrorCode.notLate;
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      now: _lateNow,
      bookings: repo,
    );
    await _settle(tester);

    final open = find.byKey(const Key('late-delivery-cancel'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _settle(tester);

    await tester.tap(_inSheet(find.byKey(const Key('late-cancel-confirm'))));
    await _settle(tester);

    expect(_sheet, findsNothing);
    expect(find.text('Chưa quá hạn bàn giao.'), findsOneWidget);
  });

  testWidgets(
    'a not_eligible refusal (the booking already completed, e.g. after a lost response) closes the sheet and toasts detailErrorNotEligible',
    (tester) async {
      final repo = RecordingBookingRepository()
        ..seedBooking(_lateBooking())
        ..nextError = BookingErrorCode.notEligible;
      await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        now: _lateNow,
        bookings: repo,
      );
      await _settle(tester);

      final open = find.byKey(const Key('late-delivery-cancel'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await _settle(tester);

      await tester.tap(_inSheet(find.byKey(const Key('late-cancel-confirm'))));
      await _settle(tester);

      expect(_sheet, findsNothing);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Không còn thực hiện được thao tác này'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('disputed closes and toasts lateCancelDisputed', (tester) async {
    final repo = RecordingBookingRepository()
      ..seedBooking(_lateBooking())
      ..nextError = BookingErrorCode.conflict;
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      now: _lateNow,
      bookings: repo,
    );
    await _settle(tester);

    final open = find.byKey(const Key('late-delivery-cancel'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _settle(tester);

    await tester.tap(_inSheet(find.byKey(const Key('late-cancel-confirm'))));
    await _settle(tester);

    expect(_sheet, findsNothing);
    expect(
      find.text('Booking đang khiếu nại, không huỷ được.'),
      findsOneWidget,
    );
  });

  testWidgets('a network failure keeps the sheet open with the generic error', (
    tester,
  ) async {
    final repo = RecordingBookingRepository()
      ..seedBooking(_lateBooking())
      ..nextError = BookingErrorCode.network;
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      now: _lateNow,
      bookings: repo,
    );
    await _settle(tester);

    final open = find.byKey(const Key('late-delivery-cancel'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _settle(tester);

    await tester.tap(_inSheet(find.byKey(const Key('late-cancel-confirm'))));
    await _settle(tester);

    expect(_sheet, findsOneWidget);
    expect(find.text('Không gửi được. Thử lại nhé.'), findsOneWidget);
  });

  testWidgets('the confirm button is disabled while the call runs', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repo = RecordingBookingRepository()
      ..seedBooking(_lateBooking())
      ..gate = gate;
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      now: _lateNow,
      bookings: repo,
    );
    await _settle(tester);

    final open = find.byKey(const Key('late-delivery-cancel'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _settle(tester);

    final confirm = _inSheet(find.byKey(const Key('late-cancel-confirm')));
    await tester.tap(confirm);
    await tester.pump();

    expect(tester.widget<AppButton>(confirm).loading, isTrue);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();

    gate.complete();
    await _settle(tester);
    expect(_sheet, findsNothing);
    expect(repo.cancelLateCalls, hasLength(1));
  });
}
