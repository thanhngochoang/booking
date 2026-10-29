// S04.03-entry: a booking at a ticketed spot carries entry tickets (spec
// §5.1, Decision 15): the card on by default with one ticket for the
// customer and one for the photographer, the waivers of a resident, the
// switch, the money line and the two payees, the reference-only section,
// and `createBooking.entry`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/entry/entry_rules.dart';

import '../../support/booking_world.dart';
import '../../support/fake_booking_repository.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/spot_booking_fixtures.dart';

Spot _ticketedSpot() {
  final b = spotBookingSpot();
  return Spot(
    id: b.id,
    name: b.name,
    city: b.city,
    areaCode: b.areaCode,
    lat: b.lat,
    lng: b.lng,
    radiusM: b.radiusM,
    cover: null,
    description: '',
    tips: const [],
    seasonMonths: const [],
    pinned: false,
    hidden: false,
    archived: false,
    stats: b.stats,
    managedBy: 'org1',
    openHours: const OpenHours(start: '05:00', end: '22:00'),
    access: SpotAccess(
      type: SpotAccessType.ticket,
      fees: const [AccessFee(label: 'Người lớn', amountVnd: 70000)],
      updatedAt: DateTime.utc(2026, 10, 1),
      source: SpotAccessSource.organizer,
    ),
  );
}

const _entry = EntryEvent(
  id: 'ent1',
  title: 'Vé vào cửa Hồ Tây',
  spotId: spotBookingSpotId,
  organizerId: 'org1',
  organizerName: 'Ban quản lý Hồ Tây',
  status: EventStatus.open,
  startDay: '2026-10-01',
  endDay: '2026-12-31',
  openHours: OpenHours(start: '05:00', end: '22:00'),
  ticketTypes: [
    EntryTicketType(id: 't1', name: 'Người lớn', price: 70000),
    EntryTicketType(id: 't2', name: 'Trẻ em', price: 50000),
  ],
);

FakeSpotRepository _spots({
  bool onSale = true,
  List<Resident> residents = const [],
}) {
  final repo = spotBookingRepo()..seedSpot(_ticketedSpot());
  if (onSale) repo.seedEntryEvent(spotBookingSpotId, _entry);
  if (residents.isNotEmpty) repo.seedResidents(spotBookingSpotId, residents);
  return repo;
}

/// S29.06's slot path opens S04.03 directly (offer 490.000₫, day 1).
Future<FakeBookingRepository> _open(
  WidgetTester tester, {
  FakeSpotRepository? spots,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  Size size = const Size(390, 1400),
}) async {
  final bookings = FakeBookingRepository();
  await pumpBookingRoute(
    tester,
    path: spotBookingPath(start: '06:40'),
    bookings: bookings,
    brightness: brightness,
    textScale: textScale,
    viewSize: size,
    extraOverrides: [
      spotRepositoryProvider.overrideWithValue(spots ?? _spots()),
    ],
  );
  await tester.pumpAndSettle();
  return bookings;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test('spotCovers: inside the radius only', () {
    final s = _ticketedSpot(); // radius 2000 m
    expect(spotCoversPoint(s, s.lat, s.lng), isTrue);
    expect(spotCoversPoint(s, s.lat + 0.01, s.lng), isTrue); // ≈ 1.1 km
    expect(spotCoversPoint(s, s.lat + 0.05, s.lng), isFalse); // ≈ 5.6 km
  });

  test('quote: guests waived up to maxGuests, provider ticket of the first '
      'type unless waived', () {
    final q = quoteBookingEntry(
      event: _entry,
      picks: const {'t1': 2, 't2': 1},
      waiver: (provider: false, guests: true, maxGuests: 2),
    );
    expect(q.waivedGuests, 2);
    expect(q.providerTicket, isTrue);
    expect(
      {for (final l in q.lines) l.ticketTypeId: l.qty},
      {'t2': 1, 't1': 1},
    );
    expect(q.amount, 120000);
    final all = quoteBookingEntry(
      event: _entry,
      picks: const {'t1': 1},
      waiver: (provider: true, guests: true, maxGuests: null),
    );
    expect(all.allWaived, isTrue);
    expect(all.amount, 0);
  });

  testWidgets('on by default: 1 ticket for you + 1 for the photographer, '
      'the money line and the two payees', (tester) async {
    await _open(tester);
    expect(find.text('Vé vào cửa · T7 10/10'), findsOneWidget);
    final sw = tester.widget<Switch>(
      find.byKey(const Key('book-entry-switch')),
    );
    expect(sw.value, isTrue);
    expect(find.text('Người lớn · bạn'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('book-entry-t1-quantity'))).data,
      '1',
    );
    expect(find.text('Vé cho thợ (Minh Trí)'), findsOneWidget);
    expect(find.text('Vé vào cửa × 2'), findsOneWidget);
    expect(find.text('140.000₫'), findsWidgets);
    expect(
      find.text('Tiền buổi chụp chuyển cho thợ, tiền vé chuyển cho địa điểm.'),
      findsOneWidget,
    );
    expect(find.text('Thanh toán 630.000₫'), findsOneWidget);
  });

  testWidgets('createBooking gets the entry: event, day and your tickets', (
    tester,
  ) async {
    final bookings = await _open(tester);
    await _tap(tester, find.byKey(const Key('book-entry-t2-plus')));
    expect(find.text('Vé vào cửa × 3'), findsOneWidget);
    await _tap(tester, find.text('Thanh toán 680.000₫'));
    final e = bookings.createEntries.single!;
    expect(e.eventId, 'ent1');
    expect(e.visitDay, spotBookingDay1);
    expect(
      {for (final i in e.items) i.ticketTypeId: i.qty},
      {'t1': 1, 't2': 1},
    );
  });

  testWidgets('a resident who waives the photographer: the line says so', (
    tester,
  ) async {
    await _open(
      tester,
      spots: _spots(
        residents: const [
          Resident(providerId: 'p1', waivesProvider: true, waivesGuests: false),
        ],
      ),
    );
    expect(find.text('Thợ tại điểm · miễn vé'), findsOneWidget);
    expect(find.text('Vé vào cửa × 1'), findsOneWidget);
    expect(find.text('Thanh toán 560.000₫'), findsOneWidget);
  });

  testWidgets('all waived: one line, no money line, nothing sent', (
    tester,
  ) async {
    final bookings = await _open(
      tester,
      spots: _spots(
        residents: const [
          Resident(providerId: 'p1', waivesProvider: true, waivesGuests: true),
        ],
      ),
    );
    expect(find.text('Bạn và thợ được miễn vé'), findsOneWidget);
    expect(find.textContaining('Vé vào cửa ×'), findsNothing);
    await _tap(tester, find.text('Thanh toán 490.000₫'));
    expect(bookings.createEntries.single, isNull);
  });

  testWidgets('switch off → "Tự mua vé tại cổng ≈ …", no tickets sent', (
    tester,
  ) async {
    final bookings = await _open(tester);
    await _tap(tester, find.byKey(const Key('book-entry-switch')));
    expect(find.text('Tự mua vé tại cổng ≈ 140.000₫'), findsOneWidget);
    expect(find.textContaining('Vé vào cửa ×'), findsNothing);
    await _tap(tester, find.text('Thanh toán 490.000₫'));
    expect(bookings.createEntries.single, isNull);
  });

  testWidgets('a reference-only spot shows Chi phí tại chỗ (không qua app)', (
    tester,
  ) async {
    await _open(tester, spots: _spots(onSale: false));
    expect(find.byKey(const Key('book-entry-switch')), findsNothing);
    expect(find.text('Chi phí tại chỗ (không qua app)'), findsOneWidget);
    expect(find.text('Vé vào cửa ≈ 70.000₫ × 2 (bạn và thợ)'), findsOneWidget);
    expect(find.text('Thanh toán 490.000₫'), findsOneWidget);
  });

  testWidgets('an open spot has no entry card', (tester) async {
    await _open(tester, spots: spotBookingRepo());
    expect(find.byKey(const Key('book-entry')), findsNothing);
    expect(find.text('Chi phí tại chỗ (không qua app)'), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text (${b.name})', (tester) async {
      await _open(
        tester,
        brightness: b,
        textScale: 1.3,
        size: const Size(320, 2000),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('book-entry')), findsOneWidget);
    });
  }
}
