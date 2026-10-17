// test/features/verification/verify_identity_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/verification/verification_repository.dart';

import '../../support/verification_world.dart';

/// Today 9:12 in Vietnam.
final _at = DateTime.utc(2026, 10, 15, 2, 12);

/// An `in_progress` record with the phone done; [identity] adds a passed
/// check, [failure] a failed one, [attempts] today's tries.
Map<String, dynamic> _doc({
  bool identity = false,
  String? failure,
  int attempts = 0,
  DateTime? checkedAt,
}) => {
  'uid': 'u',
  'status': 'in_progress',
  'steps': {
    'phone': {'doneAt': _at},
    if (identity)
      'identity': {
        'method': 'vneid',
        'checkedAt': _at,
        'result': 'passed',
        'failure': null,
        'maskedName': 'NGUYỄN M** T**',
      }
    else if (failure != null)
      'identity': {
        'method': 'vneid',
        'checkedAt': checkedAt ?? _at,
        'result': 'failed',
        'failure': failure,
        'maskedName': null,
      },
  },
  'identityAttempts': {'dayKey': '2026-10-15', 'count': attempts},
  'freeResubmitsLeft': 1,
};

Future<VerificationWorld> _world(
  WidgetTester tester, {
  bool real = false,
  bool fee = false,
  double width = 390,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = VerificationWorld(
    startScreen: true,
    identityReal: real,
    feeRequired: fee,
  );
  await w.init();
  w.seedDoc(_doc());
  return w;
}

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  WidgetTester tester,
  VerificationWorld w, {
  String location = '/verify/identity',
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(w.app(location: location, textScale: textScale));
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

/// Labels of the primary (gradient) buttons on screen.
List<String> _primaryLabels(WidgetTester tester) => [
  for (final b in tester.widgetList<AppButton>(
    find.ancestor(
      of: find.byType(CtaSurface),
      matching: find.byType(AppButton),
    ),
  ))
    b.label,
];

List<String> _callNames(VerificationWorld w) => [
  for (final c in w.repo.calls) c.name,
];

const _vneid = 'Xác minh bằng VNeID';
const _nfcLink = 'Không dùng được VNeID? Quét chip CCCD';
const _failed = 'Chưa xác minh được. Thử lại hoặc dùng cách khác.';

void main() {
  testWidgets('VNeID screen matches the mock copy', (tester) async {
    final w = await _world(tester);
    await _open(tester, w);

    expect(find.text('Xác minh danh tính'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byType(StepProgress), findsOneWidget);
    expect(find.byIcon(AppIcons.badge), findsOneWidget);
    expect(find.text('Xác minh bằng căn cước điện tử'), findsOneWidget);
    expect(
      find.text(
        'Không cần gõ hay chụp giấy tờ: mở app VNeID, đồng ý chia sẻ rồi '
        'nhập mã PIN VNeID.',
      ),
      findsOneWidget,
    );
    expect(find.text('Chúng tôi chỉ nhận'), findsOneWidget);
    expect(find.text('Họ tên'), findsOneWidget);
    expect(find.text('Ngày sinh'), findsOneWidget);
    expect(find.text('Số định danh'), findsOneWidget);
    expect(find.byIcon(AppIcons.lock), findsOneWidget);
    expect(
      find.text(
        'Không lưu ảnh selfie. Dùng để khớp tên tài khoản nhận tiền và chống '
        'giả mạo; số định danh được mã hoá.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Bấm "Xác minh bằng VNeID" là bạn đồng ý chia sẻ ba thông tin trên.',
      ),
      findsOneWidget,
    );
    expect(find.text(_nfcLink), findsOneWidget);
    expect(_primaryLabels(tester), [_vneid]);
    final code = tester.widget<ScreenCode>(find.byType(ScreenCode));
    expect(code.code, ScreenCodes.verifyIdentity);
    expect(code.label, isNull);
  });

  testWidgets('fake mode: Xác minh bằng VNeID starts a vneid session, the '
      'fake sheet agrees and the result shows Đã xác minh: NGUYỄN M** T**, '
      'then returns to S21.02', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app(location: '/profile'));
    await _settle(tester);
    w.router.push('/verify/start');
    await _settle(tester);
    await _tap(tester, find.byKey(const Key('verify-next')));
    expect(w.router.state.uri.path, '/verify/identity');

    await _tap(tester, find.text(_vneid));
    expect(w.repo.calls.first.name, 'startIdentityVerification');
    expect(w.repo.calls.first.data, {'method': 'vneid'});
    expect(find.text('VNeID (giả lập)'), findsOneWidget);
    expect(
      find.text(
        'Môi trường thử: không mở app VNeID thật. Bấm Đồng ý để nhận một '
        'danh tính thử.',
      ),
      findsOneWidget,
    );
    expect(w.launcher.opened, isEmpty);

    await _tap(tester, find.text('Đồng ý chia sẻ'));
    expect(_callNames(w), [
      'startIdentityVerification',
      'completeIdentityVerification',
    ]);
    expect(w.repo.calls.last.data, {'sessionId': 'fake-session'});
    expect(find.text('Đã xác minh: NGUYỄN M** T**'), findsOneWidget);
    expect(_primaryLabels(tester), ['Tiếp tục']);

    await _tap(tester, find.text('Tiếp tục'));
    expect(w.router.state.uri.path, '/verify/start');
    expect(find.text('Đã khớp qua VNeID'), findsOneWidget);
    // Popped back onto S21.02, which still has the profile below it.
    expect(w.router.canPop(), isTrue);
  });

  testWidgets('closing the fake sheet completes nothing', (tester) async {
    final w = await _world(tester);
    await _open(tester, w);
    await _tap(tester, find.text(_vneid));
    expect(find.text('VNeID (giả lập)'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);
    expect(find.text('VNeID (giả lập)'), findsNothing);
    expect(_callNames(w), ['startIdentityVerification']);
    expect(_primaryLabels(tester), [_vneid]);
  });

  testWidgets('real mode opens redirectUrl and waits for the listener', (
    tester,
  ) async {
    final w = await _world(tester, real: true);
    w.repo.identitySession = const IdentitySession(
      sessionId: 's-real',
      redirectUrl: 'https://vneid.test/consent/s-real',
    );
    await _open(tester, w);

    await _tap(tester, find.text(_vneid));
    expect(w.launcher.opened, [Uri.parse('https://vneid.test/consent/s-real')]);
    expect(find.text('VNeID (giả lập)'), findsNothing);
    expect(_callNames(w), ['startIdentityVerification']);
    expect(find.textContaining('Đã xác minh'), findsNothing);

    // The vendor reports to the server; the record changes.
    w.repo.seed(w.uid, _doc(identity: true));
    await _settle(tester);
    expect(find.text('Đã xác minh: NGUYỄN M** T**'), findsOneWidget);
    expect(_callNames(w), ['startIdentityVerification']);
  });

  testWidgets('real mode: a failure on the record shows its message', (
    tester,
  ) async {
    final w = await _world(tester, real: true);
    w.repo.identitySession = const IdentitySession(
      sessionId: 's-real',
      redirectUrl: 'https://vneid.test/consent/s-real',
    );
    await _open(tester, w);
    await _tap(tester, find.text(_vneid));
    // The start counted the try (server model); nothing is decided yet.
    expect((w.repo.doc(w.uid)!['identityAttempts'] as Map)['count'], 1);
    expect(find.text(_failed), findsNothing);

    // The check finishes as failed: a new checkedAt on the record.
    w.repo.seed(
      w.uid,
      _doc(failure: 'provider_failed', attempts: 1, checkedAt: verificationNow),
    );
    await _settle(tester);
    expect(
      find.text('Chưa xác minh được. Thử lại hoặc dùng cách khác.'),
      findsOneWidget,
    );
    expect(_primaryLabels(tester), [_vneid]);
  });

  testWidgets('real mode: an older failure on the record is not this '
      'session\'s result; it waits, then shows the pass', (tester) async {
    final w = await _world(tester, real: true);
    // Failed once earlier today; a retry is offered.
    w.seedDoc(_doc(failure: 'provider_failed', attempts: 1));
    w.repo.identitySession = const IdentitySession(
      sessionId: 's-real',
      redirectUrl: 'https://vneid.test/consent/s-real',
    );
    await _open(tester, w);
    expect(find.text(_failed), findsNothing);

    await _tap(tester, find.text(_vneid));
    // The start snapshot (try counted, old failure still there) arrived.
    expect((w.repo.doc(w.uid)!['identityAttempts'] as Map)['count'], 2);
    expect(find.text(_failed), findsNothing);
    expect(
      tester.widget<AppButton>(find.byKey(const Key('verify-vneid'))).loading,
      isTrue,
    );

    w.repo.seed(w.uid, _doc(identity: true, attempts: 2));
    await _settle(tester);
    expect(find.text('Đã xác minh: NGUYỄN M** T**'), findsOneWidget);
    expect(_callNames(w), ['startIdentityVerification']);
  });

  testWidgets('a final reason shows ahead of the daily limit', (tester) async {
    final w = await _world(tester);
    w.seedDoc(_doc(failure: 'underage', attempts: 3));
    await _open(tester, w);

    expect(find.text('Bạn cần đủ 18 tuổi để nhận đơn.'), findsOneWidget);
    expect(
      find.text('Bạn đã thử 3 lần hôm nay. Thử lại vào ngày mai.'),
      findsNothing,
    );
    expect(_primaryLabels(tester), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    final w2 = await _world(tester);
    w2.seedDoc(_doc(failure: 'identity_in_use', attempts: 3));
    await _open(tester, w2);
    expect(find.textContaining('Danh tính này đã gắn'), findsOneWidget);
    expect(find.textContaining('Bạn đã thử 3 lần'), findsNothing);
  });

  testWidgets('underage shows verifyIdUnderage and no retry button', (
    tester,
  ) async {
    final w = await _world(tester);
    w.repo.completeFailWith = 'underage';
    await _open(tester, w);
    await _tap(tester, find.text(_vneid));
    await _tap(tester, find.text('Đồng ý chia sẻ'));

    expect(find.text('Bạn cần đủ 18 tuổi để nhận đơn.'), findsOneWidget);
    expect(_primaryLabels(tester), isEmpty);
    expect(find.text(_vneid), findsNothing);
    expect(find.text(_nfcLink), findsNothing);
  });

  testWidgets('identity_in_use shows verifyIdInUse', (tester) async {
    final w = await _world(tester);
    w.repo.completeFailWith = 'identity_in_use';
    await _open(tester, w);
    await _tap(tester, find.text(_vneid));
    await _tap(tester, find.text('Đồng ý chia sẻ'));

    expect(
      find.text(
        'Danh tính này đã gắn với một tài khoản nhận đơn khác. Liên hệ hỗ '
        'trợ nếu đây là nhầm lẫn.',
      ),
      findsOneWidget,
    );
    expect(_primaryLabels(tester), isEmpty);
  });

  testWidgets('rate_limited shows verifyIdRateLimited', (tester) async {
    final w = await _world(tester);
    w.repo.failWith = 'rate_limited';
    await _open(tester, w);
    await _tap(tester, find.text(_vneid));

    expect(
      find.text('Bạn đã thử 3 lần hôm nay. Thử lại vào ngày mai.'),
      findsOneWidget,
    );
    expect(_primaryLabels(tester), isEmpty);
    expect(find.text('VNeID (giả lập)'), findsNothing);
  });

  testWidgets('no tries left today shows verifyIdRateLimited on arrival', (
    tester,
  ) async {
    final w = await _world(tester);
    w.seedDoc(_doc(failure: 'provider_failed', attempts: 3));
    await _open(tester, w);

    expect(
      find.text('Bạn đã thử 3 lần hôm nay. Thử lại vào ngày mai.'),
      findsOneWidget,
    );
    expect(_primaryLabels(tester), isEmpty);
  });

  testWidgets('not_eligible shows verifyIdFailed', (tester) async {
    final w = await _world(tester);
    w.repo.completeFailWith = 'not_eligible';
    await _open(tester, w);
    await _tap(tester, find.text(_vneid));
    await _tap(tester, find.text('Đồng ý chia sẻ'));

    expect(
      find.text('Chưa xác minh được. Thử lại hoặc dùng cách khác.'),
      findsOneWidget,
    );
    // A retry and the other method stay offered.
    expect(_primaryLabels(tester), [_vneid]);
    expect(find.text(_nfcLink), findsOneWidget);
  });

  testWidgets('an unexpected error starting shows verifyIdFailed and back '
      'leaves the screen', (tester) async {
    final w = await _world(tester);
    w.repo.startThrows = StateError('boom');
    await tester.pumpWidget(w.app(location: '/profile'));
    await _settle(tester);
    w.router.push('/verify/identity');
    await _settle(tester);

    await _tap(tester, find.text(_vneid));
    expect(find.text(_failed), findsOneWidget);
    expect(_primaryLabels(tester), [_vneid]);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(w.router.state.uri.path, '/profile');
  });

  testWidgets('an unexpected error completing shows verifyIdFailed and back '
      'leaves the screen', (tester) async {
    final w = await _world(tester);
    w.repo.completeThrows = TimeoutException('complete');
    await tester.pumpWidget(w.app(location: '/profile'));
    await _settle(tester);
    w.router.push('/verify/identity');
    await _settle(tester);

    await _tap(tester, find.text(_vneid));
    await _tap(tester, find.text('Đồng ý chia sẻ'));
    expect(find.text(_failed), findsOneWidget);
    expect(_primaryLabels(tester), [_vneid]);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(w.router.state.uri.path, '/profile');
  });

  testWidgets('Quét chip CCCD opens step 1/2, Bắt đầu quét moves to the '
      'selfie step, Bắt đầu chụp completes an nfc session', (tester) async {
    final w = await _world(tester);
    await _open(tester, w);
    await _tap(tester, find.text(_nfcLink));

    expect(find.text('Quét chip CCCD'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Bước 1/2 · Đọc chip'), findsOneWidget);
    expect(find.text('Bước 2/2 · Selfie'), findsOneWidget);
    expect(find.text('Áp CCCD vào mặt sau điện thoại'), findsOneWidget);
    expect(
      find.text(
        'Giữ yên thẻ ở giữa lưng máy tới khi máy rung. Tháo ốp lưng dày nếu '
        'đọc chậm.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tiếp theo'), findsOneWidget);
    expect(find.text('Chụp selfie để kiểm tra người thật'), findsOneWidget);
    expect(
      find.text(
        'Máy cần có NFC. Ảnh selfie chỉ dùng để so với ảnh trong chip, '
        'không lưu.',
      ),
      findsOneWidget,
    );
    expect(_primaryLabels(tester), ['Bắt đầu quét']);
    expect(tester.widget<ScreenCode>(find.byType(ScreenCode)).label, 'nfc');

    await _tap(tester, find.text('Bắt đầu quét'));
    expect(w.repo.calls.single.data, {'method': 'nfc'});
    expect(find.text('Chụp selfie 3–5 giây'), findsOneWidget);
    expect(
      find.text(
        'Nhìn thẳng vào camera, quay đầu chậm sang trái rồi sang phải.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Ảnh selfie chỉ dùng để so với ảnh trong chip, không lưu.'),
      findsOneWidget,
    );
    expect(_primaryLabels(tester), ['Bắt đầu chụp']);

    await _tap(tester, find.text('Bắt đầu chụp'));
    expect(_callNames(w), [
      'startIdentityVerification',
      'completeIdentityVerification',
    ]);
    expect(find.text('Đã xác minh: NGUYỄN M** T**'), findsOneWidget);
    final steps = (w.repo.doc(w.uid)!['steps'] as Map)['identity'] as Map;
    expect(steps['method'], 'nfc');
  });

  testWidgets('method=nfc opens the chip screen; back returns to VNeID only '
      'when VNeID was the start', (tester) async {
    final w = await _world(tester);
    await _open(tester, w, location: '/verify/identity?method=nfc');
    expect(find.text('Bước 1/2 · Đọc chip'), findsOneWidget);

    await _open(tester, w);
    await _tap(tester, find.text(_nfcLink));
    expect(find.text('Bước 1/2 · Đọc chip'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text(_nfcLink), findsOneWidget);
    expect(w.router.state.uri.path, '/verify/identity');
  });

  testWidgets('with the fee off the identity step opens without a payment', (
    tester,
  ) async {
    final w = await _world(tester);
    await _open(tester, w, location: '/verify/start');
    await _tap(tester, find.byKey(const Key('verify-next')));

    expect(w.router.state.uri.path, '/verify/identity');
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.textContaining('Phí xác minh'), findsNothing);
    expect(_primaryLabels(tester), [_vneid]);
    await _tap(tester, find.text(_vneid));
    expect(_callNames(w), ['startIdentityVerification']);
  });

  testWidgets('the identity step is disabled until the fee is paid (tap '
      'opens the fee route)', (tester) async {
    final w = await _world(tester, fee: true);
    await _open(tester, w);

    expect(find.text('3 / 4'), findsOneWidget);
    await _tap(tester, find.text(_vneid));
    expect(_callNames(w), isEmpty);
    expect(w.router.state.uri.path, '/verify/start/fee');

    // The chip fallback is closed the same way.
    await tester.pumpWidget(const SizedBox.shrink());
    final w2 = await _world(tester, fee: true);
    await _open(tester, w2, location: '/verify/identity?method=nfc');
    await _tap(tester, find.text('Bắt đầu quét'));
    expect(_callNames(w2), isEmpty);
    expect(w2.router.state.uri.path, '/verify/start/fee');

    // Paid: the identity starts.
    await tester.pumpWidget(const SizedBox.shrink());
    final w3 = await _world(tester, fee: true);
    w3.seedDoc({
      ..._doc(),
      'steps': {
        ...(_doc()['steps'] as Map<String, dynamic>),
        'fee': {'paymentId': 'pay1', 'amount': 99000, 'paidAt': _at},
      },
    });
    await _open(tester, w3);
    await _tap(tester, find.text(_vneid));
    expect(_callNames(w3), ['startIdentityVerification']);
  });

  testWidgets('an identity already passed shows the result', (tester) async {
    final w = await _world(tester);
    w.seedDoc(_doc(identity: true));
    await _open(tester, w);

    expect(find.text('Đã xác minh: NGUYỄN M** T**'), findsOneWidget);
    expect(_primaryLabels(tester), ['Tiếp tục']);
    // Opened on its own: Tiếp tục goes to S21.02.
    await _tap(tester, find.text('Tiếp tục'));
    expect(w.router.state.uri.path, '/verify/start');
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    final w = await _world(tester, width: 320, height: 640);
    await _open(tester, w, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text(_nfcLink));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Bắt đầu quét'));
    expect(tester.takeException(), isNull);
  });
}
