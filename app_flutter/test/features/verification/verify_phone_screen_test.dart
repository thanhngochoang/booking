// test/features/verification/verify_phone_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/verification/phone_verifier.dart';

import '../../support/verification_world.dart';

const _fromStart = '/verify/phone?returnTo=%2Fverify%2Fstart';

Finder get _phoneInput => find.descendant(
  of: find.byKey(const Key('verify-phone')),
  matching: find.byType(TextFormField),
);

Finder get _codeInput => find.descendant(
  of: find.byKey(const Key('verify-code')),
  matching: find.byType(TextField),
);

Future<VerificationWorld> _world({bool feeRequired = false}) async {
  final w = VerificationWorld(feeRequired: feeRequired);
  await w.init();
  return w;
}

Future<void> _open(
  WidgetTester tester,
  VerificationWorld w, {
  String location = '/verify/phone',
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(w.app(location: location, textScale: textScale));
  await tester.pump();
  await tester.pump();
}

Future<void> _send(WidgetTester tester, {String? number}) async {
  if (number != null) {
    await tester.enterText(_phoneInput, number);
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('verify-send')));
  await tester.pump();
  await tester.pump();
}

Future<void> _confirm(WidgetTester tester, String code) async {
  await tester.enterText(_codeInput, code);
  await tester.pump();
  await tester.tap(find.byKey(const Key('verify-confirm')));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

bool _enabled(WidgetTester tester, Key key) =>
    tester
        .widget<FilledButton>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('prefills the saved number', (tester) async {
    final w = await _world();
    w.seedContact('+84912345678');
    await _open(tester, w);

    expect(
      tester.widget<TextFormField>(_phoneInput).controller!.text,
      '912 345 678',
    );
    expect(find.text('Xác minh số điện thoại'), findsOneWidget);
    expect(find.text('Nhập số điện thoại của bạn'), findsOneWidget);
    expect(find.text('Ví dụ: 0912 345 678.'), findsOneWidget);
    expect(find.text('Gửi mã'), findsOneWidget);
  });

  testWidgets('an invalid number shows verifyPhoneInvalid and does not send', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);

    await _send(tester, number: '12345');

    expect(
      find.text('Số điện thoại chưa đúng. Ví dụ: 0912 345 678.'),
      findsOneWidget,
    );
    expect(w.verifier.sent, isEmpty);
    expect(find.byType(OtpCodeField), findsNothing);
  });

  testWidgets('Gửi mã sends and shows the code step with the last 4 digits', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);

    await _send(tester, number: '0912345678');

    expect(w.verifier.sent, ['+84912345678']);
    expect(find.text('Nhập mã 6 số'), findsOneWidget);
    expect(find.text('Đã gửi tới •••• 5678'), findsOneWidget);
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(find.text('Đổi số điện thoại'), findsOneWidget);
    expect(_enabled(tester, const Key('verify-confirm')), isFalse);
  });

  testWidgets('a different number is saved to the contact first', (
    tester,
  ) async {
    final w = await _world();
    w.seedContact('+84903123456', allowZalo: false, allowWhatsApp: true);
    await _open(tester, w);

    await _send(tester, number: '912345678');
    expect(w.log, isEmpty, reason: 'nothing is saved before the code');
    await _confirm(tester, FakePhoneVerifier.validCode);

    expect(w.log, ['link:+84912345678', 'save:+84912345678', 'confirm']);
    final saved = w.contacts.stored(w.uid)!;
    expect(saved.phone, '+84912345678');
    expect(saved.allowZalo, isFalse);
    expect(saved.allowWhatsApp, isTrue);
  });

  testWidgets('Xác nhận links, calls confirmPhoneVerified and returns to '
      'returnTo', (tester) async {
    final w = await _world();
    w.seedContact('+84912345678');
    await _open(tester, w, location: _fromStart);

    await _send(tester);
    await _confirm(tester, FakePhoneVerifier.validCode);
    await tester.pump();

    expect(w.verifier.linked, ['+84912345678']);
    expect(w.repo.calls.map((c) => c.name), ['confirmPhoneVerified']);
    expect(w.log, [
      'link:+84912345678',
      'confirm',
    ], reason: 'the same number is not saved again');
    expect(find.text('stub /verify/start'), findsOneWidget);
  });

  testWidgets('a wrong code shows verifyCodeWrong and keeps the step', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);
    await _send(tester, number: '912345678');

    await _confirm(tester, '000000');

    expect(find.text('Mã không đúng. Kiểm tra lại tin nhắn.'), findsOneWidget);
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(find.text('Đã gửi tới •••• 5678'), findsOneWidget);
    expect(w.repo.calls, isEmpty);
  });

  testWidgets('an expired code shows verifyCodeExpired', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await _send(tester, number: '912345678');
    w.verifier.confirmError = PhoneVerifyErrorCode.codeExpired;

    await _confirm(tester, FakePhoneVerifier.validCode);

    expect(find.text('Mã đã hết hạn. Bấm Gửi lại mã.'), findsOneWidget);
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(w.repo.calls, isEmpty);
  });

  testWidgets('alreadyInUse shows verifyPhoneInUse under the field', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w);
    await _send(tester, number: '912345678');
    w.verifier.confirmError = PhoneVerifyErrorCode.alreadyInUse;

    await _confirm(tester, FakePhoneVerifier.validCode);

    expect(find.byType(OtpCodeField), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('verify-phone')),
        matching: find.text('Số này đã gắn với một tài khoản khác.'),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(_phoneInput).controller!.text,
      '912 345 678',
    );
    expect(w.log, isEmpty);
  });

  testWidgets('tooManyRequests shows verifyPhoneTooMany', (tester) async {
    final w = await _world();
    await _open(tester, w);
    w.verifier.sendError = PhoneVerifyErrorCode.tooManyRequests;

    await _send(tester, number: '912345678');

    expect(
      find.text('Bạn đã thử quá nhiều lần. Thử lại sau ít phút.'),
      findsOneWidget,
    );
    expect(find.byType(OtpCodeField), findsNothing);
  });

  testWidgets('resend is disabled for 60 s and enabled after', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await _send(tester, number: '912345678');

    expect(find.text('Gửi lại mã sau 1:00'), findsOneWidget);
    expect(find.byKey(const Key('verify-resend')), findsNothing);
    for (var second = 1; second <= 61; second++) {
      await tester.pump(const Duration(seconds: 1));
      if (second == 18) {
        expect(find.text('Gửi lại mã sau 0:42'), findsOneWidget);
        expect(find.byKey(const Key('verify-resend')), findsNothing);
      }
    }
    expect(find.textContaining('Gửi lại mã sau'), findsNothing);
    expect(find.byKey(const Key('verify-resend')), findsOneWidget);

    await tester.tap(find.byKey(const Key('verify-resend')));
    await tester.pump();
    await tester.pump();

    expect(w.verifier.sent, ['+84912345678', '+84912345678']);
    expect(w.verifier.resendTokens, [null, 1]);
    expect(find.text('Gửi lại mã sau 1:00'), findsOneWidget);
  });

  testWidgets('Đổi số điện thoại returns to the number step', (tester) async {
    final w = await _world();
    await _open(tester, w);
    await _send(tester, number: '912345678');

    await tester.tap(find.text('Đổi số điện thoại'));
    await tester.pump();

    expect(find.byType(OtpCodeField), findsNothing);
    expect(
      tester.widget<TextFormField>(_phoneInput).controller!.text,
      '912 345 678',
    );
    expect(find.text('Gửi mã'), findsOneWidget);
    // The countdown stopped: nothing ticks after leaving the code step.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('an already verified number shows the done state and Tiếp tục', (
    tester,
  ) async {
    final w = await _world();
    w.seedContact('+84912345678', verified: true);
    await _open(tester, w, location: _fromStart);

    expect(find.text('Đã xác minh số điện thoại'), findsOneWidget);
    expect(find.byType(PhoneField), findsNothing);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.text('stub /verify/start'), findsOneWidget);
    expect(w.verifier.sent, isEmpty);
  });

  testWidgets('shows 1 / 3 and the step bar only inside the S21.02 flow', (
    tester,
  ) async {
    final w = await _world();
    await _open(tester, w, location: _fromStart);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byType(StepProgress), findsOneWidget);

    final plain = await _world();
    await _open(tester, plain);
    expect(find.text('1 / 3'), findsNothing);
    expect(find.byType(StepProgress), findsNothing);
  });

  testWidgets('counts 1 / 4 once the fee step is on', (tester) async {
    final w = await _world(feeRequired: true);
    await _open(tester, w, location: _fromStart);
    expect(find.text('1 / 4'), findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = await _world();
    await _open(tester, w, location: _fromStart, textScale: 1.3);
    expect(tester.takeException(), isNull);

    await _send(tester, number: '912345678');
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _confirm(tester, '000000');
    expect(tester.takeException(), isNull);
  });
}
