// test/features/booking/booking_flow_e2e_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/payment/fake_transfer_sheet.dart';
import 'package:photobooking/features/payment/payment_screen.dart';
import 'package:photobooking/features/booking/steps/datetime_step.dart';
import 'package:photobooking/features/booking/steps/place_step.dart';
import 'package:photobooking/features/booking/steps/review_step.dart';
import 'package:photobooking/features/booking/steps/service_step.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/spots/slot_pick_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/booking_world.dart';
import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/fake_booking_repository.dart';
import '../../support/spot_booking_fixtures.dart';

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
    List<AddonPick> addons = const [],
    BookingPlace? pickup,
    int? expectedTotal,
    String? spotScheduleId,
    String? slotOfferId,
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
      addons: addons,
      pickup: pickup,
      expectedTotal: expectedTotal,
      spotScheduleId: spotScheduleId,
      slotOfferId: slotOfferId,
    );
  }

  @override
  Future<BookingCheckout> createPayment({
    required String bookingId,
    required PayMethod method,
  }) {
    log.add('createPayment(${method.code})');
    return super.createPayment(bookingId: bookingId, method: method);
  }

  @override
  Future<String> confirmFakePayment({
    required String paymentId,
    FakeTransferKind kind = FakeTransferKind.exact,
  }) {
    log.add('confirmFakePayment');
    return super.confirmFakePayment(paymentId: paymentId, kind: kind);
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
      await _tapButton(tester, 'Thanh toán 1.500.000₫');
      await _pumpWhileWaiting(tester);

      // No sheet yet: S04.04 shows the QR and waits for the transfer.
      expect(find.byType(FakeTransferSheet), findsNothing);
      expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
      expect(find.byType(QrImageView), findsOneWidget);
      // The test bank's simulator sends the exact amount.
      await tester.tap(find.text('Giả lập chuyển khoản'));
      await _pumpWhileWaiting(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Chuyển đúng'));
      await _pumpWhileWaiting(tester);

      // S04.04 saw the status leave draft and moved on to S05.02.
      expect(handles.router.state.uri.toString(), '/b/booking_1?paid=1');
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(BookingDetailScreen), findsOneWidget);
      expect(
        find.textContaining('tiền được giữ an toàn.'),
        findsOneWidget,
      );

      expect(repo.log, [
        'createBooking',
        'createPayment(bank_qr)',
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

  testWidgets(
    'add-ons: makeup ×2 + car through S04.01 → S04.02 → S04.06 → S04.03 → payment',
    (tester) async {
      final day12 = DateTime.utc(2026, 10, 12);
      final repo = _OrderedBookingRepository();
      final handles = await pumpBookingRoute(
        tester,
        path: '/u/p1/book?serviceId=s1',
        bookings: repo,
        packages: [bookingPortrait2h, bookingPackage2],
        addons: [addonMakeup, addonRetouch, addonTransport],
        days: {day12: AvailabilityDay(day: day12, state: DayState.free)},
      );
      await tester.pumpAndSettle();

      // "Đặt gói này" with add-ons opens on S04.01 with the package chosen.
      expect(find.byType(ServiceStep), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        final plus = find.byKey(const Key('addon-a_makeup-plus'));
        await tester.ensureVisible(plus);
        await tester.tap(plus);
        await tester.pump();
      }
      final car = find.byKey(const Key('addon-a_car-check'));
      await tester.ensureVisible(car);
      await tester.tap(car);
      await tester.pump();
      await _tapButton(tester, 'Tiếp tục · 3.400.000₫');
      await tester.pumpAndSettle();

      // S04.02.
      expect(find.byType(DateTimeStep), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('12 tháng 10, rảnh'));
      await tester.pumpAndSettle();
      final slot = find.widgetWithText(AppChip, '15:30');
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Tiếp tục · 3.400.000₫');
      await tester.pumpAndSettle();

      // S04.06: place and pickup.
      expect(find.byType(PlaceStep), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'Bến Bạch Đằng, Quận 1',
      );
      await tester.enterText(
        find.byKey(const Key('book-pickup-field')),
        'Ga Sài Gòn, Quận 3',
      );
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Tiếp tục · 3.400.000₫');
      await tester.pumpAndSettle();

      // S04.03 → createBooking → createPayment → S04.04.
      expect(find.byType(ReviewStep), findsOneWidget);
      expect(find.text('Điểm đón: Ga Sài Gòn, Quận 3'), findsOneWidget);
      await _tapButton(tester, 'Thanh toán 3.400.000₫');
      await _pumpWhileWaiting(tester);

      expect(handles.router.state.uri.toString(), '/b/booking_1/pay');
      expect(repo.log, ['createBooking', 'createPayment(bank_qr)']);
      final created = repo.createCalls.single;
      expect(created.serviceId, 's1');
      expect(created.addons, const [
        AddonPick('a_makeup', 2),
        AddonPick('a_car', 1),
      ]);
      expect(created.pickup, const BookingPlace(name: 'Ga Sài Gòn, Quận 3'));
      expect(created.expectedPrice, 1500000);
      expect(created.expectedTotal, 3400000);
    },
  );

  group('booking from a spot', () {
    testWidgets(
      'spot package path S04.01 → S04.02-spot → S04.06 → S04.03 → GoToPayment',
      (tester) async {
        final repo = _OrderedBookingRepository();
        await walkSpotPackage(
          tester,
          until: BookingStep.review,
          car: true,
          bookings: repo,
        );

        expect(find.byType(ReviewStep), findsOneWidget);
        expect(find.text('Tại Hồ Tây'), findsOneWidget);
        await _tapButton(tester, 'Thanh toán 1.800.000₫');
        await _pumpWhileWaiting(tester);

        expect(repo.log, ['createBooking', 'createPayment(bank_qr)']);
        expect(find.byType(PaymentScreen), findsOneWidget);
        final created = repo.createCalls.single;
        expect(created.spotScheduleId, spotBookingScheduleId);
        expect(created.slotOfferId, isNull);
        expect(created.serviceId, 's1');
        expect(created.day, spotBookingDay1);
        expect(created.start, '06:00');
        expect(created.placeName, 'Hồ Tây');
        expect(created.addons.single.addonId, 'a_car');
        expect(created.pickup?.name, 'Ga Hà Nội, Đống Đa');
      },
    );

    testWidgets('slot path S29.06 → S04.03 → GoToPayment', (tester) async {
      final repo = _OrderedBookingRepository();
      await pumpBookingRoute(
        tester,
        path: '/spots/$spotBookingSpotId',
        bookings: repo,
        addons: [addonMakeup, addonTransport],
        extraOverrides: [
          spotRepositoryProvider.overrideWithValue(spotBookingRepo()),
        ],
        extraRoutes: [
          // Stand-in for S29.02: its "Chọn suất" opens S29.06.
          GoRoute(
            path: '/spots/:spotId',
            builder: (_, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showSlotPickSheet(
                    context,
                    ref,
                    offer: spotBookingOffer,
                    schedule: spotBookingSchedule(),
                    spotName: 'Hồ Tây',
                    day: spotBookingDay1,
                  ),
                  child: const Text('Chọn suất'),
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn suất'));
      await tester.pumpAndSettle();

      // S29.06: pick 07:20, then straight to S04.03.
      await tester.tap(find.text('07:20'));
      await tester.pump();
      await _tapButton(tester, 'Tiếp tục · 490.000₫');
      await tester.pumpAndSettle();

      expect(find.byType(ReviewStep), findsOneWidget);
      expect(find.text('Tại Hồ Tây'), findsOneWidget);
      expect(find.textContaining('Bình minh Hồ Tây 30 phút'), findsWidgets);
      expect(find.byType(ServiceStep), findsNothing);
      await _tapButton(tester, 'Thanh toán 490.000₫');
      await _pumpWhileWaiting(tester);

      expect(repo.log, ['createBooking', 'createPayment(bank_qr)']);
      expect(find.byType(PaymentScreen), findsOneWidget);
      final created = repo.createCalls.single;
      expect(created.spotScheduleId, spotBookingScheduleId);
      expect(created.slotOfferId, spotBookingOfferId);
      expect(created.serviceId, spotBookingOfferId);
      expect(created.expectedPrice, 490000);
      expect(created.day, spotBookingDay1);
      expect(created.start, '07:20');
      expect(created.addons, isEmpty);
      expect(created.pickup, isNull);
      expect(created.expectedTotal, isNull);
    });
  });
}
