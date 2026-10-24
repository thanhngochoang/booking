import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_edit_controller.dart';
import 'package:photobooking/features/recruit/recruit_edit_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/recruit_world.dart';

/// S27.04 has bounded loaders only: a second of frames.
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
    builder: (_, _) => const Scaffold(body: Text('S27.05 stub')),
  ),
  GoRoute(
    path: '/studio/recruit/new',
    builder: (_, _) => const RecruitEditScreen(),
  ),
  GoRoute(
    path: '/studio/recruit/:postId/edit',
    builder: (_, s) => RecruitEditScreen(postId: s.pathParameters['postId']),
  ),
];

/// Opens S27.05's stub, then pushes [location] on top (as "Đăng tin mới" and
/// "Sửa" do).
Future<RecruitWorld> _open(
  WidgetTester tester, {
  String location = '/studio/recruit/new',
  RecruitCounters? counters,
  ProviderFacts? facts,
  RecruitPost? post,
  Size size = const Size(390, 2000),
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
    counters ?? const RecruitCounters(openPostCount: 1),
  );
  if (post != null) w.recruits.seedPost(post);
  await tester.pumpWidget(
    w.app(
      '/studio/recruit',
      routes: _routes,
      stubs: const ['/verify/start', '/recruit'],
      textScale: textScale,
    ),
  );
  await tester.pump();
  w.router.push(location);
  await _settle(tester);
  return w;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_key(key));
  await tester.enterText(_key(key), text);
  await tester.pump();
}

Finder _chip(String label) => find.widgetWithText(AppChip, label);

Future<void> _submit(WidgetTester tester) =>
    _tap(tester, _key('recruit-submit'));

/// Fills the mock's example: "Thợ phụ chụp cưới mùa cưới", Cưới + Gia đình,
/// Quận 3 + Quận 7, Theo mùa, 800.000₫ per shoot.
Future<void> _fill(WidgetTester tester) async {
  await _type(tester, 'recruit-title', 'Thợ phụ chụp cưới mùa cưới');
  await _tap(tester, _chip('Cưới'));
  await _tap(tester, _chip('Gia đình'));
  await _tap(tester, _chip('Quận 3'));
  await _tap(tester, _chip('Quận 7'));
  await _tap(tester, find.text('Theo mùa (cưới, Tết…)'));
  await _type(tester, 'recruit-fee-amount', '800000');
}

void main() {
  testWidgets('create shows "Đăng tin tuyển", "Còn 2/3 tin mở" and both '
      'kinds', (tester) async {
    await _open(tester);
    expect(_code(ScreenCodes.recruitEdit), findsOneWidget);
    expect(find.text('Đăng tin tuyển'), findsOneWidget);
    expect(find.text('Còn 2/3 tin mở'), findsOneWidget);
    expect(find.text('Cộng tác theo việc'), findsOneWidget);
    expect(find.text('Thợ làm từng buổi, không vào studio'), findsOneWidget);
    expect(find.text('Thành viên studio'), findsOneWidget);
    expect(find.text('Thợ vào studio của bạn'), findsOneWidget);
    // Mock captions are uppercase (CSS `text-transform`).
    expect(find.text('Thể loại (tối đa 4)'.toUpperCase()), findsOneWidget);
    expect(find.text('Khu vực (tối đa 5)'.toUpperCase()), findsOneWidget);
    expect(
      find.text(
        'Không ghi số điện thoại, Zalo hay link. Tin hiện 30 ngày, chỉ thợ ảnh '
        'và studio thấy.',
      ),
      findsOneWidget,
    );
    expect(find.text('Đăng tin'), findsOneWidget);
    expect(find.text('0/80'), findsOneWidget);
    expect(find.text('0/600'), findsOneWidget);
  });

  testWidgets('edit shows "Sửa tin tuyển", "Lưu thay đổi" and the kind '
      'locked', (tester) async {
    final w = await _open(
      tester,
      location: '/studio/recruit/p1/edit',
      post: makeRecruitPost(
        studioId: 'cuc',
        requirements: 'Có máy full-frame.',
      ),
    );
    expect(find.text('Sửa tin tuyển'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.text('Còn 2/3 tin mở'), findsNothing);
    expect(find.text('Tuyển CTV chụp cưới cuối tuần'), findsOneWidget);
    expect(find.text('Có máy full-frame.'), findsOneWidget);
    final member = find.widgetWithText(AppOptionTile, 'Thành viên studio');
    expect(tester.widget<AppOptionTile>(member).enabled, isFalse);
    await _tap(tester, member);
    expect(
      tester
          .widget<AppOptionTile>(
            find.widgetWithText(AppOptionTile, 'Cộng tác theo việc'),
          )
          .selected,
      isTrue,
    );
    await _submit(tester);
    expect(w.recruits.calls.single.$1, 'updateRecruitPost');
    expect(w.recruits.calls.single.$2.containsKey('kind'), isFalse);
    expect(w.recruits.drafts.single.kind, RecruitKind.collaborator);
    expect(w.location, '/studio/recruit');
    expect(find.text('Đã lưu thay đổi'), findsOneWidget);
  });

  testWidgets('a closed post cannot be edited', (tester) async {
    await _open(
      tester,
      location: '/studio/recruit/p1/edit',
      post: makeRecruitPost(studioId: 'cuc', status: RecruitPostStatus.closed),
    );
    expect(find.text('Tin đã đóng hoặc hết hạn.'), findsOneWidget);
    expect(_key('recruit-submit'), findsNothing);
  });

  testWidgets('field errors appear under each field on submit', (tester) async {
    final w = await _open(tester);
    await _type(tester, 'recruit-title', 'Ngắn123');
    for (final area in ['Quận 1', 'Quận 3', 'Quận 7', 'Bình Thạnh', 'Huế']) {
      await _tap(tester, _chip(area));
    }
    // A sixth area cannot be picked.
    expect(tester.widget<AppChip>(_chip('Đà Lạt')).enabled, isFalse);
    expect(tester.widget<AppChip>(_chip('Huế')).enabled, isTrue);
    await _tap(tester, _chip('Đà Lạt'));
    expect(tester.widget<AppChip>(_chip('Đà Lạt')).selected, isFalse);
    await _submit(tester);
    expect(w.recruits.calls, isEmpty);
    expect(
      _inKey('recruit-title', find.text('Tiêu đề 8–80 ký tự')),
      findsOneWidget,
    );
    expect(
      _inKey('recruit-specialties', find.text('Chọn 1–4 thể loại')),
      findsOneWidget,
    );
    expect(find.text('Chọn 1–5 khu vực'), findsNothing);
    expect(
      _inKey('recruit-fee-amount', find.text('Nhập số tiền mỗi buổi')),
      findsOneWidget,
    );
    // Fixing the title clears its line.
    await _type(tester, 'recruit-title', 'Thợ phụ chụp cưới');
    expect(find.text('Tiêu đề 8–80 ký tự'), findsNothing);
  });

  testWidgets('no area shows its line; a fifth specialty is disabled', (
    tester,
  ) async {
    final w = await _open(tester);
    for (final s in ['Chân dung', 'Cưới', 'Cặp đôi', 'Gia đình']) {
      await _tap(tester, _chip(s));
    }
    expect(tester.widget<AppChip>(_chip('Sự kiện')).enabled, isFalse);
    await _submit(tester);
    expect(w.recruits.calls, isEmpty);
    expect(
      _inKey('recruit-areas', find.text('Chọn 1–5 khu vực')),
      findsOneWidget,
    );
    expect(find.text('Chọn 1–4 thể loại'), findsNothing);
  });

  testWidgets('a phone number in requirements shows the contact error from '
      'the server', (tester) async {
    final w = await _open(tester);
    await _fill(tester);
    await _type(tester, 'recruit-requirements', 'Gọi 0903123456');
    w.recruits.failWith = const RecruitError(
      RecruitErrorCode.invalidArgument,
      field: 'requirements.contact',
    );
    await _submit(tester);
    expect(
      _inKey(
        'recruit-requirements',
        find.text('Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung'),
      ),
      findsOneWidget,
    );
    expect(_code(ScreenCodes.recruitEdit), findsOneWidget);
  });

  testWidgets('negotiable hides the amount', (tester) async {
    await _open(tester);
    expect(_key('recruit-fee-amount'), findsOneWidget);
    await _tap(tester, find.text('Thoả thuận'));
    expect(_key('recruit-fee-amount'), findsNothing);
    await _tap(tester, find.text('Theo buổi'));
    expect(_key('recruit-fee-amount'), findsOneWidget);
  });

  testWidgets('submit calls create with the exact draft and pops to '
      '/studio/recruit with "Đã đăng tin"', (tester) async {
    final w = await _open(tester);
    await _fill(tester);
    await _type(tester, 'recruit-requirements', '  Có máy full-frame.  ');
    expect(find.text('26/80'), findsOneWidget);
    await _submit(tester);
    expect(
      w.recruits.drafts.single,
      const RecruitDraft(
        kind: RecruitKind.collaborator,
        title: 'Thợ phụ chụp cưới mùa cưới',
        specialties: ['wedding', 'family'],
        areas: ['hcm-q3', 'hcm-q7'],
        frequency: RecruitFrequency.seasonal,
        fee: PerShootFee(800000),
        requirements: 'Có máy full-frame.',
      ),
    );
    expect(w.recruits.calls.single.$1, 'createRecruitPost');
    expect(w.location, '/studio/recruit');
    expect(find.text('Đã đăng tin'), findsOneWidget);
  });

  testWidgets('a member post with a negotiable fee', (tester) async {
    final w = await _open(tester);
    await _tap(tester, find.text('Thành viên studio'));
    await _fill(tester);
    await _tap(tester, find.text('Thoả thuận'));
    await _submit(tester);
    final d = w.recruits.drafts.single;
    expect((d.kind, d.fee), (RecruitKind.member, const NegotiableFee()));
  });

  testWidgets('limit_exceeded shows "Studio đã có 3 tin mở."', (tester) async {
    final w = await _open(tester);
    await _fill(tester);
    w.recruits.failWith = const RecruitError(RecruitErrorCode.limitExceeded);
    await _submit(tester);
    expect(find.text('Studio đã có 3 tin mở.'), findsOneWidget);
    expect(_code(ScreenCodes.recruitEdit), findsOneWidget);
  });

  testWidgets('recruit_blocked shows the block message with the date', (
    tester,
  ) async {
    await _open(
      tester,
      counters: RecruitCounters(
        openPostCount: 1,
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
    expect(_enabled(tester, _key('recruit-submit')), isFalse);
  });

  test('a recruit_blocked refusal reads the block date of the counters', () {
    final l = lookupAppLocalizations(const Locale('vi'));
    expect(
      recruitPostErrorText(
        const RecruitError(RecruitErrorCode.recruitBlocked),
        l,
        blockedUntil: DateTime.utc(2026, 11, 12, 3),
      ),
      'Bạn tạm không đăng tin và mời cộng tác viên tới 12/11 vì chưa trả '
      'thù lao cho cộng tác viên.',
    );
    expect(
      recruitPostErrorText(
        const RecruitError(RecruitErrorCode.recruitBlocked),
        l,
      ),
      'Chưa thực hiện được. Thử lại sau.',
    );
  });

  testWidgets('an individual is sent to /recruit', (tester) async {
    final w = await _open(tester, facts: makeProviderFacts());
    expect(w.location, '/recruit');
  });

  testWidgets('exactly one AppButton.primary', (tester) async {
    await _open(tester);
    expect(find.byType(CtaSurface), findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x', (tester) async {
    await _open(tester, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      _key('recruit-requirements'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
