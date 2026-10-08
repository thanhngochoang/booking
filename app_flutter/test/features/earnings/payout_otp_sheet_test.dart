import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/features/earnings/widgets/payout_otp_sheet.dart';

import '../../support/screen_host.dart';

const _ticket = PayoutOtpTicket(
  phoneLast4: '4567',
  expiresInSeconds: 300,
  resendInSeconds: 60,
);

/// The confirm button's ring spins while a code is checked: bounded pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Host {
  DateTime now = DateTime.utc(2026, 10, 8, 2);
  final submitted = <String>[];
  final results = <bool>[];
  var resends = 0;
  List<PayoutOtpSubmit> answers = [PayoutOtpSubmit.saved];
  PayoutOtpTicket? resendAnswer = _ticket;

  Future<void> open(
    WidgetTester tester, {
    double width = 390,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screenApp(
        textScale: textScale,
        overrides: [clockProvider.overrideWithValue(() => now)],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showPayoutOtpSheet(
                  context,
                  ticket: _ticket,
                  onSubmit: (code) async {
                    submitted.add(code);
                    return answers.length > 1
                        ? answers.removeAt(0)
                        : answers.single;
                  },
                  onResend: () async {
                    resends++;
                    return resendAnswer;
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
  }

  /// Moves the clock and the timers together.
  Future<void> wait(WidgetTester tester, Duration d) async {
    now = now.add(d);
    await tester.pump(d);
  }
}

Finder _confirm() => find.widgetWithText(AppButton, 'Xác nhận đổi tài khoản');

void main() {
  testWidgets('shows the title, the last 4 of the phone, the note and one '
      'primary in the mock order', (tester) async {
    final h = _Host();
    await h.open(tester);
    final texts = [
      'Nhập mã xác nhận',
      'Mã 6 số đã gửi tới số điện thoại •••• 4567. Mã có hiệu lực 5 phút.',
      'Mã OTP',
      'Gửi lại sau 60 giây',
      'Tài khoản mới có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi.',
      'Xác nhận đổi tài khoản',
    ];
    final ys = [for (final t in texts) tester.getTopLeft(find.text(t)).dy];
    expect(ys, [...ys]..sort(), reason: 'mock order');
    expect(find.byType(CtaSurface), findsOneWidget, reason: 'one primary');
    expect(tester.widget<AppButton>(_confirm()).onPressed, isNull);
  });

  testWidgets('OTP sheet: resend is disabled for 60 s then enabled', (
    tester,
  ) async {
    final h = _Host();
    await h.open(tester);
    expect(find.text('Gửi lại sau 60 giây'), findsOneWidget);
    expect(find.text('Gửi lại mã'), findsNothing);
    await h.wait(tester, const Duration(seconds: 18));
    expect(find.text('Gửi lại sau 42 giây'), findsOneWidget);
    await h.wait(tester, const Duration(seconds: 41));
    expect(find.text('Gửi lại sau 1 giây'), findsOneWidget);
    await h.wait(tester, const Duration(seconds: 1));
    expect(find.text('Gửi lại mã'), findsOneWidget);
    await tester.tap(find.text('Gửi lại mã'));
    await _settle(tester);
    expect(h.resends, 1);
    expect(find.text('Gửi lại sau 60 giây'), findsOneWidget, reason: 'again');
    // Let the new countdown finish so no timer is left running.
    await h.wait(tester, const Duration(seconds: 60));
  });

  testWidgets('a refused resend shows the daily limit', (tester) async {
    final h = _Host()..resendAnswer = null;
    await h.open(tester);
    await h.wait(tester, const Duration(seconds: 60));
    await tester.tap(find.text('Gửi lại mã'));
    await _settle(tester);
    expect(
      find.text('Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai.'),
      findsOneWidget,
    );
  });

  testWidgets('the 6th digit submits; saved closes the sheet with true', (
    tester,
  ) async {
    final h = _Host();
    await h.open(tester);
    await tester.enterText(find.byType(TextField), '482913');
    await _settle(tester);
    expect(h.submitted, ['482913']);
    expect(h.results, [true]);
    expect(find.text('Nhập mã xác nhận'), findsNothing);
  });

  testWidgets('a wrong code keeps the sheet open with the error', (
    tester,
  ) async {
    final h = _Host()..answers = [PayoutOtpSubmit.wrong, PayoutOtpSubmit.saved];
    await h.open(tester);
    await tester.enterText(find.byType(TextField), '111111');
    await _settle(tester);
    expect(find.text('Mã chưa đúng. Kiểm tra lại tin nhắn'), findsOneWidget);
    expect(h.results, isEmpty);
    await tester.enterText(find.byType(TextField), '482913');
    await _settle(tester);
    expect(h.submitted, ['111111', '482913']);
    expect(h.results, [true]);
    await h.wait(tester, const Duration(seconds: 60));
  });

  for (final (answer, text) in [
    (PayoutOtpSubmit.expired, 'Mã đã hết hạn. Gửi lại mã mới'),
    (PayoutOtpSubmit.tooMany, 'Bạn đã nhập sai quá nhiều lần. Gửi lại mã mới'),
  ]) {
    testWidgets('${answer.name} shows "$text"', (tester) async {
      final h = _Host()..answers = [answer];
      await h.open(tester);
      await tester.enterText(find.byType(TextField), '111111');
      await _settle(tester);
      expect(find.text(text), findsOneWidget);
      expect(h.results, isEmpty);
      await h.wait(tester, const Duration(seconds: 60));
    });
  }

  testWidgets('failed closes the sheet with false', (tester) async {
    final h = _Host()..answers = [PayoutOtpSubmit.failed];
    await h.open(tester);
    await tester.enterText(find.byType(TextField), '111111');
    await _settle(tester);
    expect(h.results, [false]);
  });

  testWidgets('fits 320 dp at 1.3× text', (tester) async {
    final h = _Host()..answers = [PayoutOtpSubmit.wrong];
    await h.open(tester, width: 320, textScale: 1.3);
    await tester.enterText(find.byType(TextField), '111111');
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_confirm()).height, greaterThanOrEqualTo(48));
    await h.wait(tester, const Duration(seconds: 60));
  });
}
