import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_card.dart';
import 'package:photobooking/features/recruit/recruit_list_screen.dart';

import '../../support/recruit_world.dart';

/// S27.01 has bounded loaders only: a second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _key(String k) => find.byKey(Key(k));

/// The posts' list (the chips row scrolls too).
Finder get _list => find.byType(Scrollable).last;

Finder _inCard(String postId, Finder f) =>
    find.descendant(of: _key('recruit-card-$postId'), matching: f);

final _routes = <RouteBase>[
  GoRoute(
    path: '/recruit',
    builder: (_, s) =>
        RecruitListScreen(studioId: s.uri.queryParameters['studioId']),
  ),
  GoRoute(path: '/recruit/:postId', builder: (_, s) => Text('stub ${s.uri}')),
];

Future<RecruitWorld> _open(
  WidgetTester tester, {
  ProviderFacts? facts,
  List<RecruitPost> posts = const [],
  String location = '/recruit',
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = RecruitWorld();
  w.recruits.setFacts(w.uid, facts ?? makeProviderFacts());
  for (final p in posts) {
    w.recruits.seedPost(p);
  }
  await tester.pumpWidget(
    w.app(location, routes: _routes, textScale: textScale),
  );
  await _settle(tester);
  return w;
}

void main() {
  testWidgets('shows the cards with kind tag, title, studio, areas, '
      'specialties, fee and footer', (tester) async {
    await _open(tester, posts: [makeRecruitPost()]);
    expect(
      find.byWidgetPredicate(
        (w) => w is ScreenCode && w.code == ScreenCodes.recruitList,
      ),
      findsOneWidget,
    );
    expect(_inCard('p1', find.text('Cộng tác theo việc')), findsOneWidget);
    expect(
      _inCard('p1', find.text('Tuyển CTV chụp cưới cuối tuần')),
      findsOneWidget,
    );
    expect(
      _inCard('p1', find.textContaining('Studio Cúc', findRichText: true)),
      findsOneWidget,
    );
    expect(
      _inCard(
        'p1',
        find.textContaining(
          'Quận 1, Quận 3 · Cưới, Gia đình',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    expect(_inCard('p1', find.text('800.000₫/buổi')), findsOneWidget);
    expect(_inCard('p1', find.text('Hằng tuần · hôm qua')), findsOneWidget);
  });

  testWidgets('"Hợp với bạn" only on score-2 posts and they come first', (
    tester,
  ) async {
    await _open(
      tester,
      facts: makeProviderFacts(recruitMatchKeys: ['a=hcm-q1|s=wedding']),
      posts: [
        makeRecruitPost(
          id: 'both',
          title: 'Khớp cả hai',
          areas: ['hcm-q1'],
          specialties: ['wedding'],
          createdAt: recruitNow.subtract(const Duration(days: 3)),
        ),
        makeRecruitPost(
          id: 'none',
          title: 'Không khớp',
          areas: ['hcm-q7'],
          specialties: ['event'],
          createdAt: recruitNow.subtract(const Duration(hours: 1)),
        ),
        makeRecruitPost(
          id: 'one',
          title: 'Khớp khu vực',
          areas: ['hcm-q1'],
          specialties: ['event'],
          createdAt: recruitNow.subtract(const Duration(hours: 2)),
        ),
      ],
    );
    expect(find.text('Hợp với bạn'), findsOneWidget);
    expect(_inCard('both', find.text('Hợp với bạn')), findsOneWidget);
    final ys = [
      for (final id in ['both', 'one', 'none'])
        tester.getTopLeft(_key('recruit-card-$id')).dy,
    ];
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue, reason: '$ys');
  });

  testWidgets('a negotiable fee shows "Thoả thuận"', (tester) async {
    await _open(
      tester,
      posts: [
        makeRecruitPost(kind: RecruitKind.member, fee: const NegotiableFee()),
      ],
    );
    expect(_inCard('p1', find.text('Thoả thuận')), findsOneWidget);
    expect(_inCard('p1', find.text('Vào studio')), findsOneWidget);
  });

  testWidgets('choosing an area then a specialty queries the combined filter '
      'key', (tester) async {
    final w = await _open(tester, posts: [makeRecruitPost()]);
    expect(w.recruits.listedKeys, ['']);
    await tester.tap(_key('recruit-filter-area'));
    await _settle(tester);
    await tester.tap(find.text('Quận 3, TP.HCM'));
    await _settle(tester);
    expect(w.recruits.listedKeys.last, 'a=hcm-q3');
    expect(
      find.descendant(
        of: _key('recruit-filter-area'),
        matching: find.text('Quận 3'),
      ),
      findsOneWidget,
    );
    await tester.tap(_key('recruit-filter-specialty'));
    await _settle(tester);
    await tester.tap(find.text('Cưới'));
    await _settle(tester);
    expect(w.recruits.listedKeys.last, 'a=hcm-q3|s=wedding');
    expect(_key('recruit-card-p1'), findsOneWidget);
    await tester.ensureVisible(_key('recruit-filter-kind-member'));
    await tester.pump();
    await tester.tap(_key('recruit-filter-kind-member'));
    await _settle(tester);
    expect(w.recruits.listedKeys.last, 'k=member|a=hcm-q3|s=wedding');
    expect(_key('recruit-card-p1'), findsNothing);
  });

  testWidgets('"Xem thêm" loads the next page with the last cursor', (
    tester,
  ) async {
    final w = await _open(
      tester,
      posts: [
        for (var i = 0; i < 25; i++)
          makeRecruitPost(
            id: 'p$i',
            title: 'Tin $i',
            createdAt: recruitNow.subtract(Duration(hours: i + 1)),
          ),
      ],
    );
    expect(w.recruits.listedCursors, [null]);
    final more = _key('recruit-load-more');
    await tester.scrollUntilVisible(more, 300, scrollable: _list);
    await tester.tap(more);
    await _settle(tester);
    expect(w.recruits.listedCursors, [null, 20]);
    await tester.scrollUntilVisible(
      _key('recruit-card-p24'),
      300,
      scrollable: _list,
    );
    expect(_key('recruit-card-p24'), findsOneWidget);
    expect(more, findsNothing);
  });

  testWidgets('empty filter shows "Chưa có tin tuyển nào hợp bộ lọc."', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Chưa có tin tuyển nào hợp bộ lọc.'), findsOneWidget);
  });

  testWidgets('shows "Chỉ thợ ảnh và studio thấy mục này."', (tester) async {
    await _open(tester, posts: [makeRecruitPost()]);
    expect(find.text('Chỉ thợ ảnh và studio thấy mục này.'), findsOneWidget);
  });

  testWidgets('a customer-mode account sees only the note and nothing is '
      'queried (R3)', (tester) async {
    final w = await _open(
      tester,
      facts: makeProviderFacts(role: 'customer'),
      posts: [makeRecruitPost()],
    );
    expect(find.text('Chỉ thợ ảnh và studio thấy mục này.'), findsOneWidget);
    expect(_key('recruit-card-p1'), findsNothing);
    expect(w.recruits.listedKeys, isEmpty);
  });

  testWidgets('/recruit?studioId= lists that studio\'s open posts', (
    tester,
  ) async {
    final w = await _open(
      tester,
      location: '/recruit?studioId=cuc',
      posts: [
        makeRecruitPost(),
        makeRecruitPost(id: 'p2', studioId: 'nang', studioName: 'Studio Nắng'),
      ],
    );
    expect(w.recruits.listedKeys, ['studio:cuc']);
    expect(_key('recruit-card-p1'), findsOneWidget);
    expect(_key('recruit-card-p2'), findsNothing);
  });

  testWidgets('a card opens its post', (tester) async {
    final w = await _open(tester, posts: [makeRecruitPost()]);
    await tester.tap(_key('recruit-card-p1'));
    await _settle(tester);
    expect(w.location, '/recruit/p1');
  });

  testWidgets('a studio viewer sees the "Tin tuyển của studio" icon opening '
      '/studio/recruit; an individual does not', (tester) async {
    final w = await _open(
      tester,
      facts: makeProviderFacts(providerType: ProviderType.studio),
    );
    final action = find.byTooltip('Tin tuyển của studio');
    expect(action, findsOneWidget);
    await tester.tap(action);
    await _settle(tester);
    expect(w.location, '/studio/recruit');

    await tester.pumpWidget(const SizedBox.shrink());
    await _open(tester);
    expect(find.byTooltip('Tin tuyển của studio'), findsNothing);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _open(
      tester,
      size: const Size(320, 640),
      textScale: 1.3,
      facts: makeProviderFacts(
        providerType: ProviderType.studio,
        recruitMatchKeys: ['a=hcm-q1|s=wedding'],
      ),
      posts: [
        makeRecruitPost(
          title: 'Thợ phụ chụp cưới mùa cưới cho các studio lớn ở Sài Gòn',
          areas: ['hcm-q1', 'hcm-q3', 'hcm-q7', 'hcm-binh-thanh'],
          specialties: ['wedding', 'family', 'event'],
          frequency: RecruitFrequency.occasional,
          fee: const PerShootFee(12000000),
          createdAt: recruitNow.subtract(const Duration(days: 9)),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(
      _inCard('p1', find.text('Vài buổi/tháng · 1 tuần trước')),
      findsOneWidget,
    );
    expect(find.byType(RecruitCard), findsOneWidget);
  });

  testWidgets('a post past its expiry is hidden even while still open', (
    tester,
  ) async {
    await _open(
      tester,
      posts: [
        makeRecruitPost(id: 'live'),
        makeRecruitPost(
          id: 'lapsed',
          title: 'Tin đã quá hạn nhưng chưa quét',
          expiresAt: recruitNow.subtract(const Duration(minutes: 1)),
        ),
      ],
    );
    expect(_key('recruit-card-live'), findsOneWidget);
    expect(_key('recruit-card-lapsed'), findsNothing);
    expect(find.text('Tin đã quá hạn nhưng chưa quét'), findsNothing);
  });

  testWidgets('only lapsed posts: the empty line shows', (tester) async {
    await _open(
      tester,
      posts: [
        makeRecruitPost(
          expiresAt: recruitNow.subtract(const Duration(minutes: 1)),
        ),
      ],
    );
    expect(_key('recruit-empty'), findsOneWidget);
  });
}
