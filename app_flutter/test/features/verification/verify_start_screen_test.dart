// test/features/verification/verify_start_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:photobooking/features/verification/widgets/verify_step_tile.dart';

import '../../support/verification_world.dart';

/// Today 9:12 in Vietnam.
final _sentAt = DateTime.utc(2026, 10, 15, 2, 12);

Map<String, dynamic> _doc({
  String status = 'in_progress',
  bool identity = false,
  bool rules = false,
  String method = 'vneid',
  DateTime? submittedAt,
  DateTime? decidedAt,
  String? reject,
  String? rejectText,
  int freeResubmitsLeft = 1,
}) => {
  'uid': 'u',
  'status': status,
  'steps': {
    'phone': {'doneAt': _sentAt},
    if (identity)
      'identity': {
        'method': method,
        'checkedAt': _sentAt,
        'result': 'passed',
        'failure': null,
        'maskedName': 'NGUYỄN M** T**',
      },
    if (rules) 'rules': {'acceptedAt': _sentAt, 'version': '2026-10-06'},
  },
  'submittedAt': submittedAt,
  'decidedAt': decidedAt,
  'rejectReason': reject == null ? null : {'code': reject, 'text': rejectText},
  'freeResubmitsLeft': freeResubmitsLeft,
};

Future<VerificationWorld> _world(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = VerificationWorld(startScreen: true);
  await w.init();
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
  String location = '/verify/start',
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(w.app(location: location, textScale: textScale));
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

Finder _tile(String step) => find.byKey(Key('verify-step-$step'));

Finder _inTile(String step, String text) =>
    find.descendant(of: _tile(step), matching: find.text(text));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

void main() {
  group('S21.02 steps', () {
    testWidgets('a new provider sees three steps without the fee, phone Đang '
        'làm, others Chưa làm, counter 1 / 3', (tester) async {
      final w = await _world(tester);
      w.seedDoc(null, phoneVerified: false);
      await _open(tester, w);

      expect(find.text('Bắt đầu nhận đơn'), findsOneWidget);
      expect(find.byKey(const Key('verify-counter')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.byType(VerifyStepTile), findsNWidgets(3));
      expect(find.byKey(const Key('verify-step-fee')), findsNothing);
      expect(find.textContaining('Phí xác minh'), findsNothing);
      expect(_inTile('phone', 'Số điện thoại'), findsOneWidget);
      expect(_inTile('phone', 'Nhận mã 6 số qua SMS'), findsOneWidget);
      expect(_inTile('phone', 'Đang làm'), findsOneWidget);
      expect(_inTile('identity', 'Xác minh danh tính'), findsOneWidget);
      expect(_inTile('identity', 'Chưa làm'), findsOneWidget);
      expect(_inTile('rules', 'Đồng ý quy định nhận việc'), findsOneWidget);
      expect(_inTile('rules', 'Chưa làm'), findsOneWidget);
      expect(
        find.text(
          'Làm từng bước, lưu lại tiến độ. Thoát giữa chừng thì lần sau làm '
          'tiếp từ bước đang dở.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Xong 3 bước thì bấm "Gửi duyệt". Staff duyệt trong 24 giờ; được '
          'duyệt là có tích xanh và nhận đơn ngay.',
        ),
        findsOneWidget,
      );
      expect(_primaryLabels(tester), ['Tiếp tục']);
    });

    testWidgets('a done phone shows Đã xác minh · •••• 3456 and Xong', (
      tester,
    ) async {
      final w = await _world(tester);
      w.seedDoc(_doc());
      await _open(tester, w);

      expect(_inTile('phone', 'Đã xác minh · •••• 3456'), findsOneWidget);
      expect(_inTile('phone', 'Xong'), findsOneWidget);
      expect(_inTile('identity', 'Đang làm'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('Tiếp tục opens the first undone step route', (tester) async {
      final w = await _world(tester);
      w.seedDoc(null, phoneVerified: false);
      await _open(tester, w);
      await _tap(tester, find.byKey(const Key('verify-next')));
      expect(w.router.state.uri.path, '/verify/phone');
      expect(w.router.state.uri.queryParameters['returnTo'], '/verify/start');

      await tester.pumpWidget(const SizedBox.shrink());
      final w2 = await _world(tester);
      w2.seedDoc(_doc());
      await _open(tester, w2);
      await _tap(tester, find.byKey(const Key('verify-next')));
      expect(w2.router.state.uri.path, '/verify/identity');

      await tester.pumpWidget(const SizedBox.shrink());
      final w3 = await _world(tester);
      w3.seedDoc(_doc(identity: true));
      await _open(tester, w3);
      expect(find.text('3 / 3'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('verify-next')));
      expect(w3.router.state.uri.path, '/verify/start/rules');
    });

    testWidgets('all required steps done shows Gửi duyệt and submits', (
      tester,
    ) async {
      final w = await _world(tester);
      w.seedDoc(_doc(identity: true, rules: true));
      await _open(tester, w);

      expect(_primaryLabels(tester), ['Gửi duyệt']);
      for (final step in ['phone', 'identity', 'rules']) {
        expect(_inTile(step, 'Xong'), findsOneWidget, reason: step);
      }
      expect(_inTile('identity', 'Đã khớp qua VNeID'), findsOneWidget);
      expect(_inTile('rules', 'Đã đồng ý'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('verify-submit')));

      expect(w.repo.calls.map((c) => c.name), ['submitVerification']);
      expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
    });

    testWidgets('a refused submit shows the error and stays', (tester) async {
      final w = await _world(tester);
      w.seedDoc(_doc(identity: true, rules: true));
      w.repo.failWith = 'not_eligible';
      await _open(tester, w);
      await _tap(tester, find.byKey(const Key('verify-submit')));

      expect(find.text('Chưa thực hiện được. Thử lại nhé.'), findsOneWidget);
      expect(_primaryLabels(tester), ['Gửi duyệt']);
    });

    testWidgets('states are text, not colour only (semantics labels)', (
      tester,
    ) async {
      final w = await _world(tester);
      w.seedDoc(_doc());
      await _open(tester, w);
      final handle = tester.ensureSemantics();
      String label(String step) => tester.getSemantics(_tile(step)).label;

      expect(label('phone'), contains('Số điện thoại'));
      expect(label('phone'), contains('Xong'));
      expect(label('identity'), contains('Đang làm'));
      expect(label('rules'), contains('Chưa làm'));
      handle.dispose();
    });

    testWidgets('fits 320dp at 1.3x text', (tester) async {
      final w = await _world(tester, width: 320, height: 640);
      w.seedDoc(_doc());
      await _open(tester, w, textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(_primaryLabels(tester), ['Tiếp tục']);
    });
  });

  group('S21.02 decisions', () {
    testWidgets('submitted shows the pending timeline with the masked name '
        'and no primary button', (tester) async {
      final w = await _world(tester);
      w.seedDoc(
        _doc(
          status: 'submitted',
          identity: true,
          rules: true,
          submittedAt: _sentAt,
        ),
      );
      await _open(tester, w);

      expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
      expect(
        find.text('Gửi lúc 9:12 hôm nay · có kết quả trước 9:12 ngày mai'),
        findsOneWidget,
      );
      expect(find.text('Đã xác minh danh tính'), findsOneWidget);
      expect(find.text('VNeID · NGUYỄN M** T**'), findsOneWidget);
      expect(find.text('Đã gửi duyệt'), findsOneWidget);
      expect(
        find.text('Hôm nay 9:12 · đã đồng ý quy định nhận việc'),
        findsOneWidget,
      );
      expect(find.text('Staff duyệt'), findsOneWidget);
      expect(find.text('Đã trả phí xác minh'), findsNothing);
      expect(
        find.text(
          'Trong lúc chờ, bạn vẫn sửa portfolio, tạo gói và trò chuyện với '
          'khách.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('verify-counter')), findsNothing);
      expect(_primaryLabels(tester), isEmpty);
      await _tap(tester, find.byKey(const Key('verify-view-profile')));
      expect(w.router.state.uri.path, '/u/${w.uid}');
    });

    testWidgets('rejected fake_avatar shows the reason, Còn 1 lần gửi lại '
        'miễn phí, the avatar fix row opening /settings/profile, and Sửa và '
        'gửi lại resubmits', (tester) async {
      final w = await _world(tester);
      w.seedDoc(
        _doc(
          status: 'rejected',
          identity: true,
          rules: true,
          submittedAt: _sentAt,
          decidedAt: DateTime.utc(2026, 10, 15, 2, 40),
          reject: 'fake_avatar',
        ),
      );
      await _open(tester, w);

      expect(find.text('Hồ sơ chưa được duyệt'), findsOneWidget);
      expect(
        find.text(
          'Lý do: Ảnh đại diện không phải ảnh người thật. Đổi sang ảnh chân '
          'dung rõ mặt của bạn rồi gửi lại.',
        ),
        findsOneWidget,
      );
      expect(find.text('Còn 1 lần gửi lại miễn phí'), findsOneWidget);
      expect(find.text('9:40 hôm nay'), findsOneWidget);
      final fix = find.byKey(const Key('verify-fix-avatar'));
      expect(
        find.descendant(of: fix, matching: find.text('Ảnh đại diện')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fix, matching: find.text('Cần sửa')),
        findsOneWidget,
      );
      expect(_inTile('identity', 'Xong'), findsOneWidget);
      expect(_inTile('rules', 'Xong'), findsOneWidget);
      expect(_tile('phone'), findsNothing, reason: 'a done phone is not drawn');
      expect(
        find.text(
          'Chỉ sửa mục bị từ chối; các bước đã xong được giữ nguyên. Gửi lại '
          'thì staff duyệt trong 24 giờ.',
        ),
        findsOneWidget,
      );
      expect(_primaryLabels(tester), ['Sửa và gửi lại']);

      await _tap(tester, fix);
      expect(w.router.state.uri.path, '/settings/profile');
      w.router.pop();
      await _settle(tester);

      await _tap(tester, find.byKey(const Key('verify-resubmit')));
      expect(w.repo.calls.map((c) => c.name), ['resubmitVerification']);
      expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
    });

    testWidgets('rejected stolen_portfolio opens the own profile', (
      tester,
    ) async {
      final w = await _world(tester);
      w.seedDoc(
        _doc(
          status: 'rejected',
          identity: true,
          rules: true,
          reject: 'stolen_portfolio',
        ),
      );
      await _open(tester, w);
      await _tap(tester, find.byKey(const Key('verify-fix-portfolio')));
      expect(w.router.state.uri.path, '/u/${w.uid}');
    });

    testWidgets('rejected identity_mismatch reopens the identity step', (
      tester,
    ) async {
      final w = await _world(tester);
      w.seedDoc(
        _doc(status: 'rejected', rules: true, reject: 'identity_mismatch'),
      );
      await _open(tester, w);

      expect(_inTile('identity', 'Cần sửa'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('verify-resubmit')));
      expect(w.repo.calls, isEmpty);
      expect(w.router.state.uri.path, '/verify/identity');
    });

    testWidgets('rejected with no free resubmit and the fee off resubmits '
        'straight to pending', (tester) async {
      final w = await _world(tester);
      w.seedDoc(
        _doc(
          status: 'rejected',
          identity: true,
          rules: true,
          reject: 'other',
          rejectText: 'Ảnh bìa mờ',
          freeResubmitsLeft: 0,
        ),
      );
      await _open(tester, w);

      expect(find.text('Lý do: Ảnh bìa mờ'), findsOneWidget);
      expect(find.textContaining('lần gửi lại miễn phí'), findsNothing);
      await _tap(tester, find.byKey(const Key('verify-resubmit')));
      expect(w.repo.calls.map((c) => c.name), ['resubmitVerification']);
      expect(w.repo.doc(w.uid)!['status'], 'submitted');
      expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
    });

    testWidgets('rejected duplicate_account shows the support line and no '
        'primary', (tester) async {
      final w = await _world(tester);
      w.seedDoc(
        _doc(
          status: 'rejected',
          identity: true,
          rules: true,
          reject: 'duplicate_account',
        ),
      );
      await _open(tester, w);

      expect(
        find.text(
          'Lý do: Danh tính này đã gắn với một tài khoản nhận đơn khác. Liên '
          'hệ hỗ trợ nếu đây là nhầm lẫn.',
        ),
        findsOneWidget,
      );
      expect(find.text('Hỗ trợ: hotro@photobooking.vn'), findsOneWidget);
      expect(_primaryLabels(tester), isEmpty);
      expect(find.byType(VerifyStepTile), findsNothing);
      await _tap(tester, find.byKey(const Key('verify-support')));
      expect(w.launcher.opened, [Uri.parse('mailto:hotro@photobooking.vn')]);
    });

    testWidgets('approved shows the heading and Xem hồ sơ', (tester) async {
      final w = await _world(tester);
      w.seedDoc(
        _doc(
          status: 'approved',
          identity: true,
          rules: true,
          decidedAt: DateTime.utc(2026, 10, 15, 3, 5),
        ),
      );
      await _open(tester, w);

      expect(find.text('Bạn đã có thể nhận đơn'), findsOneWidget);
      expect(
        find.text('Duyệt lúc 10:05 hôm nay. Tích xanh đã hiện cạnh tên bạn.'),
        findsOneWidget,
      );
      expect(_primaryLabels(tester), isEmpty);
      expect(find.byKey(const Key('verify-view-profile')), findsOneWidget);
    });

    testWidgets('revoked shows the warning and support line', (tester) async {
      final w = await _world(tester);
      w.seedDoc(_doc(status: 'revoked', identity: true, rules: true));
      await _open(tester, w);

      expect(find.text('Xác minh đã bị thu hồi'), findsOneWidget);
      expect(
        find.text('Bạn tạm thời không nhận đơn. Liên hệ hỗ trợ để biết thêm.'),
        findsOneWidget,
      );
      expect(find.text('Hỗ trợ: hotro@photobooking.vn'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('decision states fit 320dp at 1.3x text', (tester) async {
      for (final doc in [
        _doc(
          status: 'submitted',
          identity: true,
          rules: true,
          submittedAt: _sentAt,
        ),
        _doc(
          status: 'rejected',
          identity: true,
          rules: true,
          decidedAt: _sentAt,
          reject: 'fake_avatar',
        ),
        _doc(status: 'approved', decidedAt: _sentAt),
        _doc(status: 'revoked'),
      ]) {
        final w = await _world(tester, width: 320, height: 640);
        w.seedDoc(doc);
        await _open(tester, w, textScale: 1.3);
        expect(tester.takeException(), isNull, reason: '${doc['status']}');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('entry', () {
    test('verifyStartReadyProvider is true and /verify/start resolves', () {
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(verifyStartReadyProvider), isTrue);
      final router = c.read(routerProvider);
      final start = router.configuration.findMatch(Uri.parse('/verify/start'));
      expect(start.isError, isFalse);
      expect(start.matches.last.matchedLocation, '/verify/start');
      final rules = router.configuration.findMatch(
        Uri.parse('/verify/start/rules'),
      );
      expect(rules.isError, isFalse);
      expect(rules.matches.last.matchedLocation, '/verify/start/rules');
      expect(rules.matches.last.route, isA<GoRoute>());
    });
  });
}
