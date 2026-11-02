// S06.01-scan: "Quét mã khách" from two hours before the start, the
// photographer's ticket line, "Đang chụp" after the scan and "Đã chụp xong"
// only once it may be used (Decision 14).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/organizer_world.dart' show makeSpot, makeEntryEvent;

/// Thursday 08/10 09:00 in Vietnam.
final _now = DateTime.utc(2026, 10, 8, 2);

Booking _today(
  String id, {
  BookingStatus status = BookingStatus.upcoming,
  String start = '14:00',
  String end = '16:00',
  bool pass = true,
  BookingEntry? entry,
  String? spotId,
}) => makeTestBooking(
  id: id,
  status: status,
  day: '2026-10-08',
  start: start,
  end: end,
  place: const BookingPlace(name: 'Bãi đá sông Hồng'),
).copyWith(passCode4: pass ? '4R9X' : null, entry: entry, spotId: spotId);

Future<BookingsTabHandles> _pump(
  WidgetTester tester,
  List<Booking> list, {
  DateTime? now,
  FakeSpotRepository? spots,
  RecordingBookingRepository? repo,
  double textScale = 1,
  Size size = const Size(390, 1200),
  Brightness brightness = Brightness.dark,
}) async {
  final r = repo ?? RecordingBookingRepository();
  for (final b in list) {
    r.seedBooking(b);
  }
  final h = await pumpBookingsTab(
    tester,
    extraOverrides: [instantEnabledProvider.overrideWithValue(false)],
    uid: detailPhotographerUid,
    role: UserRole.photographer,
    bookings: r,
    clock: TestClock(now ?? _now),
    packages: const [workPackage],
    portfolioPhotos: 8,
    completeness: 90,
    spots: spots,
    textScale: textScale,
    viewSize: size,
    brightness: brightness,
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return h;
}

AppButton _scanButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.byKey(const Key('work-scan')));

void main() {
  testWidgets('Quét mã khách is off before start − 2 h with Mở lúc {time}', (
    tester,
  ) async {
    await _pump(tester, [_today('t1')]);
    expect(find.text('Quét mã khách'), findsOneWidget);
    expect(_scanButton(tester).onPressed, isNull);
    expect(find.text('Mở lúc 12:00'), findsOneWidget);
  });

  testWidgets('from start − 2 h it opens S30.07 for the booking', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      [_today('t1')],
      now: DateTime.utc(2026, 10, 8, 5), // 12:00 VN
    );
    expect(find.byKey(const Key('work-scan-opens')), findsNothing);
    await tester.tap(find.byKey(const Key('work-scan')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.router.state.uri.toString(), '/scan?booking=t1');
  });

  testWidgets('a booking without a pass keeps Chỉ đường, no scan', (
    tester,
  ) async {
    await _pump(tester, [_today('t1', pass: false)]);
    expect(find.byKey(const Key('work-scan')), findsNothing);
    expect(find.text('Chỉ đường'), findsOneWidget);
  });

  testWidgets('ticket line: bought with the booking / waived / at the gate', (
    tester,
  ) async {
    await _pump(tester, [
      _today(
        't1',
        entry: const BookingEntry(
          eventId: 'ent1',
          visitDay: '2026-10-08',
          providerTicket: true,
        ),
      ),
    ]);
    expect(find.textContaining('khách đã mua vé cho bạn'), findsOneWidget);

    await _pump(tester, [
      _today(
        't2',
        entry: const BookingEntry(
          eventId: 'ent1',
          visitDay: '2026-10-08',
          waivedProvider: true,
        ),
      ),
    ]);
    expect(find.textContaining('bạn được miễn vé'), findsOneWidget);

    final spots = FakeSpotRepository()
      ..seedSpot(
        makeSpot(
          id: 'bd',
          managedBy: 'org1',
          access: SpotAccess(
            type: SpotAccessType.ticket,
            fees: const [AccessFee(label: 'Người lớn', amountVnd: 70000)],
            updatedAt: _now,
            source: SpotAccessSource.organizer,
          ),
        ),
      )
      ..seedEntryEvent('bd', makeEntryEvent());
    await _pump(tester, [_today('t3', spotId: 'bd')], spots: spots);
    expect(
      find.textContaining('khách tự mua vé tại cổng ≈ 70.000₫'),
      findsOneWidget,
    );
  });

  testWidgets('after the scan: Đang chụp badge and Đã chụp xong marks shot', (
    tester,
  ) async {
    final repo = RecordingBookingRepository();
    await _pump(tester, [
      _today('t1', status: BookingStatus.shooting),
    ], repo: repo);
    expect(find.text('ĐANG CHỤP'), findsWidgets); // the status badge
    expect(find.byKey(const Key('work-scan')), findsNothing);
    await tester.tap(find.byKey(const Key('work-mark-shot-t1')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(repo.transitions.single.action, 'mark_shot');
  });

  testWidgets('Đã chụp xong is hidden before the scan when the booking has a '
      'pass, shown for a legacy booking after the end', (tester) async {
    final after = DateTime.utc(2026, 10, 8, 10); // 17:00 VN, after 16:00
    await _pump(tester, [_today('t1')], now: after);
    expect(find.byKey(const Key('work-mark-shot-t1')), findsNothing);

    await _pump(tester, [_today('t2', pass: false)], now: after);
    expect(find.byKey(const Key('work-mark-shot-t2')), findsOneWidget);
  });

  testWidgets('another scanned shoot is listed under today with Đang chụp', (
    tester,
  ) async {
    await _pump(tester, [
      _today('t1', start: '15:30', end: '17:30'),
      _today(
        's1',
        status: BookingStatus.shooting,
        start: '08:00',
        end: '10:00',
      ),
    ]);
    expect(find.byKey(const Key('work-scan')), findsOneWidget);
    expect(find.byKey(const Key('work-shooting-s1')), findsOneWidget);
    expect(find.byKey(const Key('work-mark-shot-s1')), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text (${b.name})', (tester) async {
      await _pump(
        tester,
        [
          _today(
            't1',
            entry: const BookingEntry(
              eventId: 'ent1',
              visitDay: '2026-10-08',
              providerTicket: true,
            ),
          ),
          _today('s1', status: BookingStatus.shooting, start: '08:00'),
        ],
        textScale: 1.3,
        size: const Size(320, 1600),
        brightness: b,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
