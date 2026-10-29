// S30.07 `/scan` (+ S30.07-booking, S30.07-error). No camera: the scanner
// is a fake that emits codes; `scanPass` is scripted.
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/passes/pass_repository.dart';
import 'package:photobooking/features/scan/scan_controller.dart';
import 'package:photobooking/features/scan/scan_result_sheet.dart';

import '../../support/booking_fixtures.dart';
import '../../support/organizer_world.dart';
import '../../support/scan_world.dart';

const _code = 'VE-7K2Q-4R9X';
const _norm = '7K2Q4R9X';

ScanResult _entryResult({int qty = 3, int? today}) => ScanResult(
  registrations: [
    ScanRegistration(
      id: 'r1',
      eventTitle: 'Vé vào cửa',
      quantity: qty,
      kind: ScanKind.entry,
    ),
  ],
  todayCount: today,
);

Future<void> _scan(WidgetTester tester, ScanWorld w, String code) async {
  w.scanner.emit(code);
  await settleScan(tester);
}

ScanWorld _gateWorld() {
  final w = ScanWorld();
  w.organizers.putOrganizer(makeOrganizer());
  w.spots.seedSpot(makeSpot(managedBy: 'org1'));
  w.spots.seedEntryEvent('bd', makeEntryEvent());
  w.organizers.putEntryDay(
    const EntryDay(
      eventId: 'ent1',
      day: organizerToday,
      sold: 182,
      checkedIn: 96,
    ),
  );
  return w;
}

void main() {
  test(
    'scanCodeOf: pass codes in any case, legacy ticket codes, else null',
    () {
      expect(scanCodeOf(' ve-7k2q-4r9x '), _norm);
      expect(scanCodeOf('7k2q4r9x'), _norm);
      expect(scanCodeOf('ve-ab2c-1013'), 'VE-AB2C-1013');
      expect(scanCodeOf('hello'), isNull);
    },
  );

  testWidgets('camera primer when denied, with Mở cài đặt', (tester) async {
    final w = ScanWorld()
      ..scanner.failure = PassScannerFailure.permissionDenied;
    await w.pump(tester);
    expect(find.byKey(const Key('scan-camera-primer')), findsOneWidget);
    expect(find.text('Cho phép dùng camera để quét mã'), findsOneWidget);
    // S30.07 has no gradient button: "Mở cài đặt" is an outline.
    final settings = find.text('Mở cài đặt');
    expect(
      find.ancestor(of: settings, matching: find.byType(OutlinedButton)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('scan-camera-primer')),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Mở cài đặt'));
    await settleScan(tester);
    expect(w.scanner.settingsOpened, 1);
    // The primer's "Nhập mã 8 ký tự" opens the manual sheet.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('scan-camera-primer')),
        matching: find.text('Nhập mã 8 ký tự'),
      ),
    );
    await settleScan(tester);
    expect(find.byKey(const Key('scan-manual-code')), findsOneWidget);
  });

  testWidgets('torch toggles', (tester) async {
    final w = ScanWorld();
    await w.pump(tester);
    await tester.tap(find.byKey(const Key('scan-torch')));
    await settleScan(tester);
    expect(w.scanner.torchToggles, 1);
  });

  testWidgets('manual 8-char sheet normalises case and refuses junk', (
    tester,
  ) async {
    final w = ScanWorld();
    w.passes.answerScan(_code, _entryResult());
    await w.pump(tester);
    await tester.tap(find.byKey(const Key('scan-manual')));
    await settleScan(tester);
    await tester.enterText(find.byKey(const Key('scan-manual-code')), 'abc');
    await tester.pump();
    await tester.tap(find.byKey(const Key('scan-manual-submit')));
    await settleScan(tester);
    expect(find.text('Mã gồm 8 ký tự chữ và số'), findsOneWidget);
    expect(w.passes.scans, isEmpty);

    await tester.enterText(
      find.byKey(const Key('scan-manual-code')),
      ' ve-7k2q-4r9x ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('scan-manual-submit')));
    await settleScan(tester);
    expect(w.passes.scans, [_norm]);
    expect(find.text('Đã vào · 3 người'), findsOneWidget);
  });

  testWidgets(
    'success: green sheet, short vibration, Quét tiếp 52 dp, closes after 3 s',
    (tester) async {
      final w = ScanWorld();
      w.passes.answerScan(_code, _entryResult());
      await w.pump(tester);
      await _scan(tester, w, _code);
      expect(find.byKey(const Key('scan-result-ok')), findsOneWidget);
      expect(find.text('Đã vào · 3 người'), findsOneWidget);
      expect(w.haptics, ['light']);
      expect(
        tester.getSize(find.byKey(const Key('scan-next'))).height,
        scanNextHeight,
      );
      // While the sheet is up another code is ignored.
      w.scanner.emit(_code);
      await settleScan(tester);
      expect(w.passes.scans, [_norm]);

      await tester.pump(scanAutoClose);
      await settleScan(tester);
      expect(find.byKey(const Key('scan-result-ok')), findsNothing);
      // Back to the camera: the next code is sent.
      await _scan(tester, w, _code);
      expect(w.passes.scans, [_norm, _norm]);
    },
  );

  testWidgets('Quét tiếp returns to the camera', (tester) async {
    final w = ScanWorld();
    w.passes.answerScan(_code, _entryResult());
    await w.pump(tester);
    await _scan(tester, w, _code);
    await tester.tap(find.byKey(const Key('scan-next')));
    await settleScan(tester);
    expect(find.byKey(const Key('scan-result-ok')), findsNothing);
  });

  testWidgets('venue gate and waived heads read Vào cổng', (tester) async {
    final w = ScanWorld();
    w.passes.answerScan(_code, const ScanResult(waivedCount: 2));
    await w.pump(tester);
    await _scan(tester, w, _code);
    expect(find.text('Vào cổng · 2 người'), findsOneWidget);
  });

  final errors = <(PassError, String)>[
    (
      const PassError(PassErrorCode.wrongDay, day: '2026-11-15'),
      'Vé ngày CN 15/11',
    ),
    (
      PassError(
        PassErrorCode.alreadyCheckedIn,
        at: DateTime.utc(2026, 11, 10, 0, 42),
      ),
      'Đã vào lúc 07:42',
    ),
    (
      PassError(PassErrorCode.tooEarly, opensAt: DateTime.utc(2026, 11, 9, 22)),
      'Mở quét từ 05:00',
    ),
    (const PassError(PassErrorCode.refunded), 'Vé đã hoàn'),
    (
      const PassError(PassErrorCode.notYourPass),
      'Mã này không thuộc sự kiện hoặc buổi chụp của bạn',
    ),
    (const PassError(PassErrorCode.notFound), 'Không tìm thấy mã'),
  ];
  for (final (error, text) in errors) {
    testWidgets('error ${error.code.name}: red sheet "$text", long vibration', (
      tester,
    ) async {
      final w = ScanWorld();
      w.passes.answerScan(_code, error);
      await w.pump(tester);
      await _scan(tester, w, _code);
      expect(find.byKey(const Key('scan-result-error')), findsOneWidget);
      expect(find.text(text), findsOneWidget);
      expect(w.haptics, ['vibrate']);
      // A refusal stays until "Quét tiếp".
      await tester.pump(scanAutoClose);
      await settleScan(tester);
      expect(find.byKey(const Key('scan-result-error')), findsOneWidget);
    });
  }

  testWidgets('wrong day explains how to change the day', (tester) async {
    final w = ScanWorld();
    w.passes.answerScan(
      _code,
      const PassError(PassErrorCode.wrongDay, day: '2026-11-15'),
    );
    await w.pump(tester);
    await _scan(tester, w, _code);
    expect(
      find.textContaining('Khách đổi ngày bằng cách huỷ vé'),
      findsOneWidget,
    );
  });

  testWidgets('offline keeps the code and Thử lại sends it again', (
    tester,
  ) async {
    final w = ScanWorld();
    w.passes.failWith = const SocketException('offline');
    await w.pump(tester);
    await _scan(tester, w, _code);
    expect(find.text('Chưa quét được, kiểm tra kết nối'), findsOneWidget);
    expect(find.textContaining('VE-7K2Q-4R9X'), findsOneWidget);

    w.passes.failWith = null;
    w.passes.answerScan(_code, _entryResult());
    await tester.tap(find.byKey(const Key('scan-retry')));
    await settleScan(tester);
    expect(w.passes.scans, [_norm, _norm]);
    expect(find.text('Đã vào · 3 người'), findsOneWidget);
  });

  testWidgets('a junk QR is Không tìm thấy mã without a call', (tester) async {
    final w = ScanWorld();
    await w.pump(tester);
    await _scan(tester, w, 'https://example.com');
    expect(find.text('Không tìm thấy mã'), findsOneWidget);
    expect(w.passes.scans, isEmpty);
  });

  testWidgets(
    'shooter (S30.07-booking): Đang chụp · {khách}, ticket line, Về buổi chụp',
    (tester) async {
      final w = ScanWorld(uid: 'p1');
      w.bookings.seedBooking(
        makeTestBooking(
          id: 'b1',
          status: BookingStatus.upcoming,
          day: organizerToday,
          start: '15:30',
          end: '17:30',
        ).copyWith(
          passCode4: '4R9X',
          entry: const BookingEntry(
            eventId: 'ent1',
            visitDay: organizerToday,
            providerTicket: true,
          ),
        ),
      );
      w.passes.answerScan(
        _code,
        const ScanResult(
          booking: ScanBooking(id: 'b1', customerName: 'Lan Anh'),
        ),
      );
      await w.pump(tester, location: '/scan?booking=b1');
      expect(find.text('Quét mã khách'), findsOneWidget);
      expect(find.byKey(const Key('scan-today')), findsNothing);
      await _scan(tester, w, _code);
      expect(find.text('Đang chụp · Lan Anh'), findsOneWidget);
      expect(
        find.text(
          'Khách đã mua vé vào cửa cho bạn qua app. Nhân viên cổng quét cùng mã này.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('scan-next')), findsNothing);
      await tester.tap(find.byKey(const Key('scan-back-to-shoot')));
      await settleScan(tester);
      expect(w.location, '/b/b1');
    },
  );

  testWidgets('the gate sees today\'s count, updated by its scans', (
    tester,
  ) async {
    final w = _gateWorld();
    w.passes.answerScan(_code, _entryResult(qty: 1, today: 97));
    await w.pump(tester);
    expect(find.text('Soát vé · Bãi đá sông Hồng'), findsOneWidget);
    expect(find.text('Hôm nay: 96 / 182 khách đã vào'), findsOneWidget);
    await _scan(tester, w, _code);
    await tester.tap(find.byKey(const Key('scan-next')));
    await settleScan(tester);
    expect(find.text('Hôm nay: 97 / 182 khách đã vào'), findsOneWidget);
  });

  testWidgets('active gate staff get the organizer\'s spot and count', (
    tester,
  ) async {
    final w = ScanWorld(uid: 'g1');
    w.organizers.putOrganizer(makeOrganizer());
    w.organizers.putGateStaff(
      GateStaff(
        organizerId: 'org1',
        staffUid: 'g1',
        status: GateStaffStatus.active,
        invitedAt: organizerNow.subtract(const Duration(days: 2)),
      ),
    );
    w.spots.seedSpot(makeSpot(managedBy: 'org1'));
    w.spots.seedEntryEvent('bd', makeEntryEvent());
    w.organizers.putEntryDay(
      const EntryDay(
        eventId: 'ent1',
        day: organizerToday,
        sold: 10,
        checkedIn: 4,
      ),
    );
    await w.pump(tester);
    expect(find.text('Hôm nay: 4 / 10 khách đã vào'), findsOneWidget);
  });

  testWidgets('the result shows within 2 s of the scan', (tester) async {
    final w = ScanWorld();
    w.passes
      ..scanDelay = const Duration(milliseconds: 1200)
      ..answerScan(_code, _entryResult());
    await w.pump(tester);
    w.scanner.emit(_code);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('scan-checking')), findsOneWidget);
    // The answer lands at 1.2 s: the sheet must be up by 1.3 s (< 2 s).
    await tester.pump(const Duration(milliseconds: 1150));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Đã vào · 3 người'), findsOneWidget);
  });

  testWidgets('closing the screen disposes the camera', (tester) async {
    final w = ScanWorld();
    await w.pump(tester);
    await tester.tap(find.byKey(const Key('scan-close')));
    await settleScan(tester);
    expect(w.scanner.disposed, isTrue);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text (${b.name})', (tester) async {
      final w = _gateWorld();
      w.passes.answerScan(_code, _entryResult());
      await w.pump(
        tester,
        width: 320,
        height: 640,
        brightness: b,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await _scan(tester, w, _code);
      expect(tester.takeException(), isNull);
      expect(find.text('Đã vào · 3 người'), findsOneWidget);
    });
    testWidgets('the primer fits 320 dp at 1.3× text (${b.name})', (
      tester,
    ) async {
      final w = ScanWorld()
        ..scanner.failure = PassScannerFailure.permissionDenied;
      await w.pump(
        tester,
        width: 320,
        height: 640,
        brightness: b,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
