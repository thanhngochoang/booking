// test/support/spot_booking_fixtures.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';

import 'booking_world.dart';
import 'fake_booking_repository.dart';
import 'fake_spot_repository.dart';

/// Booking from a spot (#194 Task 7): photographer `p1` holds schedule
/// `sched1` at "Hồ Tây" on two days after `worldBookingToday` (2026-10-03)
/// and one past day, 06:00–11:00, for package `s1` only; offer `off1` cuts
/// the window into 30-minute slots 10 minutes apart.
const spotBookingSpotId = 'spot1';
const spotBookingScheduleId = 'sched1';
const spotBookingOfferId = 'off1';
const spotBookingDay1 = '2026-10-10';
const spotBookingDay2 = '2026-10-11';

Spot spotBookingSpot({bool archived = false}) => Spot(
  id: spotBookingSpotId,
  name: 'Hồ Tây',
  city: 'Hà Nội',
  areaCode: 'hn',
  lat: 21.05,
  lng: 105.82,
  radiusM: 2000,
  cover: null,
  description: '',
  tips: const [],
  seasonMonths: const [],
  pinned: false,
  hidden: false,
  archived: archived,
  stats: const SpotStats(
    posts14d: 0,
    events: 0,
    bookings14d: 0,
    openSchedules: 1,
    providersWeek: 1,
    providersWeekend: 1,
  ),
);

SpotSchedule spotBookingSchedule({
  List<String> days = const ['2026-09-30', spotBookingDay1, spotBookingDay2],
  List<String> serviceIds = const ['s1'],
  bool open = true,
}) => SpotSchedule(
  id: spotBookingScheduleId,
  providerId: 'p1',
  spotId: spotBookingSpotId,
  assigneeId: null,
  days: days,
  window: const SpotWindow(start: '06:00', end: '11:00'),
  serviceIds: serviceIds,
  priceFrom: 1500000,
  open: open,
);

const spotBookingOffer = SlotOffer(
  id: spotBookingOfferId,
  providerId: 'p1',
  scheduleId: spotBookingScheduleId,
  spotId: spotBookingSpotId,
  name: 'Bình minh Hồ Tây 30 phút',
  price: 490000,
  slotMinutes: 30,
  gapMinutes: 10,
  photoCount: 20,
  editedCount: 15,
  deliveryDays: 3,
  open: true,
);

/// A fake spot repository holding the spot, schedule and offer above.
FakeSpotRepository spotBookingRepo({
  bool archived = false,
  bool open = true,
  List<String> serviceIds = const ['s1'],
  Map<String, List<SpotInterval>> taken = const {},
}) {
  final repo = FakeSpotRepository()
    ..seedSpot(spotBookingSpot(archived: archived))
    ..seedSchedule(spotBookingSchedule(serviceIds: serviceIds, open: open))
    ..seedOffer(spotBookingOffer);
  for (final MapEntry(key: day, value: list) in taken.entries) {
    repo.seedSpotDay(
      SpotDay(scheduleId: spotBookingScheduleId, day: day, taken: list),
    );
  }
  return repo;
}

/// `/u/p1/book` from S29.02 "Đặt" (package path) or S29.06 (slot path).
String spotBookingPath({String day = spotBookingDay1, String? start}) =>
    Uri(
      path: '/u/p1/book',
      queryParameters: {
        'date': day,
        'scheduleId': spotBookingScheduleId,
        if (start != null) ...{'offerId': spotBookingOfferId, 'start': start},
      },
    ).toString();

/// Opens the sheet from S29.02 "Đặt" (package `s1`, day 1) and walks it to
/// [until]: S04.01 (optionally ticking the car), S04.02 at 06:00, S04.06.
Future<void> walkSpotPackage(
  WidgetTester tester, {
  required BookingStep until,
  bool car = false,
  Map<String, List<SpotInterval>> taken = const {},
  FakeBookingRepository? bookings,
  FakeSpotRepository? spots,
}) async {
  await pumpBookingRoute(
    tester,
    path: spotBookingPath(),
    bookings: bookings,
    addons: car ? [addonTransport] : const [],
    extraOverrides: [
      spotRepositoryProvider.overrideWithValue(
        spots ?? spotBookingRepo(taken: taken),
      ),
    ],
  );
  await tester.pumpAndSettle();
  if (until == BookingStep.service) return;

  if (car) {
    await tester.ensureVisible(find.byKey(const Key('addon-a_car-check')));
    await tester.tap(find.byKey(const Key('addon-a_car-check')));
    await tester.pump();
  }
  final total = car ? '1.800.000₫' : '1.500.000₫';
  Future<void> next() async {
    final b = find.widgetWithText(AppButton, 'Tiếp tục · $total');
    await tester.ensureVisible(b);
    await tester.tap(b);
    await tester.pumpAndSettle();
  }

  await next();
  if (until == BookingStep.datetime) return;

  final chip = find.widgetWithText(AppChip, '06:00');
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
  await next();
  if (until == BookingStep.place) return;

  if (car) {
    await tester.enterText(
      find.byKey(const Key('book-pickup-field')),
      'Ga Hà Nội, Đống Đa',
    );
    await tester.pump();
  }
  await next();
}
