import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';

/// Shoot on Monday 12/10 15:30–17:30 Vietnam = 08:30–10:30 UTC.
final _startsAt = DateTime.utc(2026, 10, 12, 8, 30);

Booking _booking({BookingStatus status = BookingStatus.accepted}) =>
    makeTestBooking(
      id: 'b1',
      status: status,
      day: '2026-10-12',
      start: '15:30',
      end: '17:30',
      deposit: 450000,
      remaining: 1050000,
      serviceSnapshot: const BookingServiceSnapshot(
        name: 'Chân dung 2 giờ',
        price: 1500000,
        durationMinutes: 120,
      ),
      place: const BookingPlace(name: 'Bến Bạch Đằng'),
    );

RecordingBookingRepository _repo({
  BookingStatus status = BookingStatus.accepted,
}) => RecordingBookingRepository()
  ..seedBooking(_booking(status: status))
  ..seedContact('b1', testContactSnapshot);

/// Sheets and tickers animate: pump a bounded second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _sheet = find.byKey(const Key('app-sheet'));

Finder _inSheet(Finder f) => find.descendant(of: _sheet, matching: f);

Finder _refundLine(String amount) => find.descendant(
  of: find.byType(MoneyBreakdown),
  matching: find.text(amount),
);

int _activeRow(WidgetTester tester) =>
    tester.widget<PolicyTable>(find.byType(PolicyTable)).activeIndex;

/// Opens S05.02 at `/b/b1/cancel` as the customer at [now].
Future<BookingDetailHandles> _openCustomer(
  WidgetTester tester, {
  required DateTime now,
  RecordingBookingRepository? bookings,
  TestClock? clock,
}) async {
  final handles = await pumpBookingDetail(
    tester,
    uid: detailCustomerUid,
    path: '/b/b1/cancel',
    clock: clock ?? TestClock(now),
    bookings: bookings ?? _repo(),
  );
  await _settle(tester);
  return handles;
}

/// Opens S05.02 as the photographer and taps "Huỷ buổi chụp" (the deep link
/// would open before the contact copy names the customer).
Future<BookingDetailHandles> _openPhotographer(
  WidgetTester tester, {
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) async {
  final handles = await pumpBookingDetail(
    tester,
    uid: detailPhotographerUid,
    clock: TestClock(_startsAt.subtract(const Duration(days: 3))),
    bookings: _repo(),
    textScale: textScale,
    viewSize: viewSize,
  );
  await _settle(tester);
  final open = find.widgetWithText(AppButton, 'Huỷ buổi chụp');
  await tester.ensureVisible(open);
  await tester.tap(open);
  await _settle(tester);
  return handles;
}

void main() {
  testWidgets('uses showConfirmSheet with PolicyTable, MoneyBreakdown and '
      'ReasonPicker (no hand-made sheet)', (tester) async {
    await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(days: 3)),
    );

    expect(_sheet, findsOneWidget);
    expect(_inSheet(find.text('Huỷ buổi chụp?')), findsOneWidget);
    expect(_inSheet(find.byType(PolicyTable)), findsOneWidget);
    expect(_inSheet(find.byType(MoneyBreakdown)), findsOneWidget);
    expect(_inSheet(find.byType(ReasonPicker)), findsOneWidget);
    for (final reason in ['Đổi kế hoạch', 'Tìm được thợ khác', 'Lý do khác']) {
      expect(_inSheet(find.text(reason)), findsOneWidget, reason: reason);
    }
    final keep = _inSheet(find.widgetWithText(AppButton, 'Giữ lịch'));
    final confirm = _inSheet(find.widgetWithText(AppButton, 'Huỷ buổi chụp'));
    expect(keep, findsOneWidget);
    expect(confirm, findsOneWidget);
    // Safe button left, red button right; never the gradient.
    expect(tester.getCenter(keep).dx, lessThan(tester.getCenter(confirm).dx));
    expect(_inSheet(find.byType(CtaSurface)), findsNothing);
  });

  testWidgets('highlights the 100 % row more than 48 h before and shows the '
      'full deposit back', (tester) async {
    await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(days: 3)),
    );

    expect(_activeRow(tester), 0);
    expect(find.text('Trước 12/10 15:30 hơn 48 giờ'), findsOneWidget);
    expect(find.text('Hoàn 100%'), findsOneWidget);
    expect(find.text('Trong 24–48 giờ'), findsOneWidget);
    expect(find.text('Hoàn 50%'), findsOneWidget);
    expect(find.text('Dưới 24 giờ'), findsOneWidget);
    expect(find.text('Không hoàn'), findsOneWidget);
    expect(_inSheet(find.text('Bạn sẽ nhận lại')), findsOneWidget);
    expect(_refundLine('450.000₫'), findsOneWidget);
  });

  testWidgets('exactly 48 h before still highlights 100 %; 47 h 59 min '
      'highlights 50 % and halves the amount', (tester) async {
    await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(hours: 48)),
    );
    expect(_activeRow(tester), 0);
    expect(_refundLine('450.000₫'), findsOneWidget);

    await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(hours: 47, minutes: 59)),
    );
    expect(_activeRow(tester), 1);
    expect(_refundLine('225.000₫'), findsOneWidget);
  });

  testWidgets('under 24 h highlights Không hoàn and shows 0₫ back', (
    tester,
  ) async {
    await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(hours: 23, minutes: 59)),
    );
    expect(_activeRow(tester), 2);
    expect(_refundLine('0₫'), findsOneWidget);
  });

  testWidgets('the refund line follows the clock across 48 h', (tester) async {
    final clock = TestClock(
      _startsAt.subtract(const Duration(hours: 48, seconds: 30)),
    );
    await _openCustomer(tester, now: clock.now, clock: clock);
    expect(_activeRow(tester), 0);
    expect(_refundLine('450.000₫'), findsOneWidget);

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await _settle(tester);

    expect(_sheet, findsOneWidget);
    expect(_activeRow(tester), 1);
    expect(_refundLine('225.000₫'), findsOneWidget);
  });

  testWidgets('Giữ lịch closes without calling the server; tapping outside '
      'does not cancel', (tester) async {
    final handles = await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(days: 3)),
    );

    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Giữ lịch')));
    await _settle(tester);
    expect(_sheet, findsNothing);

    final reopen = find.text('Huỷ yêu cầu · hoàn cọc 100%');
    await tester.ensureVisible(reopen);
    await tester.tap(reopen);
    await _settle(tester);
    expect(_sheet, findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);

    expect(_sheet, findsNothing);
    expect(handles.bookings.transitions, isEmpty);
    expect(
      find.byWidgetPredicate(
        (w) => w is StatusBadge && w.status == BookingStatus.accepted,
      ),
      findsOneWidget,
    );
  });

  testWidgets('double tap on Huỷ buổi chụp sends one transition', (
    tester,
  ) async {
    final bookings = _repo()..gate = Completer<void>();
    await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(days: 3)),
      bookings: bookings,
    );

    final confirm = _inSheet(find.widgetWithText(AppButton, 'Huỷ buổi chụp'));
    await tester.tap(confirm);
    await tester.pump();
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();
    expect(bookings.transitions, hasLength(1));
    // Locked while in flight: Giữ lịch does nothing.
    await tester.tap(
      _inSheet(find.widgetWithText(AppButton, 'Giữ lịch')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(_sheet, findsOneWidget);

    bookings.gate!.complete();
    await _settle(tester);
    expect(_sheet, findsNothing);
    expect(bookings.transitions, hasLength(1));
  });

  testWidgets('Huỷ buổi chụp sends the chosen reason and closes with true', (
    tester,
  ) async {
    final handles = await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(days: 3)),
    );

    await tester.tap(_inSheet(find.text('Đổi kế hoạch')));
    await tester.pump();
    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Huỷ buổi chụp')));
    await _settle(tester);

    expect(handles.bookings.transitions.single, (
      bookingId: 'b1',
      action: 'cancel',
      reason: 'Đổi kế hoạch',
    ));
    expect(_sheet, findsNothing);
    expect(find.text('Đã huỷ. Hoàn 450.000₫ trong 3–5 ngày'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is StatusBadge && w.status == BookingStatus.cancelled,
      ),
      findsOneWidget,
    );
  });

  testWidgets('no reason is fine: the cancel goes out without one', (
    tester,
  ) async {
    final handles = await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(hours: 30)),
    );
    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Huỷ buổi chụp')));
    await _settle(tester);

    expect(handles.bookings.transitions.single.reason, isNull);
    expect(find.text('Đã huỷ. Hoàn 225.000₫ trong 3–5 ngày'), findsOneWidget);
  });

  testWidgets('Lý do khác sends the typed text, capped at 200', (tester) async {
    final handles = await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(days: 3)),
    );

    await tester.tap(_inSheet(find.text('Lý do khác')));
    await tester.pump();
    final field = find.byKey(const ValueKey('reason_picker_other_field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, '  ${'a' * 250}  ');
    await tester.pump();
    final confirm = _inSheet(find.widgetWithText(AppButton, 'Huỷ buổi chụp'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await _settle(tester);

    final reason = handles.bookings.transitions.single.reason!;
    expect(reason.length, lessThanOrEqualTo(200));
    expect(reason, startsWith('a'));
    expect(reason.trim(), reason);
  });

  testWidgets('a server error keeps the sheet open with a SnackBar', (
    tester,
  ) async {
    final bookings = _repo()..nextError = BookingErrorCode.notEligible;
    await _openCustomer(
      tester,
      now: _startsAt.subtract(const Duration(days: 3)),
      bookings: bookings,
    );

    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Huỷ buổi chụp')));
    await _settle(tester);

    expect(_sheet, findsOneWidget);
    expect(find.text('Không còn thực hiện được thao tác này'), findsOneWidget);
    expect(find.textContaining('BookingException'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is StatusBadge && w.status == BookingStatus.accepted,
      ),
      findsOneWidget,
    );
  });

  testWidgets('photographer variant shows 100 % refund to the customer and '
      'its own reasons', (tester) async {
    final handles = await _openPhotographer(tester);

    expect(_inSheet(find.text('Huỷ buổi chụp với Nguyễn Văn A?')), findsOne);
    expect(_inSheet(find.byType(PolicyTable)), findsNothing);
    expect(
      _inSheet(find.text('Nguyễn Văn A được hoàn cọc 100%')),
      findsOneWidget,
    );
    expect(_refundLine('450.000₫'), findsOneWidget);
    for (final reason in ['Ốm/việc gấp', 'Thiết bị gặp sự cố', 'Lý do khác']) {
      expect(_inSheet(find.text(reason)), findsOneWidget, reason: reason);
    }
    expect(_inSheet(find.text('Đổi kế hoạch')), findsNothing);

    await tester.tap(_inSheet(find.text('Thiết bị gặp sự cố')));
    await tester.pump();
    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Huỷ buổi chụp')));
    await _settle(tester);

    expect(handles.bookings.transitions.single, (
      bookingId: 'b1',
      action: 'cancel',
      reason: 'Thiết bị gặp sự cố',
    ));
    expect(
      find.text('Đã huỷ. Nguyễn Văn A được hoàn cọc 100%'),
      findsOneWidget,
    );
  });

  testWidgets('320 dp, 1.3×: rows and buttons fit', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await pumpBookingDetail(
        tester,
        uid: detailCustomerUid,
        path: '/b/b1/cancel',
        clock: TestClock(_startsAt.subtract(const Duration(hours: 30))),
        bookings: _repo(),
        brightness: brightness,
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );
      await _settle(tester);
      await tester.tap(_inSheet(find.text('Lý do khác')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$brightness');

      for (final label in ['Giữ lịch', 'Huỷ buổi chụp']) {
        final button = _inSheet(find.widgetWithText(AppButton, label));
        await tester.ensureVisible(button);
        await tester.pump();
        final r = tester.getRect(button);
        expect(r.left, greaterThanOrEqualTo(0), reason: label);
        expect(r.right, lessThanOrEqualTo(320), reason: label);
      }
    }

    await _openPhotographer(
      tester,
      textScale: 1.3,
      viewSize: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(_inSheet(find.byType(MoneyBreakdown)), findsOneWidget);
  });
}
