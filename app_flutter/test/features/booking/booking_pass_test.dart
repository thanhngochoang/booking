// S05.02-pass, S05.02-askshot and the entry lines of S05.02; S05.03 "Giữ vé
// vào cửa" (#223).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/passes/pass_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/dispute_world.dart';
import '../../support/fake_pass_repository.dart';
import '../../support/fake_pass_scanner.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/organizer_world.dart' show makeSpot;

/// Shoot on Monday 12/10 15:30–17:30 Vietnam = 08:30–10:30 UTC.
final _start = DateTime.utc(2026, 10, 12, 8, 30);
final _end = DateTime.utc(2026, 10, 12, 10, 30);
const _code = '7K2Q4R9X';

const _entry = BookingEntry(
  eventId: 'ent1',
  visitDay: '2026-10-12',
  items: [
    EntryLine(ticketTypeId: 't1', name: 'Người lớn', price: 70000, qty: 3),
  ],
  providerTicket: true,
  amount: 210000,
);

Booking _booking({
  BookingStatus status = BookingStatus.upcoming,
  bool pass = true,
  BookingEntry? entry = _entry,
  String? spotId,
  DateTime? askedAt,
  DateTime? deniedAt,
  DateTime? checkedInAt,
}) =>
    makeTestBooking(
      id: 'b1',
      status: status,
      day: '2026-10-12',
      start: '15:30',
      end: '17:30',
      place: const BookingPlace(name: 'Bãi đá sông Hồng'),
    ).copyWith(
      passCode4: pass ? '4R9X' : null,
      entry: entry,
      spotId: spotId,
      shootQuestionAt: askedAt,
      shootQuestionUntil: askedAt?.add(const Duration(hours: 48)),
      shootDeniedAt: deniedAt,
      checkedInAt: checkedInAt,
    );

class _World {
  final passes = FakePassRepository()..setBookingPass('b1', _code);
  final brightness = FakeScreenBrightness();
  final spots = FakeSpotRepository();
  final disputes = DisputeWorld();
  late SharedPreferences prefs;

  Future<List<Override>> overrides({
    Map<String, Object> saved = const {},
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    prefs = await SharedPreferences.getInstance();
    return [
      passRepositoryProvider.overrideWithValue(passes),
      sharedPreferencesProvider.overrideWithValue(prefs),
      screenBrightnessProvider.overrideWithValue(brightness),
      spotRepositoryProvider.overrideWithValue(spots),
      disputeRepositoryProvider.overrideWithValue(disputes.repo),
      imagePickerProvider.overrideWithValue(disputes.picker),
    ];
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<BookingDetailHandles> _open(
  WidgetTester tester,
  _World w,
  Booking b, {
  required DateTime now,
  String uid = detailCustomerUid,
  Map<String, Object> saved = const {},
  RecordingBookingRepository? repo,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  Size size = const Size(390, 1600),
}) async {
  final r = repo ?? RecordingBookingRepository();
  r.seedBooking(b);
  final h = await pumpBookingDetail(
    tester,
    uid: uid,
    bookings: r,
    now: now,
    brightness: brightness,
    textScale: textScale,
    viewSize: size,
    extraOverrides:
        await tester.runAsync(() => w.overrides(saved: saved)) ?? const [],
  );
  await _settle(tester);
  return h;
}

void main() {
  group('S05.02-pass', () {
    testWidgets('from 24 h before the start: QR, code and the tickets', (
      tester,
    ) async {
      final w = _World();
      await _open(
        tester,
        w,
        _booking(),
        now: _start.subtract(const Duration(hours: 23)),
      );
      expect(find.text('Mã gặp thợ'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('VE-7K2Q-4R9X'), findsOneWidget);
      expect(find.text('Kèm 3 vé vào cửa'), findsOneWidget);
      expect(
        find.text('Đưa mã cho Minh Trí khi gặp, và cho nhân viên ở cổng.'),
        findsOneWidget,
      );
    });

    testWidgets('not before 24 h, not for the photographer', (tester) async {
      final w = _World();
      await _open(
        tester,
        w,
        _booking(),
        now: _start.subtract(const Duration(hours: 25)),
      );
      expect(find.text('Mã gặp thợ'), findsNothing);
      await _open(
        tester,
        _World(),
        _booking(),
        now: _start.subtract(const Duration(hours: 1)),
        uid: detailPhotographerUid,
      );
      expect(find.text('Mã gặp thợ'), findsNothing);
    });

    testWidgets('a booking without tickets: "Đưa mã cho {thợ} khi gặp"', (
      tester,
    ) async {
      await _open(
        tester,
        _World(),
        _booking(entry: null),
        now: _start.subtract(const Duration(hours: 2)),
      );
      expect(find.text('Đưa mã cho Minh Trí khi gặp'), findsOneWidget);
      expect(find.textContaining('vé vào cửa'), findsNothing);
    });

    testWidgets('full screen raises the brightness and gives it back', (
      tester,
    ) async {
      final w = _World();
      await _open(
        tester,
        w,
        _booking(),
        now: _start.subtract(const Duration(hours: 2)),
      );
      await tester.tap(find.byKey(const Key('pass-card')));
      await _settle(tester);
      expect(find.byKey(const Key('pass-qr-full')), findsOneWidget);
      expect(w.brightness.raised, isTrue);
      await tester.tap(find.byKey(const Key('pass-qr-full')));
      await _settle(tester);
      expect(find.byKey(const Key('pass-qr-full')), findsNothing);
      expect(w.brightness.calls, ['raise', 'restore']);
    });

    testWidgets('offline: the saved code still draws the QR', (tester) async {
      final w = _World()..passes.failWith = Exception('offline');
      await _open(
        tester,
        w,
        _booking(),
        now: _start.subtract(const Duration(hours: 2)),
        saved: {'pass.b1': _code},
      );
      expect(find.text('VE-7K2Q-4R9X'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('the timeline has "Đang chụp", current after the scan', (
      tester,
    ) async {
      await _open(
        tester,
        _World(),
        _booking(
          status: BookingStatus.shooting,
          checkedInAt: _start.add(const Duration(minutes: 5)),
        ),
        now: _start.add(const Duration(minutes: 30)),
      );
      expect(find.text('Đang chụp'), findsWidgets);
      expect(find.text('Hôm nay 15:35'), findsOneWidget);
    });

    testWidgets('entry lines: included, or to buy at the gate', (tester) async {
      await _open(
        tester,
        _World(),
        _booking(),
        now: _start.subtract(const Duration(days: 3)),
      );
      expect(find.text('Đã gồm vé vào cửa cho bạn và thợ'), findsOneWidget);

      final w = _World();
      w.spots.seedSpot(
        makeSpot(
          id: 'bd',
          access: SpotAccess(
            type: SpotAccessType.ticket,
            fees: const [AccessFee(label: 'Người lớn', amountVnd: 70000)],
            updatedAt: _start,
            source: SpotAccessSource.staff,
          ),
        ),
      );
      await _open(
        tester,
        w,
        _booking(entry: null, spotId: 'bd'),
        now: _start.subtract(const Duration(days: 3)),
      );
      expect(find.text('Tự mua tại cổng ≈ 140.000₫'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('fits 320 dp at 1.3× text (${b.name})', (tester) async {
        await _open(
          tester,
          _World(),
          _booking(),
          now: _start.subtract(const Duration(hours: 2)),
          brightness: b,
          textScale: 1.3,
          size: const Size(320, 2400),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('pass-card')), findsOneWidget);
      });
    }
  });

  group('S05.02-askshot', () {
    final asked = _end.add(const Duration(hours: 24));

    testWidgets('appears when shootQuestionAt is set; "Có, đã chụp" answers', (
      tester,
    ) async {
      final repo = RecordingBookingRepository();
      await _open(
        tester,
        _World(),
        _booking(askedAt: asked),
        now: asked.add(const Duration(hours: 1)),
        repo: repo,
      );
      expect(find.text('Buổi chụp có diễn ra không?'), findsOneWidget);
      expect(
        find.text(
          'Minh Trí chưa quét mã của bạn hôm T2 12/10. Cho chúng tôi biết để giữ đúng tiền của bạn.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Không trả lời trong 48 giờ thì coi như đã chụp.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ask-shot-send')));
      await _settle(tester);
      expect(repo.shootAnswers.single, (bookingId: 'b1', happened: true));
      expect(find.text('Buổi chụp có diễn ra không?'), findsNothing);
    });

    testWidgets('"Không diễn ra" opens S18.01 with the preset reason', (
      tester,
    ) async {
      final repo = RecordingBookingRepository();
      final w = _World();
      await _open(
        tester,
        w,
        _booking(askedAt: asked),
        now: asked.add(const Duration(hours: 1)),
        repo: repo,
      );
      await tester.tap(find.text('Không diễn ra'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('ask-shot-send')));
      await _settle(tester);
      expect(repo.shootAnswers.single, (bookingId: 'b1', happened: false));
      expect(
        find.byWidgetPredicate(
          (x) => x is ScreenCode && x.code == ScreenCodes.openDispute,
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('dispute-description')),
        'Thợ không tới, đợi 1 tiếng.',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('dispute-submit')));
      await tester.tap(find.byKey(const Key('dispute-submit')));
      await _settle(tester);
      expect(w.disputes.repo.opened.single.reason, DisputeReason.noShow);
    });

    testWidgets('no sheet once scanned, answered or for the photographer', (
      tester,
    ) async {
      await _open(
        tester,
        _World(),
        _booking(askedAt: asked, deniedAt: asked.add(const Duration(hours: 1))),
        now: asked.add(const Duration(hours: 2)),
      );
      expect(find.text('Buổi chụp có diễn ra không?'), findsNothing);
      await _open(
        tester,
        _World(),
        _booking(askedAt: asked),
        now: asked.add(const Duration(hours: 1)),
        uid: detailPhotographerUid,
      );
      expect(find.text('Buổi chụp có diễn ra không?'), findsNothing);
    });
  });
}
