import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/studio_recruit_screen.dart';

import '../../support/content_fixtures.dart';
import '../../support/recruit_world.dart';

/// S27.05 has bounded loaders only: a second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _key(String k) => find.byKey(Key(k));

Finder _code(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

Finder _inKey(String k, Finder f) => find.descendant(of: _key(k), matching: f);

bool _enabled(WidgetTester tester, Finder button) {
  final b = find.descendant(
    of: button,
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(b.first).onPressed != null;
}

final _routes = <RouteBase>[
  GoRoute(
    path: '/studio/recruit',
    builder: (_, s) =>
        StudioRecruitScreen(postId: s.uri.queryParameters['post']),
  ),
];

const _stubs = [
  '/verify/start',
  '/recruit',
  '/studio/recruit/new',
  '/studio/recruit/:postId/edit',
  '/u/:uid',
];

/// Studio Cúc's two open posts: the collaborator one (12 applicants, 26
/// days left) and the member one (3 applicants, 9 days left), plus a closed
/// one.
List<RecruitPost> _posts() => [
  makeRecruitPost(
    id: 'p1',
    title: 'Thợ phụ chụp cưới mùa cưới',
    applicationCount: 12,
    createdAt: recruitNow.subtract(const Duration(days: 4)),
  ),
  makeRecruitPost(
    id: 'p2',
    kind: RecruitKind.member,
    title: 'Tuyển thành viên chụp kỷ yếu',
    applicationCount: 3,
    createdAt: recruitNow.subtract(const Duration(days: 21)),
  ),
  makeRecruitPost(
    id: 'p3',
    title: 'Tin cũ đã đóng',
    status: RecruitPostStatus.closed,
    applicationCount: 5,
    createdAt: recruitNow.subtract(const Duration(days: 25)),
  ),
];

Future<RecruitWorld> _open(
  WidgetTester tester, {
  ProviderFacts? facts,
  RecruitCounters? counters,
  List<RecruitPost>? posts,
  List<RecruitApplication> applications = const [],
  String location = '/studio/recruit',
  Size size = const Size(390, 1200),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = RecruitWorld(uid: 'cuc');
  w.recruits.setFacts(
    w.uid,
    facts ?? makeProviderFacts(providerType: ProviderType.studio),
  );
  w.recruits.setCounters(
    w.uid,
    counters ??
        const RecruitCounters(
          openPostCount: 2,
          postActions: RecruitDaily(day: '2026-10-21', count: 2),
        ),
  );
  for (final p in posts ?? _posts()) {
    w.recruits.seedPost(p);
  }
  for (final a in applications) {
    w.recruits.seedApplication(a);
  }
  w.seedApplicant(id: 'vy', name: 'Thảo Vy');
  w.seedApplicant(id: 'phuc', name: 'Đình Phúc', tomatoPct: 89);
  w.posts
    ..add(fixturePost('vy1', photographerId: 'vy'))
    ..add(fixturePost('vy2', photographerId: 'vy'))
    ..add(fixturePost('vy3', photographerId: 'vy'));
  await tester.pumpWidget(
    w.app(location, routes: _routes, stubs: _stubs, textScale: textScale),
  );
  await _settle(tester);
  return w;
}

RecruitApplication _vy({String postId = 'p1', RecruitKind? kind}) =>
    makeRecruitApplication(
      postId: postId,
      applicantId: 'vy',
      applicantName: 'Thảo Vy',
      kind: kind ?? RecruitKind.collaborator,
      message: 'Em đã chụp phụ 15 đám cưới, có 70-200 f2.8 và đèn rời.',
      samplePostIds: const ['vy1', 'vy2', 'vy3'],
    );

RecruitApplication _phuc({String postId = 'p1', RecruitKind? kind}) =>
    makeRecruitApplication(
      postId: postId,
      applicantId: 'phuc',
      applicantName: 'Đình Phúc',
      kind: kind ?? RecruitKind.collaborator,
      message: 'Em rảnh cuối tuần.',
      createdAt: recruitNow.subtract(const Duration(hours: 3)),
    );

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await _settle(tester);
}

void main() {
  testWidgets('lists posts with status badges and "{n} ứng viên · còn {d} '
      'ngày"', (tester) async {
    await _open(tester);
    expect(_code(ScreenCodes.studioRecruit), findsOneWidget);
    expect(find.text('Tin tuyển của studio'), findsOneWidget);
    expect(
      find.text('2/3 tin mở · còn 3 lượt đăng/đóng hôm nay'),
      findsOneWidget,
    );
    expect(_inKey('recruit-post-p1', find.text('ĐANG MỞ')), findsOneWidget);
    expect(_inKey('recruit-post-p2', find.text('ĐANG MỞ')), findsOneWidget);
    expect(_inKey('recruit-post-p3', find.text('ĐÃ ĐÓNG')), findsOneWidget);
    expect(
      _inKey('recruit-post-p1', find.text('Cộng tác theo việc')),
      findsOneWidget,
    );
    expect(_inKey('recruit-post-p2', find.text('Vào studio')), findsOneWidget);
    expect(
      _inKey('recruit-post-p1', find.text('12 ứng viên · còn 26 ngày')),
      findsOneWidget,
    );
    expect(
      _inKey('recruit-post-p2', find.text('3 ứng viên · còn 9 ngày')),
      findsOneWidget,
    );
    expect(_inKey('recruit-post-p3', find.text('5 ứng viên')), findsOneWidget);
    // Text actions only on open posts.
    expect(_inKey('recruit-post-p1', find.text('Sửa')), findsOneWidget);
    expect(_inKey('recruit-post-p3', find.text('Sửa')), findsNothing);
    expect(_inKey('recruit-post-p3', find.text('Đóng tin')), findsNothing);
  });

  testWidgets('a post past its expiry reads "Hết hạn" without actions', (
    tester,
  ) async {
    await _open(
      tester,
      posts: [
        makeRecruitPost(
          id: 'p1',
          expiresAt: recruitNow.subtract(const Duration(minutes: 5)),
        ),
      ],
    );
    expect(_inKey('recruit-post-p1', find.text('HẾT HẠN')), findsOneWidget);
    expect(_inKey('recruit-post-p1', find.text('Sửa')), findsNothing);
  });

  testWidgets('selecting a post lists its applicants', (tester) async {
    await _open(
      tester,
      applications: [
        _vy(),
        _phuc(),
        _vy(postId: 'p2', kind: RecruitKind.member),
      ],
    );
    // The first open post is selected.
    expect(find.text('Ứng viên · Thợ phụ chụp cưới mùa cưới'), findsOneWidget);
    expect(find.text('2 chờ trả lời'), findsOneWidget);
    expect(_key('recruit-applicant-vy'), findsOneWidget);
    expect(_key('recruit-applicant-phuc'), findsOneWidget);
    expect(
      _inKey(
        'recruit-applicant-vy',
        find.textContaining('95%', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      _inKey(
        'recruit-applicant-vy',
        find.textContaining('42 buổi chụp', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      _inKey(
        'recruit-applicant-vy',
        find.textContaining('Em đã chụp phụ 15 đám cưới'),
      ),
      findsOneWidget,
    );
    expect(
      _inKey('recruit-applicant-vy', find.byType(NetworkPhoto)),
      findsNWidgets(3),
    );
    await _tap(
      tester,
      _inKey('recruit-post-p2', find.text('Tuyển thành viên chụp kỷ yếu')),
    );
    expect(
      find.text('Ứng viên · Tuyển thành viên chụp kỷ yếu'),
      findsOneWidget,
    );
    expect(find.text('1 chờ trả lời'), findsOneWidget);
    expect(_key('recruit-applicant-phuc'), findsNothing);
  });

  testWidgets('a post without applicants says so', (tester) async {
    await _open(tester);
    expect(find.text('Chưa có ai ứng tuyển.'), findsOneWidget);
  });

  testWidgets('"Nhận" on a collaborator post calls respond(accept: true) and '
      'removes the card', (tester) async {
    final w = await _open(tester, applications: [_vy(), _phuc()]);
    await _tap(tester, _key('recruit-accept-vy'));
    expect(w.recruits.calls.single.$1, 'respondRecruitApplication');
    expect(w.recruits.calls.single.$2, {
      'postId': 'p1',
      'applicantId': 'vy',
      'accept': true,
    });
    expect(_key('recruit-applicant-vy'), findsNothing);
    expect(_key('recruit-applicant-phuc'), findsOneWidget);
    expect(find.text('1 chờ trả lời'), findsOneWidget);
  });

  for (final (code, text) in [
    (
      RecruitErrorCode.membershipConflict,
      'Thảo Vy đang ở studio khác hoặc đang cộng tác với studio bạn.',
    ),
    (
      RecruitErrorCode.cooldown,
      'Thảo Vy mới rời studio, chưa vào được studio mới.',
    ),
    (RecruitErrorCode.studioFull, 'Studio đã đủ thành viên.'),
    (RecruitErrorCode.collabFull, 'Đã đủ số cộng tác viên.'),
    (RecruitErrorCode.notAcceptingOrders, 'Thảo Vy hiện chưa nhận đơn được.'),
  ]) {
    testWidgets('"Nhận" on a member post that fails with ${code.name} shows '
        '"$text"', (tester) async {
      final w = await _open(
        tester,
        location: '/studio/recruit?post=p2',
        applications: [_vy(postId: 'p2', kind: RecruitKind.member)],
      );
      w.recruits.failWith = RecruitError(code);
      await _tap(tester, _key('recruit-accept-vy'));
      expect(find.text(text), findsOneWidget);
      expect(_key('recruit-applicant-vy'), findsOneWidget);
    });
  }

  testWidgets('"Từ chối" calls respond(accept: false) after a confirm sheet '
      'with a red button', (tester) async {
    final w = await _open(tester, applications: [_vy()]);
    await _tap(tester, _key('recruit-decline-vy'));
    expect(w.recruits.calls, isEmpty);
    final confirm = find.widgetWithText(FilledButton, 'Từ chối');
    expect(confirm, findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(confirm)
          .style
          ?.backgroundColor
          ?.resolve(const {}),
      AppColors.error,
    );
    await tester.tap(confirm);
    await _settle(tester);
    expect(w.recruits.calls.single.$1, 'respondRecruitApplication');
    expect(w.recruits.calls.single.$2, {
      'postId': 'p1',
      'applicantId': 'vy',
      'accept': false,
    });
    expect(_key('recruit-applicant-vy'), findsNothing);
  });

  testWidgets('"Đóng tin" opens the confirm sheet with "Đóng tin này?" and a '
      'red "Đóng tin"', (tester) async {
    final w = await _open(tester);
    await _tap(tester, _inKey('recruit-post-p1', find.text('Đóng tin')));
    expect(find.text('Đóng tin này?'), findsOneWidget);
    expect(
      find.text('Ứng viên đang chờ được báo là chưa được nhận.'),
      findsOneWidget,
    );
    final confirm = find.widgetWithText(FilledButton, 'Đóng tin');
    expect(
      tester
          .widget<FilledButton>(confirm)
          .style
          ?.backgroundColor
          ?.resolve(const {}),
      AppColors.error,
    );
    await tester.tap(confirm);
    await _settle(tester);
    expect(w.recruits.calls.single.$1, 'closeRecruitPost');
    expect(w.recruits.calls.single.$2, {'postId': 'p1'});
    expect(_inKey('recruit-post-p1', find.text('ĐÃ ĐÓNG')), findsOneWidget);
  });

  testWidgets('"Gia hạn 30 ngày" renews once and is hidden once renewed', (
    tester,
  ) async {
    final w = await _open(tester);
    expect(
      _inKey('recruit-post-p1', find.text('Gia hạn 30 ngày')),
      findsOneWidget,
    );
    await _tap(tester, _inKey('recruit-post-p1', find.text('Gia hạn 30 ngày')));
    expect(w.recruits.calls.single.$1, 'renewRecruitPost');
    expect(w.recruits.calls.single.$2, {'postId': 'p1'});
    expect(
      _inKey('recruit-post-p1', find.text('Gia hạn 30 ngày')),
      findsNothing,
    );
    expect(
      _inKey('recruit-post-p1', find.text('12 ứng viên · còn 56 ngày')),
      findsOneWidget,
    );
  });

  testWidgets('"Sửa" opens the edit form', (tester) async {
    final w = await _open(tester);
    await _tap(tester, _inKey('recruit-post-p1', find.text('Sửa')));
    expect(w.location, '/studio/recruit/p1/edit');
  });

  testWidgets('"Đăng tin mới" opens the form', (tester) async {
    final w = await _open(tester);
    expect(find.text('Đăng tin mới'), findsOneWidget);
    await _tap(tester, _key('recruit-new-post'));
    expect(w.location, '/studio/recruit/new');
  });

  testWidgets('three open posts: primary disabled "Đã đủ 3 tin mở"', (
    tester,
  ) async {
    await _open(tester, counters: const RecruitCounters(openPostCount: 3));
    expect(find.text('Đã đủ 3 tin mở'), findsOneWidget);
    expect(_enabled(tester, _key('recruit-new-post')), isFalse);
  });

  testWidgets('no post actions left today: primary disabled', (tester) async {
    await _open(
      tester,
      counters: const RecruitCounters(
        openPostCount: 1,
        postActions: RecruitDaily(day: '2026-10-21', count: 5),
      ),
    );
    expect(
      find.text('1/3 tin mở · còn 0 lượt đăng/đóng hôm nay'),
      findsOneWidget,
    );
    expect(_enabled(tester, _key('recruit-new-post')), isFalse);
  });

  testWidgets('unverified studio: primary "Xác minh để đăng tin" → '
      '/verify/start', (tester) async {
    final w = await _open(
      tester,
      facts: makeProviderFacts(
        providerType: ProviderType.studio,
        acceptingOrders: false,
      ),
    );
    expect(find.text('Đăng tin mới'), findsNothing);
    await _tap(tester, find.text('Xác minh để đăng tin'));
    expect(w.location, '/verify/start');
  });

  testWidgets('blocked studio shows the warning and no enabled primary', (
    tester,
  ) async {
    await _open(
      tester,
      counters: RecruitCounters(
        openPostCount: 1,
        // 12/11 in Vietnam.
        recruitBlockedUntil: DateTime.utc(2026, 11, 12, 3),
      ),
    );
    expect(
      find.text(
        'Bạn tạm không đăng tin và mời cộng tác viên tới 12/11 vì chưa trả '
        'thù lao cho cộng tác viên.',
      ),
      findsOneWidget,
    );
    expect(_enabled(tester, _key('recruit-new-post')), isFalse);
  });

  testWidgets('query post=… preselects that post', (tester) async {
    await _open(
      tester,
      location: '/studio/recruit?post=p2',
      applications: [
        _vy(postId: 'p2', kind: RecruitKind.member),
        _phuc(),
      ],
    );
    expect(
      find.text('Ứng viên · Tuyển thành viên chụp kỷ yếu'),
      findsOneWidget,
    );
    expect(_key('recruit-applicant-vy'), findsOneWidget);
    expect(_key('recruit-applicant-phuc'), findsNothing);
  });

  testWidgets('no posts yet: the empty line', (tester) async {
    await _open(tester, posts: const [], counters: const RecruitCounters());
    expect(
      find.text('Chưa có tin tuyển. Đăng tin để thợ ảnh khu vực của bạn thấy.'),
      findsOneWidget,
    );
    expect(_enabled(tester, _key('recruit-new-post')), isTrue);
  });

  testWidgets('an individual is sent to /recruit', (tester) async {
    final w = await _open(tester, facts: makeProviderFacts());
    expect(w.location, '/recruit');
    expect(w.recruits.calls, isEmpty);
    // Nothing of the studio side was read.
    expect(w.recruits.reads, isEmpty);
  });

  testWidgets('closing the selected post clears its applicants', (
    tester,
  ) async {
    final w = await _open(tester, applications: [_vy(), _phuc()]);
    expect(_key('recruit-applicant-vy'), findsOneWidget);
    await _tap(tester, _inKey('recruit-post-p1', find.text('Đóng tin')));
    await tester.tap(find.widgetWithText(FilledButton, 'Đóng tin'));
    await _settle(tester);
    expect(w.recruits.calls.single.$1, 'closeRecruitPost');
    // The closed post stays selected and says why nobody is listed.
    expect(find.text('Ứng viên · Thợ phụ chụp cưới mùa cưới'), findsOneWidget);
    expect(_key('recruit-applicants-closed'), findsOneWidget);
    expect(_key('recruit-applicant-vy'), findsNothing);
    expect(_key('recruit-accept-vy'), findsNothing);
    expect(find.textContaining('chờ trả lời'), findsNothing);
  });

  testWidgets('a post past its expiry lists no applicants and reads none', (
    tester,
  ) async {
    final w = await _open(
      tester,
      location: '/studio/recruit?post=p1',
      posts: [
        makeRecruitPost(
          id: 'p1',
          title: 'Thợ phụ chụp cưới mùa cưới',
          expiresAt: recruitNow.subtract(const Duration(minutes: 5)),
        ),
      ],
      applications: [_vy()],
    );
    expect(_key('recruit-applicants-closed'), findsOneWidget);
    expect(find.text('Tin đã đóng hoặc hết hạn.'), findsOneWidget);
    expect(_key('recruit-accept-vy'), findsNothing);
    expect(_key('recruit-decline-vy'), findsNothing);
    expect(w.recruits.reads, isNot(contains('applicantsOf:p1')));
  });

  testWidgets('a notification to ?post=p2 while S27.05 is open selects p2', (
    tester,
  ) async {
    final w = await _open(
      tester,
      applications: [
        _vy(postId: 'p2', kind: RecruitKind.member),
        _phuc(),
      ],
    );
    expect(find.text('Ứng viên · Thợ phụ chụp cưới mùa cưới'), findsOneWidget);
    w.router.go('/studio/recruit?post=p2');
    await _settle(tester);
    expect(
      find.text('Ứng viên · Tuyển thành viên chụp kỷ yếu'),
      findsOneWidget,
    );
    expect(_key('recruit-applicant-vy'), findsOneWidget);
    expect(_key('recruit-applicant-phuc'), findsNothing);
  });

  testWidgets('a refused decline keeps the card and says why', (tester) async {
    final w = await _open(tester, applications: [_vy()]);
    w.recruits.failWith = const RecruitError(RecruitErrorCode.rateLimited);
    await _tap(tester, _key('recruit-decline-vy'));
    await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
    await _settle(tester);
    expect(
      find.text('Bạn đã dùng hết lượt hôm nay. Thử lại ngày mai.'),
      findsOneWidget,
    );
    expect(_key('recruit-applicant-vy'), findsOneWidget);
  });

  testWidgets('exactly one AppButton.primary', (tester) async {
    await _open(tester, applications: [_vy()]);
    expect(find.byType(CtaSurface), findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x', (tester) async {
    await _open(
      tester,
      size: const Size(320, 640),
      textScale: 1.3,
      applications: [_vy(), _phuc()],
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      _key('recruit-applicant-phuc'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
