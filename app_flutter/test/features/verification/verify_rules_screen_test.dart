// test/features/verification/verify_rules_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/verification_world.dart';

final _at = DateTime.utc(2026, 10, 15, 2, 12);

Map<String, dynamic> _doc({bool identity = true}) => {
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
      },
  },
  'freeResubmitsLeft': 1,
};

Future<VerificationWorld> _open(
  WidgetTester tester, {
  Map<String, dynamic>? doc,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = VerificationWorld(startScreen: true);
  await w.init();
  w.seedDoc(doc ?? _doc());
  await tester.pumpWidget(
    w.app(location: '/verify/start/rules', textScale: textScale),
  );
  await _settle(tester);
  return w;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

AppButton _submit(WidgetTester tester) =>
    tester.widget<AppButton>(find.byKey(const Key('verify-rules-submit')));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

void main() {
  testWidgets('five rules in order', (tester) async {
    await _open(tester);

    expect(find.text('Quy định nhận việc'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Đọc 5 điều chính trước khi gửi duyệt.'), findsOneWidget);
    const rules = [
      'Khách trả 100% khi đặt; tiền được giữ và chuyển cho bạn theo 2 mốc: '
          'sau buổi chụp, và sau khi khách đồng ý ảnh + 48 giờ.',
      'Bàn giao hai lớp: gửi ảnh mẫu có watermark trước; link ảnh gốc chỉ mở '
          'khi khách đồng ý.',
      'Khách huỷ trước 48 giờ được hoàn 100%, 24–48 giờ hoàn 50%, dưới 24 '
          'giờ không hoàn; bạn huỷ thì khách được hoàn 100%.',
      'Thợ cá nhân: nền tảng khấu trừ và nộp thay thuế trên phần chi trả cho '
          'bạn.',
      'Họ tên, ngày sinh, số định danh được mã hoá; không lưu ảnh selfie; '
          'chỉ dùng để xác minh, chống trùng tài khoản và khấu trừ thuế.',
    ];
    var lastY = double.negativeInfinity;
    for (final (i, rule) in rules.indexed) {
      final f = find.byKey(Key('verify-rule-${i + 1}'));
      expect(f, findsOneWidget);
      expect(tester.widget<Text>(f).textSpan!.toPlainText(), '${i + 1}. $rule');
      final y = tester.getTopLeft(f).dy;
      expect(y, greaterThan(lastY));
      lastY = y;
    }
    expect(
      find.text('Tôi đã đọc và đồng ý quy định nhận việc'),
      findsOneWidget,
    );
  });

  testWidgets('Gửi duyệt is disabled until the box is checked', (tester) async {
    await _open(tester);

    expect(_submit(tester).label, 'Gửi duyệt');
    expect(_submit(tester).onPressed, isNull);
    await _tap(tester, find.byKey(const Key('verify-rules-agree')));
    expect(_submit(tester).onPressed, isNotNull);
    await _tap(tester, find.byKey(const Key('verify-rules-agree')));
    expect(_submit(tester).onPressed, isNull);
  });

  testWidgets('checking and sending accepts version 2026-10-06 then submits', (
    tester,
  ) async {
    final w = await _open(tester);
    await _tap(tester, find.byKey(const Key('verify-rules-agree')));
    await _tap(tester, find.byKey(const Key('verify-rules-submit')));

    expect(w.repo.calls.map((c) => c.name), [
      'acceptVerificationRules',
      'submitVerification',
    ]);
    expect(w.repo.calls.first.data, {'version': '2026-10-06'});
    expect(w.router.state.uri.path, '/verify/start');
    expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
  });

  testWidgets('back from the rules keeps the S21.02 back stack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = VerificationWorld(startScreen: true);
    await w.init();
    w.seedDoc(_doc());
    await tester.pumpWidget(w.app(location: '/profile'));
    await _settle(tester);
    w.router.push('/verify/start');
    await _settle(tester);
    await _tap(tester, find.byKey(const Key('verify-next')));
    expect(w.router.state.uri.path, '/verify/start/rules');

    await _tap(tester, find.byKey(const Key('verify-rules-agree')));
    await _tap(tester, find.byKey(const Key('verify-rules-submit')));
    expect(w.router.state.uri.path, '/verify/start');
    expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
    expect(w.router.canPop(), isTrue);
    w.router.pop();
    await _settle(tester);
    expect(w.router.state.uri.path, '/profile');
  });

  testWidgets('with a step still undone it only accepts and goes back', (
    tester,
  ) async {
    final w = await _open(tester, doc: _doc(identity: false));
    await _tap(tester, find.byKey(const Key('verify-rules-agree')));
    await _tap(tester, find.byKey(const Key('verify-rules-submit')));

    expect(w.repo.calls.map((c) => c.name), ['acceptVerificationRules']);
    expect(w.router.state.uri.path, '/verify/start');
    expect(find.text('Đã đồng ý'), findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _open(tester, width: 320, height: 640, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('verify-rules-submit')), findsOneWidget);
  });
}
