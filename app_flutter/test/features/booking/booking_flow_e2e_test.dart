// test/features/booking/booking_flow_e2e_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/fake_payment_sheet.dart';
import 'package:photobooking/features/booking/payment_pending_screen.dart';
import 'package:photobooking/features/booking/steps/datetime_step.dart';
import 'package:photobooking/features/booking/steps/place_step.dart';
import 'package:photobooking/features/booking/steps/review_step.dart';
import 'package:photobooking/features/booking/steps/service_step.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';

import '../../support/booking_world.dart';
import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/fake_booking_repository.dart';

/// Records the write calls of the booking port in the order they happen.
class _OrderedBookingRepository extends FakeBookingRepository {
  final log = <String>[];

  @override
  Future<Booking> createBooking({
    required String photographerId,
    required String serviceId,
    required String day,
    required String start,
    required BookingPlace place,
    String? note,
    int? expectedPrice,
  }) {
    log.add('createBooking');
    return super.createBooking(
      photographerId: photographerId,
      serviceId: serviceId,
      day: day,
      start: start,
      place: place,
      note: note,
      expectedPrice: expectedPrice,
    );
  }

  @override
  Future<CreateDepositResponse> createDeposit({
    required String bookingId,
    required String provider,
    String? returnUrl,
  }) {
    log.add('createDeposit($provider)');
    return super.createDeposit(
      bookingId: bookingId,
      provider: provider,
      returnUrl: returnUrl,
    );
  }

  @override
  Future<ConfirmPaymentResponse> confirmFakePayment({
    required String paymentId,
  }) {
    log.add('confirmFakePayment');
    return super.confirmFakePayment(paymentId: paymentId);
  }
}

/// S04.04 waits on a draft with a looping SignatureLoader: never
/// `pumpAndSettle` while it can be on screen, pump a bounded second instead.
Future<void> _pumpWhileWaiting(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(AppButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}

void main() {
  testWidgets(
    'S03.01 → S04.01–S04.03 → fake gateway → S04.04 paid → S05.02',
    (tester) async {
      final day12 = DateTime.utc(2026, 10, 12);
      final repo = _OrderedBookingRepository();
      final handles = await pumpBookingRoute(
        tester,
        path: '/u/p1',
        bookings: repo,
        days: {day12: AvailabilityDay(day: day12, state: DayState.free)},
        signedInUid: 'c1',
      );
      await tester.pumpAndSettle();

      // S03.01: the bottom bar's "Đặt lịch · từ …" goes through startBooking.
      expect(find.byType(PhotographerProfileScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-book')));
      await tester.pumpAndSettle();

      // S04.01: two packages, nothing chosen yet.
      expect(handles.router.state.uri.toString(), '/u/p1/book');
      expect(find.byType(ServiceStep), findsOneWidget);
      await tester.tap(find.text('Gói Chân Dung'));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Tiếp tục · 1.500.000₫');
      await tester.pumpAndSettle();

      // S04.02: a free day, then 15:30.
      expect(find.byType(DateTimeStep), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('12 tháng 10, rảnh'));
      await tester.pumpAndSettle();
      final slot = find.widgetWithText(AppChip, '15:30');
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      expect(find.text('15:30–17:30'), findsOneWidget);
      await _tapButton(tester, 'Tiếp tục · 1.500.000₫');
      await tester.pumpAndSettle();

      // Place step.
      expect(find.byType(PlaceStep), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Bến Bạch Đằng');
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Tiếp tục · 1.500.000₫');
      await tester.pumpAndSettle();

      // S04.03: nothing has been written to the server yet.
      expect(find.byType(ReviewStep), findsOneWidget);
      expect(repo.log, isEmpty);
      await _tapButton(tester, 'Đặt cọc 450.000₫');
      await tester.pumpAndSettle();

      // The fake gateway sheet.
      expect(find.byType(FakePaymentSheet), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Thanh toán thành công'));
      await _pumpWhileWaiting(tester);

      // S04.04 saw the status leave draft and moved on to S05.02.
      expect(handles.router.state.uri.toString(), '/b/booking_1?paid=1');
      expect(find.byType(PaymentPendingScreen), findsNothing);
      expect(find.byType(BookingDetailScreen), findsOneWidget);
      expect(
        find.textContaining('Minh Trí sẽ trả lời trong 24 giờ'),
        findsOneWidget,
      );

      expect(repo.log, [
        'createBooking',
        'createDeposit(momo)',
        'confirmFakePayment',
      ]);
      final created = repo.createCalls.single;
      expect(created.serviceId, 's1');
      expect(created.day, '2026-10-12');
      expect(created.start, '15:30');
      expect(created.placeName, 'Bến Bạch Đằng');
      expect(created.expectedPrice, 1500000);
      expect(repo.fakeConfirms, ['pay_booking_1']);
    },
  );

  testWidgets('the S02.06 entry skips nothing it should not', (tester) async {
    // S02.06 needs the discovery fakes; the booking world already provides
    // the signed-in customer, the clock and the contact.
    final discovery = DiscoveryWorld();
    await discovery.init();
    final skip = <Object>{
      authRepositoryProvider,
      userRepositoryProvider,
      clockProvider,
      userContactRepositoryProvider,
    };
    final discoveryOverrides = discovery.overrides
        .where((o) => !skip.contains((o as dynamic).origin))
        .toList();

    final handles = await pumpBookingRoute(
      tester,
      path: '/action',
      now: fixtureNow,
      packages: [bookingPackage1],
      extraOverrides: discoveryOverrides,
    );
    await tester.pumpAndSettle();
    expect(find.byType(FindPhotographerScreen), findsOneWidget);

    // Pick Saturday 3 October on S02.06, then the card's "Đặt T7".
    final dateChip = find.byKey(const Key('find-date'));
    await tester.ensureVisible(dateChip);
    await tester.pumpAndSettle();
    await tester.tap(dateChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('date-done')));
    await tester.pumpAndSettle();

    final book = find.byKey(const Key('card-book-p1'));
    expect(
      find.descendant(
        of: find.byKey(const Key('find-card-p1')),
        matching: find.text('Đặt T7'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(book);
    await tester.pumpAndSettle();
    await tester.tap(book);
    await tester.pumpAndSettle();

    // S02.06 knows the day but not the package, so S04.01 is not skipped;
    // the photographer's only package is already chosen.
    expect(handles.router.state.uri.toString(), '/u/p1/book?date=2026-10-03');
    expect(find.byType(ServiceStep), findsOneWidget);
    const args = BookingFlowArgs(photographerId: 'p1', day: '2026-10-03');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServiceStep)),
    );
    var state = container.read(bookingFlowControllerProvider(args));
    expect(state.serviceId, 's1');
    expect(state.day, '2026-10-03');

    await _tapButton(tester, 'Tiếp tục · 1.500.000₫');
    await tester.pumpAndSettle();

    // S04.02 opens with the day from S02.06 selected and its slots shown.
    expect(find.byType(DateTimeStep), findsOneWidget);
    state = container.read(bookingFlowControllerProvider(args));
    expect(state.day, '2026-10-03');
    expect(state.serviceId, 's1');
    expect(find.widgetWithText(AppChip, '06:00'), findsOneWidget);
    expect(find.text('Tiếp tục · 1.500.000₫'), findsOneWidget);
  });
}
