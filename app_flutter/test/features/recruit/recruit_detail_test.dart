import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_detail_screen.dart';

import '../../support/recruit_world.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}


Finder _code(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

final _routes = <RouteBase>[
  GoRoute(
    path: '/recruit/:postId',
    builder: (_, s) => RecruitDetailScreen(postId: s.pathParameters['postId']!),
  ),
];

Future<RecruitWorld> _open(
  WidgetTester tester, {
  ProviderFacts? facts,
  RecruitPost? post,
  RecruitApplication? application,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = RecruitWorld()..seedStudio();
  w.recruits.setFacts(w.uid, facts ?? makeProviderFacts());
  w.recruits.seedPost(
    post ??
        makeRecruitPost(
          applicationCount: 12,
          requirements: 'Có máy full-frame và ống 70-200.',
        ),
  );
  if (application != null) w.recruits.seedApplication(application);
  await tester.pumpWidget(w.app('/recruit/p1', routes: _routes));
  await _settle(tester);
  return w;
}

bool _enabled(WidgetTester tester, Finder button) {
  final b = find.descendant(
    of: button,
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(b.first).onPressed != null;
}

void main() {
  testWidgets('shows the tag, title, studio row, the four rows, requirements '
      'and the stats line', (tester) async {
    final w = await _open(tester);
    expect(_code(ScreenCodes.recruitDetail), findsOneWidget);
    expect(find.text('Cộng tác theo việc'), findsOneWidget);
    expect(find.text('Tuyển CTV chụp cưới cuối tuần'), findsOneWidget);
    expect(find.textContaining('Studio Cúc', findRichText: true), findsWidgets);
    expect(find.textContaining('96%', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('128 buổi chụp', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Cưới, Gia đình'), findsOneWidget);
    expect(find.text('Thể loại'), findsOneWidget);
    expect(find.text('Quận 1, Quận 3'), findsOneWidget);
    expect(find.text('Khu vực làm việc'), findsOneWidget);
    expect(find.text('Hằng tuần'), findsOneWidget);
    expect(find.text('Tần suất'), findsOneWidget);
    expect(find.text('800.000₫/buổi'), findsOneWidget);
    expect(
      find.text(
        'Thù lao tham khảo · studio trả trực tiếp cho bạn, ngoài ứng dụng',
      ),
      findsOneWidget,
    );
    expect(find.text('Yêu cầu'), findsOneWidget);
    expect(find.text('Có máy full-frame và ống 70-200.'), findsOneWidget);
    expect(find.text('12 người đã ứng tuyển · còn 29 ngày'), findsOneWidget);
    await tester.tap(find.text('Xem studio'));
    await _settle(tester);
    expect(w.location, '/u/cuc');
  });

  testWidgets('verified individual: "Ứng tuyển" opens the sheet', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Ứng tuyển'));
    await _settle(tester);
    expect(_code(ScreenCodes.recruitApply), findsOneWidget);
    expect(find.text('Gửi ứng tuyển'), findsOneWidget);
  });

  testWidgets('unverified: lock note and "Xác minh để ứng tuyển" goes to '
      '/verify/start', (tester) async {
    final w = await _open(
      tester,
      facts: makeProviderFacts(acceptingOrders: false),
    );
    expect(
      find.text('Bạn cần xác minh danh tính trước khi ứng tuyển.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Ứng tuyển'), findsNothing);
    await tester.tap(find.widgetWithText(AppButton, 'Xác minh để ứng tuyển'));
    await _settle(tester);
    expect(w.location, '/verify/start');
  });

  testWidgets('already applied: disabled outline "Đã ứng tuyển · chờ studio" '
      'and "Rút ứng tuyển" opens a confirm sheet with a red button', (
    tester,
  ) async {
    final w = await _open(tester, application: makeRecruitApplication());
    final applied = find.widgetWithText(AppButton, 'Đã ứng tuyển · chờ studio');
    expect(applied, findsOneWidget);
    expect(_enabled(tester, applied), isFalse);
    expect(find.byType(CtaSurface), findsNothing);
    await tester.tap(find.widgetWithText(AppButton, 'Rút ứng tuyển'));
    await _settle(tester);
    expect(find.text('Rút ứng tuyển?'), findsOneWidget);
    expect(
      find.text('Mỗi tin chỉ ứng tuyển một lần, rút rồi không gửi lại được.'),
      findsOneWidget,
    );
    final confirm = find.descendant(
      of: find.byKey(const Key('app-sheet')),
      matching: find.widgetWithText(FilledButton, 'Rút ứng tuyển'),
    );
    final bg = tester
        .widget<FilledButton>(confirm)
        .style!
        .backgroundColor!
        .resolve({});
    expect(bg, AppColorsDark.destructive);
    await tester.tap(confirm);
    await _settle(tester);
    expect(w.recruits.calls.map((c) => c.$1), ['withdrawRecruitApplication']);
    expect(w.recruits.calls.single.$2, {'postId': 'p1'});
  });

  testWidgets('accepted/declined show the result line', (tester) async {
    await _open(
      tester,
      application: makeRecruitApplication(status: ApplicationStatus.accepted),
    );
    expect(find.text('Studio đã nhận bạn'), findsOneWidget);
    expect(find.byType(CtaSurface), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _open(
      tester,
      application: makeRecruitApplication(status: ApplicationStatus.declined),
    );
    expect(find.text('Studio chưa nhận ứng tuyển này'), findsOneWidget);
    expect(find.byType(CtaSurface), findsNothing);
  });

  testWidgets('member of the posting studio: "Bạn đang là thành viên của …" '
      'and no button', (tester) async {
    await _open(tester, facts: makeProviderFacts(studioId: 'cuc'));
    expect(find.text('Bạn đang là thành viên của Studio Cúc.'), findsOneWidget);
    expect(find.byType(CtaSurface), findsNothing);
    expect(find.widgetWithText(AppButton, 'Ứng tuyển'), findsNothing);
  });

  testWidgets('studio viewer: "Studio xem được tin nhưng không ứng tuyển."', (
    tester,
  ) async {
    await _open(
      tester,
      facts: makeProviderFacts(providerType: ProviderType.studio),
    );
    expect(
      find.text('Studio xem được tin nhưng không ứng tuyển.'),
      findsOneWidget,
    );
    expect(find.byType(CtaSurface), findsNothing);
  });

  testWidgets('closed post: "Tin đã đóng hoặc hết hạn."', (tester) async {
    await _open(
      tester,
      post: makeRecruitPost(status: RecruitPostStatus.closed),
    );
    expect(find.text('Tin đã đóng hoặc hết hạn.'), findsOneWidget);
    expect(find.byType(CtaSurface), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _open(
      tester,
      post: makeRecruitPost(
        createdAt: recruitNow.subtract(const Duration(days: 31)),
      ),
    );
    expect(find.text('Tin đã đóng hoặc hết hạn.'), findsOneWidget);
  });

  testWidgets('a customer-mode account never reads the post (R3)', (
    tester,
  ) async {
    final w = await _open(tester, facts: makeProviderFacts(role: 'customer'));
    expect(find.text('Chỉ thợ ảnh và studio thấy mục này.'), findsOneWidget);
    expect(w.recruits.getCalls, isEmpty);
    expect(find.text('Tuyển CTV chụp cưới cuối tuần'), findsNothing);
  });

  testWidgets('there is no share action', (tester) async {
    await _open(tester);
    expect(find.byIcon(AppIcons.share), findsNothing);
    expect(find.byTooltip('Chia sẻ'), findsNothing);
  });

  testWidgets('exactly one AppButton.primary', (tester) async {
    await _open(tester);
    expect(find.byType(CtaSurface), findsOneWidget);
  });
}
