import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';

/// Thursday 08/10 09:00 in Vietnam; the request is for Saturday.
final _now = DateTime.utc(2026, 10, 8, 2);

const _copy = BookingContactSnapshot(
  name: 'Lan Anh',
  phone: '+84903123456',
  allowZalo: true,
  allowWhatsApp: false,
);

RecordingBookingRepository _repo() => RecordingBookingRepository()
  ..seedBooking(
    makeTestBooking(
      id: 'b1',
      status: BookingStatus.requested,
      day: '2026-10-10',
      start: '15:30',
      end: '17:30',
      deposit: 450000,
      remaining: 1050000,
      serviceSnapshot: const BookingServiceSnapshot(
        name: 'Chân dung 2h',
        price: 1500000,
        durationMinutes: 120,
      ),
      place: const BookingPlace(name: 'Bến Bạch Đằng'),
    ).copyWith(acceptDeadline: _now.add(const Duration(hours: 22))),
  )
  ..seedContact('b1', _copy);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _sheet = find.byKey(const Key('app-sheet'));

Finder _inSheet(Finder f) => find.descendant(of: _sheet, matching: f);

Finder get _confirm => _inSheet(find.widgetWithText(AppButton, 'Từ chối'));

bool _confirmEnabled(WidgetTester tester) =>
    tester.widget<AppButton>(_confirm).onPressed != null;

/// Opens S05.02 as the photographer and taps "Từ chối".
Future<BookingDetailHandles> _open(
  WidgetTester tester, {
  RecordingBookingRepository? bookings,
}) async {
  final handles = await pumpBookingDetail(
    tester,
    uid: detailPhotographerUid,
    now: _now,
    bookings: bookings ?? _repo(),
  );
  await _settle(tester);
  await tester.tap(find.widgetWithText(AppButton, 'Từ chối'));
  await _settle(tester);
  return handles;
}

void main() {
  testWidgets('uses showConfirmSheet with a radio ReasonPicker (no hand-made '
      'sheet)', (tester) async {
    await _open(tester);

    expect(_sheet, findsOneWidget);
    expect(
      _inSheet(
        find.byWidgetPredicate(
          (w) => w is ScreenCode && w.code == ScreenCodes.declineRequest,
        ),
      ),
      findsOneWidget,
    );
    expect(_inSheet(find.text('Từ chối yêu cầu của Lan Anh?')), findsOneWidget);
    final picker = tester.widget<ReasonPicker>(
      _inSheet(find.byType(ReasonPicker)),
    );
    expect(picker.style, ReasonPickerStyle.radio);
    expect(picker.reasons, [
      'Kín lịch hôm đó',
      'Ngoài khu vực phục vụ',
      'Gói không phù hợp nhu cầu',
      'Lý do khác',
    ]);
    final back = _inSheet(find.widgetWithText(AppButton, 'Quay lại'));
    expect(back, findsOneWidget);
    expect(_confirm, findsOneWidget);
    // Safe button left, red button right; never the gradient.
    expect(tester.getCenter(back).dx, lessThan(tester.getCenter(_confirm).dx));
    expect(_inSheet(find.byType(CtaSurface)), findsNothing);
  });

  testWidgets('Từ chối is disabled until a reason is chosen', (tester) async {
    await _open(tester);

    expect(_confirmEnabled(tester), isFalse);
    await tester.tap(_inSheet(find.text('Gói không phù hợp nhu cầu')));
    await _settle(tester);
    expect(_confirmEnabled(tester), isTrue);
  });

  testWidgets('Lý do khác needs at least 5 characters', (tester) async {
    final handles = await _open(tester);

    await tester.tap(_inSheet(find.text('Lý do khác')));
    await _settle(tester);
    expect(_confirmEnabled(tester), isFalse);

    final field = find.byKey(const ValueKey('reason_picker_other_field'));
    await tester.enterText(field, ' abc ');
    await _settle(tester);
    expect(_confirmEnabled(tester), isFalse);

    await tester.enterText(field, ' Máy hỏng ');
    await _settle(tester);
    expect(_confirmEnabled(tester), isTrue);

    await tester.tap(_confirm);
    await _settle(tester);
    expect(handles.bookings.transitions, [
      (bookingId: 'b1', action: 'decline', reason: 'Máy hỏng'),
    ]);
  });

  testWidgets('sends the fixed reason label', (tester) async {
    final handles = await _open(tester);

    await tester.tap(_inSheet(find.text('Ngoài khu vực phục vụ')));
    await _settle(tester);
    await tester.tap(_confirm);
    await _settle(tester);

    expect(handles.bookings.transitions, [
      (bookingId: 'b1', action: 'decline', reason: 'Ngoài khu vực phục vụ'),
    ]);
    expect(_sheet, findsNothing);
    expect(find.text('Đã từ chối. Lan Anh được hoàn cọc.'), findsOneWidget);
  });

  testWidgets('shows the refund line with the full deposit', (tester) async {
    await _open(tester);

    expect(
      _inSheet(find.text('Lan Anh được hoàn cọc 450.000₫ và nhận lý do này.')),
      findsOneWidget,
    );
  });

  testWidgets('Quay lại closes without calling', (tester) async {
    final handles = await _open(tester);

    await tester.tap(_inSheet(find.text('Kín lịch hôm đó')));
    await _settle(tester);
    await tester.tap(_inSheet(find.widgetWithText(AppButton, 'Quay lại')));
    await _settle(tester);

    expect(_sheet, findsNothing);
    expect(handles.bookings.transitions, isEmpty);
  });

  testWidgets('server error keeps the sheet with a SnackBar', (tester) async {
    final repo = _repo();
    await _open(tester, bookings: repo);

    repo.nextError = BookingErrorCode.notEligible;
    await tester.tap(_inSheet(find.text('Kín lịch hôm đó')));
    await _settle(tester);
    await tester.tap(_confirm);
    await _settle(tester);

    expect(_sheet, findsOneWidget);
    expect(find.text('Không còn thực hiện được thao tác này'), findsOneWidget);
    expect(_confirmEnabled(tester), isTrue);
  });

  testWidgets('/b/b1/decline opens S06.03 with the customer name', (
    tester,
  ) async {
    await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      now: _now,
      path: '/b/b1/decline',
      bookings: _repo(),
    );
    await _settle(tester);

    expect(_inSheet(find.text('Từ chối yêu cầu của Lan Anh?')), findsOneWidget);
  });

  testWidgets('320 dp, 1.3×: reasons and buttons fit', (tester) async {
    await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      now: _now,
      bookings: _repo(),
      textScale: 1.3,
      viewSize: const Size(320, 640),
    );
    await _settle(tester);
    final open = find.widgetWithText(AppButton, 'Từ chối');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _settle(tester);
    await tester.tap(_inSheet(find.text('Lý do khác')));
    await _settle(tester);

    expect(_sheet, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
