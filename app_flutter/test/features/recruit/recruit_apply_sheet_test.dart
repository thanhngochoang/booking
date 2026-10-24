import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_apply_sheet.dart';

import '../../support/content_fixtures.dart';
import '../../support/recruit_world.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _key(String k) => find.byKey(Key(k));

Finder _code(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

bool _enabled(WidgetTester tester, Finder button) {
  final b = find.descendant(
    of: button,
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(b.first).onPressed != null;
}

Finder get _send => _key('recruit-send');

/// A page with one button opening S27.03 for [post].
Future<RecruitWorld> _open(
  WidgetTester tester, {
  RecruitPost? post,
  int samples = 5,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = RecruitWorld();
  final p = post ?? makeRecruitPost();
  w.recruits.seedPost(p);
  for (var i = 0; i < samples; i++) {
    w.posts.add(
      fixturePost(
        's$i',
        photographerId: w.uid,
        age: Duration(hours: i + 1),
      ),
    );
  }
  await tester.pumpWidget(
    w.app(
      '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showRecruitApplySheet(context, p),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await _settle(tester);
  return w;
}

Future<void> _agree(WidgetTester tester) async {
  final agree = find.text('Tôi đồng ý điều khoản cộng tác');
  await tester.ensureVisible(agree);
  await tester.tap(agree);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_send);
  await tester.tap(_send);
  await _settle(tester);
}

void main() {
  testWidgets('collaborator post shows the three terms and the checkbox; '
      '"Gửi ứng tuyển" is disabled until agreed', (tester) async {
    await _open(tester);
    expect(_code(ScreenCodes.recruitApply), findsOneWidget);
    expect(find.text('Ứng tuyển'), findsOneWidget);
    expect(
      find.text('Tuyển CTV chụp cưới cuối tuần · Studio Cúc'),
      findsOneWidget,
    );
    expect(find.text('Điều khoản cộng tác'), findsOneWidget);
    expect(
      find.textContaining('Hợp đồng dịch vụ theo từng buổi chụp'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Studio trả trực tiếp cho bạn ngoài ứng dụng'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Bạn không chào trực tiếp khách'),
      findsOneWidget,
    );
    expect(
      find.text('Không ghi số điện thoại, Zalo hay link trong lời nhắn.'),
      findsOneWidget,
    );
    expect(_enabled(tester, _send), isFalse);
    await _agree(tester);
    expect(_enabled(tester, _send), isTrue);
    expect(find.byType(CtaSurface), findsOneWidget);
  });

  testWidgets('member post shows the member note instead of terms', (
    tester,
  ) async {
    await _open(tester, post: makeRecruitPost(kind: RecruitKind.member));
    expect(find.text('Điều khoản cộng tác'), findsNothing);
    expect(find.text('Tôi đồng ý điều khoản cộng tác'), findsNothing);
    expect(
      find.text(
        'Được nhận thì bạn vào Studio Cúc như thành viên (mỗi thợ ở một studio).',
      ),
      findsOneWidget,
    );
    expect(_enabled(tester, _send), isTrue);
  });

  testWidgets('picking a fourth sample is refused, counter shows 3/3', (
    tester,
  ) async {
    final w = await _open(tester);
    expect(find.text('0/3'), findsOneWidget);
    for (final id in ['s0', 's1', 's2', 's3']) {
      final tile = _key('post-pick-$id');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pump();
    }
    expect(find.text('3/3'), findsOneWidget);
    await _agree(tester);
    await _submit(tester);
    expect(w.recruits.calls.single.$2['samplePostIds'], ['s0', 's1', 's2']);
  });

  testWidgets('message counter stops at 400', (tester) async {
    final w = await _open(tester);
    await tester.enterText(_key('recruit-message'), 'a' * 410);
    await tester.pump();
    expect(find.text('400/400'), findsOneWidget);
    await _agree(tester);
    await _submit(tester);
    expect((w.recruits.calls.single.$2['message']! as String).length, 400);
  });

  testWidgets('server invalid_argument with field message.contact shows "Bỏ '
      'số điện thoại, Zalo hoặc link ra khỏi nội dung" under the message', (
    tester,
  ) async {
    final w = await _open(tester);
    w.recruits.failWith = const RecruitError(
      RecruitErrorCode.invalidArgument,
      field: 'message.contact',
    );
    await tester.enterText(_key('recruit-message'), 'Gọi em 0903123456');
    await _agree(tester);
    await _submit(tester);
    final error = find.text(
      'Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung',
    );
    expect(error, findsOneWidget);
    expect(
      find.descendant(of: _key('recruit-message'), matching: error),
      findsOneWidget,
    );
    expect(_code(ScreenCodes.recruitApply), findsOneWidget);
  });

  testWidgets('limit_exceeded shows recruitErrorApplyLimit', (tester) async {
    final w = await _open(tester);
    w.recruits.failWith = const RecruitError(RecruitErrorCode.limitExceeded);
    await _agree(tester);
    await _submit(tester);
    expect(
      find.text(
        'Bạn đang có 10 ứng tuyển chờ trả lời. Chờ studio trả lời hoặc rút bớt.',
      ),
      findsOneWidget,
    );
    expect(_code(ScreenCodes.recruitApply), findsOneWidget);
  });

  testWidgets('rate_limited shows recruitErrorRateLimited', (tester) async {
    final w = await _open(tester);
    w.recruits.failWith = const RecruitError(RecruitErrorCode.rateLimited);
    await _agree(tester);
    await _submit(tester);
    expect(
      find.text('Bạn đã dùng hết lượt hôm nay. Thử lại ngày mai.'),
      findsOneWidget,
    );
  });

  testWidgets('success closes the sheet and shows "Đã gửi ứng tuyển"', (
    tester,
  ) async {
    final w = await _open(tester);
    await tester.enterText(_key('recruit-message'), 'Em chụp cưới 2 năm.');
    await _agree(tester);
    await _submit(tester);
    expect(_code(ScreenCodes.recruitApply), findsNothing);
    expect(find.text('Đã gửi ứng tuyển'), findsOneWidget);
    final (name, payload) = w.recruits.calls.single;
    expect(name, 'applyToRecruitPost');
    expect(payload, {
      'postId': 'p1',
      'message': 'Em chụp cưới 2 năm.',
      'samplePostIds': <String>[],
      'acceptTerms': true,
    });
  });
}
