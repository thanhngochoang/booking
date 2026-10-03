// The whole life of a booking across both apps: one repository shared by
// the customer's and the photographer's worlds, pumped in turn.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/features/booking/my_bookings_screen.dart';
import 'package:photobooking/features/work/work_screen.dart';

import '../../support/booking_world.dart';

/// Saturday 03/10 17:00 in Vietnam; the shoot is Monday 12/10 15:30–17:30.
final _start = DateTime.utc(2026, 10, 3, 10);
final _day12 = DateTime.utc(2026, 10, 12);
final _endsAt = DateTime.utc(2026, 10, 12, 10, 30);

/// What the server does around the client calls, on the shared [clock]:
/// the package's real price and times on create, the contact copy and the
/// 24-hour deadline on payment, an event per status change.
class _ServerLikeRepository extends RecordingBookingRepository {
  _ServerLikeRepository(this.clock);

  final TestClock clock;
  var _events = 0;

  void _event(String bookingId, BookingStatus status) => addEvent(
    BookingEventRecord(
      id: 'e${++_events}',
      bookingId: bookingId,
      status: status,
      at: clock.now,
    ),
  );

  @override
  Future<Booking> createBooking({
    required String photographerId,
    required String serviceId,
    required String day,
    required String start,
    required BookingPlace place,
    String? note,
    int? expectedPrice,
  }) async {
    final b = await super.createBooking(
      photographerId: photographerId,
      serviceId: serviceId,
      day: day,
      start: start,
      place: place,
      note: note,
      expectedPrice: expectedPrice,
    );
    final fixed = b.copyWith(
      serviceSnapshot: const BookingServiceSnapshot(
        name: 'Gói Chân Dung',
        price: 1500000,
        durationMinutes: 120,
      ),
      end: '17:30',
      deposit: 450000,
      remaining: 1050000,
      createdAt: clock.now,
      updatedAt: clock.now,
    );
    seedBooking(fixed);
    return fixed;
  }

  @override
  Future<ConfirmPaymentResponse> confirmFakePayment({
    required String paymentId,
  }) async {
    final res = await super.confirmFakePayment(paymentId: paymentId);
    final id = paymentId.replaceFirst('pay_', '');
    final b = bookings[id]!;
    seedContact(
      id,
      const BookingContactSnapshot(
        name: 'Khách hàng',
        phone: '+84903123456',
        allowZalo: true,
        allowWhatsApp: false,
      ),
    );
    seedBooking(
      b.copyWith(
        depositPaidAt: clock.now,
        acceptDeadline: clock.now.add(const Duration(hours: 24)),
        updatedAt: clock.now,
      ),
    );
    _event(id, BookingStatus.requested);
    return res;
  }

  @override
  Future<Booking> transitionBooking({
    required String bookingId,
    required String action,
    String? reason,
  }) async {
    final b = await super.transitionBooking(
      bookingId: bookingId,
      action: action,
      reason: reason,
    );
    final fixed = b.copyWith(
      updatedAt: clock.now,
      completedAt: b.status == BookingStatus.completed
          ? clock.now
          : b.completedAt,
      escrowStatus: switch (b.status) {
        BookingStatus.declined => EscrowStatus.refunded,
        BookingStatus.completed => EscrowStatus.released,
        _ => b.escrowStatus,
      },
      depositRefunded: b.status == BookingStatus.declined
          ? b.deposit
          : b.depositRefunded,
    );
    seedBooking(fixed);
    _event(bookingId, fixed.status);
    return fixed;
  }
}

/// Screens here show no looping loader: pump a bounded second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(AppButton, label);
  await tester.ensureVisible(button);
  await _settle(tester);
  await tester.tap(button);
  await _settle(tester);
}

List<TimelineStepState> _timeline(WidgetTester tester) => [
  for (final s
      in tester.widget<StatusTimeline>(find.byType(StatusTimeline)).steps)
    s.state,
];

Finder _badge(BookingStatus status) =>
    find.byWidgetPredicate((w) => w is StatusBadge && w.status == status);

/// The customer books through S03.01 → S04.01–S04.03 → the fake gateway and
/// lands on S05.02 (plan 4b's flow); returns the new booking's id.
Future<String> _customerBooks(
  WidgetTester tester,
  _ServerLikeRepository repo,
) async {
  final handles = await pumpBookingRoute(
    tester,
    path: '/u/p1',
    bookings: repo,
    now: repo.clock.now,
    days: {_day12: AvailabilityDay(day: _day12, state: DayState.free)},
    signedInUid: detailCustomerUid,
  );
  await _settle(tester);
  await tester.tap(find.byKey(const Key('profile-book')));
  await _settle(tester);
  await tester.tap(find.text('Gói Chân Dung'));
  await _settle(tester);
  await _tapButton(tester, 'Tiếp tục · 1.500.000₫');
  await tester.tap(find.bySemanticsLabel('12 tháng 10, rảnh'));
  await _settle(tester);
  final slot = find.widgetWithText(AppChip, '15:30');
  await tester.ensureVisible(slot);
  await tester.tap(slot);
  await _settle(tester);
  await _tapButton(tester, 'Tiếp tục · 1.500.000₫');
  await tester.enterText(find.byType(TextField), 'Bến Bạch Đằng');
  await _settle(tester);
  await _tapButton(tester, 'Tiếp tục · 1.500.000₫');
  await _tapButton(tester, 'Đặt cọc 450.000₫');
  await tester.tap(find.widgetWithText(AppButton, 'Thanh toán thành công'));
  await _settle(tester);

  final id = repo.createCalls.isEmpty ? '' : 'booking_1';
  expect(handles.router.state.uri.toString(), '/b/$id?paid=1');
  return id;
}

/// A paid request made without the UI (the first scenario covers it).
Future<String> _paidRequest(_ServerLikeRepository repo) async {
  final b = await repo.createBooking(
    photographerId: 'p1',
    serviceId: 's1',
    day: '2026-10-12',
    start: '15:30',
    place: const BookingPlace(name: 'Bến Bạch Đằng'),
  );
  final dep = await repo.createDeposit(bookingId: b.id, provider: 'momo');
  await repo.confirmFakePayment(paymentId: dep.paymentId);
  repo.transitions.clear();
  return b.id;
}

void main() {
  testWidgets('book → photographer accepts on S06.01 → customer sees it '
      'accepted → completed after the shoot → listed under Đã xong', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repo = _ServerLikeRepository(clock);

    // Customer: booked and paid; S05.02 waits for the photographer.
    final id = await _customerBooks(tester, repo);
    expect(find.byType(BookingDetailScreen), findsOneWidget);
    expect(_badge(BookingStatus.requested), findsOneWidget);
    expect(_timeline(tester).take(2), [
      TimelineStepState.done,
      TimelineStepState.current,
    ]);

    // Photographer: the request is on S06.01 with its countdown.
    final work = await pumpBookingsTab(
      tester,
      uid: detailPhotographerUid,
      role: UserRole.photographer,
      bookings: repo,
      clock: clock,
    );
    await _settle(tester);
    expect(find.byType(WorkScreen), findsOneWidget);
    expect(find.text('Khách hàng'), findsOneWidget);
    expect(
      find.text('Gói Chân Dung · T2 12/10 15:30 · Bến Bạch Đằng'),
      findsOneWidget,
    );
    clock.advance(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    await tester.tap(find.widgetWithText(AppButton, 'Nhận · còn 22 giờ'));
    await _settle(tester);
    expect(repo.transitions.single, (
      bookingId: id,
      action: 'accept',
      reason: null,
    ));
    expect(work.location, '/b/$id');

    // Customer: accepted, steps 1–3 done.
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: repo,
      clock: clock,
      path: '/b/$id',
    );
    await _settle(tester);
    expect(_badge(BookingStatus.accepted), findsOneWidget);
    expect(_timeline(tester).take(4), [
      TimelineStepState.done,
      TimelineStepState.done,
      TimelineStepState.done,
      TimelineStepState.upcoming,
    ]);

    // After the shoot the photographer completes it on S05.02.
    clock.now = _endsAt.add(const Duration(minutes: 10));
    await pumpBookingDetail(
      tester,
      uid: detailPhotographerUid,
      bookings: repo,
      clock: clock,
      path: '/b/$id',
    );
    await _settle(tester);
    await _tapButton(tester, 'Hoàn thành');
    expect(repo.transitions.last, (
      bookingId: id,
      action: 'complete',
      reason: null,
    ));
    expect(_badge(BookingStatus.completed), findsOneWidget);

    // Customer S05.01: "Đã xong" lists it.
    await pumpBookingsTab(tester, bookings: repo, clock: clock);
    await _settle(tester);
    expect(find.byType(MyBookingsScreen), findsOneWidget);
    expect(find.byType(BookingCard), findsNothing, reason: 'nothing upcoming');
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedTabs<BookingTab>),
        matching: find.text('Đã xong'),
      ),
    );
    await _settle(tester);
    expect(find.text('Minh Trí · Gói Chân Dung'), findsOneWidget);
    expect(_badge(BookingStatus.completed), findsOneWidget);
  });

  testWidgets('photographer declines with Kín lịch hôm đó → customer S05.02 '
      'shows the stopped step and Đặt lại', (tester) async {
    final clock = TestClock(_start);
    final repo = _ServerLikeRepository(clock);
    final id = await _paidRequest(repo);

    await pumpBookingsTab(
      tester,
      uid: detailPhotographerUid,
      role: UserRole.photographer,
      bookings: repo,
      clock: clock,
    );
    await _settle(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Từ chối'));
    await _settle(tester);
    expect(find.text('Từ chối yêu cầu của Khách hàng?'), findsOneWidget);
    await tester.tap(find.text('Kín lịch hôm đó'));
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-sheet')),
        matching: find.widgetWithText(AppButton, 'Từ chối'),
      ),
    );
    await _settle(tester);
    expect(repo.transitions.single, (
      bookingId: id,
      action: 'decline',
      reason: 'Kín lịch hôm đó',
    ));
    expect(find.text('Đã từ chối. Khách hàng được hoàn cọc.'), findsOneWidget);

    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: repo,
      clock: clock,
      path: '/b/$id',
    );
    await _settle(tester);
    expect(_badge(BookingStatus.declined), findsOneWidget);
    final steps = tester
        .widget<StatusTimeline>(find.byType(StatusTimeline))
        .steps;
    expect(steps.last.state, TimelineStepState.stopped);
    expect(steps.last.title, 'Đã từ chối');
    await _tapButton(tester, 'Đặt lại');
    expect(find.textContaining('stub /u/p1/book'), findsOneWidget);
  });
}
