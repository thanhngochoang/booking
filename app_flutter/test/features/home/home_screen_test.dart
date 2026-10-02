import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/recommendation/resilient_recommendation_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/home/home_screen.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/p/:id',
      builder: (_, s) => Text('post ${s.pathParameters['id']}'),
    ),
    GoRoute(
      path: '/u/:id',
      builder: (_, s) => Text('profile ${s.pathParameters['id']}'),
    ),
    GoRoute(path: '/action', builder: (_, _) => const Text('find')),
    GoRoute(path: '/explore', builder: (_, _) => const Text('explore')),
  ],
);

/// A phone: 390 wide, tall enough for the hero card and the next section.
void _phone(WidgetTester tester, [Size size = const Size(390, 1800)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<Widget> _app(
  DiscoveryWorld w, {
  double textScale = 1,
  GoRouter? router,
}) async {
  await w.init();
  return screenRouterApp(
    router: router ?? _router(),
    overrides: w.overrides,
    textScale: textScale,
  );
}

Future<void> _pump(
  WidgetTester tester,
  DiscoveryWorld w, {
  double textScale = 1,
  Size size = const Size(390, 1800),
}) async {
  _phone(tester, size);
  await tester.pumpWidget(await _app(w, textScale: textScale));
  await tester.pumpAndSettle();
}

/// The vertical feed (the chip row scrolls sideways).
final _feed = find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

double _left(WidgetTester t, Key k) => t.getTopLeft(find.byKey(k)).dx;

void main() {
  testWidgets(
    'header, chips and the first post with its pills, name row and save button',
    (tester) async {
      await _pump(tester, DiscoveryWorld());
      expect(find.text('Chào Lan Anh'), findsOneWidget);
      expect(find.text('Hôm nay chụp gì?'), findsOneWidget);
      for (final label in [
        'Dành cho bạn',
        'Chân dung',
        'Cưới',
        'Gia đình',
        'Kỷ yếu',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final card = find.byKey(const Key('post-a'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Rảnh T7 này')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Chân dung · từ 1,5M')),
        findsOneWidget,
      );
      final author = find.byKey(const Key('author-a'));
      expect(
        find.descendant(
          of: author,
          matching: find.textContaining('Minh Trí', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: author,
          matching: find.text('Quận 3 · ★ 4,9 (58) · 112 buổi'),
        ),
        findsOneWidget,
      );
      expect(find.byType(VerifiedMark), findsWidgets);
      expect(find.byKey(const Key('save-a')), findsOneWidget);
    },
  );

  testWidgets('reasons appear under the large card, at most two', (
    tester,
  ) async {
    await _pump(tester, DiscoveryWorld());
    // Post a is by p1 (free Sat 3 Oct): the reason is listed under the card,
    // and never more than two chips per card.
    expect(find.text('Rảnh T7 03/10'), findsWidgets);
    expect(find.byType(ReasonChips), findsWidgets);
    for (final chips in tester.widgetList<ReasonChips>(
      find.byType(ReasonChips),
    )) {
      expect(chips.max, lessThanOrEqualTo(2));
    }
  });

  testWidgets(
    'the title uses the tab-root style and the chip starts from the provider',
    (tester) async {
      final router = _router();
      _phone(tester);
      await tester.pumpWidget(await _app(DiscoveryWorld(), router: router));
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(find.text('Hôm nay chụp gì?'));
      final ctx = tester.element(find.text('Hôm nay chụp gì?'));
      expect(title.style, tabRootTitleStyle(ctx));
      await tester.tap(find.byKey(const Key('home-chip-wedding')));
      await tester.pumpAndSettle();
      // Leave and come back: the screen is rebuilt, the provider keeps the chip.
      router.go('/action');
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post-b')), findsOneWidget);
      final chip = tester.widget<AppChip>(
        find.byKey(const Key('home-chip-wedding')),
      );
      expect(chip.selected, isTrue);
    },
  );

  testWidgets('"Rảnh tuần này" lists the free photographers, soonest first', (
    tester,
  ) async {
    await _pump(tester, DiscoveryWorld());
    expect(find.text('Rảnh tuần này'), findsOneWidget);
    expect(
      _left(tester, const Key('free-p2')),
      lessThan(_left(tester, const Key('free-p1'))),
    );
    expect(
      _left(tester, const Key('free-p1')),
      lessThan(_left(tester, const Key('free-p3'))),
    );
  });

  testWidgets(
    '"Buổi chụp thật" shows the customers\' photos with the photographer',
    (tester) async {
      await _pump(tester, DiscoveryWorld());
      await tester.scrollUntilVisible(
        find.byKey(const Key('real-r1')),
        300,
        scrollable: _feed,
      );
      expect(find.text('Buổi chụp thật'), findsOneWidget);
      expect(find.text('Từ khách hàng'), findsOneWidget);
      expect(find.text('Chụp bởi Minh Trí'), findsOneWidget);
    },
  );

  testWidgets(
    'taps: card to S02.02, name row to S03.01, small card to S03.01, "Xem tất cả" to S02.06',
    (tester) async {
      final w = DiscoveryWorld();
      final router = _router();
      _phone(tester);
      await tester.pumpWidget(await _app(w, router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post-a')));
      await tester.pumpAndSettle();
      expect(find.text('post a'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('author-a')));
      await tester.pumpAndSettle();
      expect(find.text('profile p1'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('free-p2')));
      await tester.pumpAndSettle();
      expect(find.text('profile p2'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xem tất cả'));
      await tester.pumpAndSettle();
      expect(find.text('find'), findsOneWidget);
    },
  );

  testWidgets(
    'a photographer has no "Xem tất cả" (their middle tab is not Find)',
    (tester) async {
      await _pump(tester, DiscoveryWorld(role: UserRole.photographer));
      expect(find.text('Rảnh tuần này'), findsOneWidget);
      expect(find.text('Xem tất cả'), findsNothing);
    },
  );

  testWidgets('saving is instant, undoable, and a failure says so', (
    tester,
  ) async {
    final w = DiscoveryWorld();
    await _pump(tester, w);
    expect(
      find.descendant(
        of: find.byKey(const Key('save-a')),
        matching: find.byIcon(Icons.bookmark_border),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('save-a')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('save-a')),
        matching: find.byIcon(Icons.bookmark),
      ),
      findsOneWidget,
      reason: 'shown before the write finishes',
    );
    await tester.pumpAndSettle();
    expect(w.engagement.writeCalls, 1);

    w.engagement.failWith = StateError('offline');
    await tester.tap(find.byKey(const Key('save-a')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa thực hiện được. Thử lại nhé.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('save-a')),
        matching: find.byIcon(Icons.bookmark),
      ),
      findsOneWidget,
      reason: 'back to saved after the failed undo',
    );
  });

  testWidgets('a category chip reloads the feed for that specialty and back', (
    tester,
  ) async {
    await _pump(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('home-chip-wedding')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-b')), findsOneWidget);
    expect(find.byKey(const Key('post-a')), findsNothing);
    await tester.tap(find.byKey(const Key('home-chip-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-a')), findsOneWidget);
  });

  testWidgets('an empty feed offers the way to Explore', (tester) async {
    final w = DiscoveryWorld(posts: const []);
    final router = _router();
    _phone(tester);
    await tester.pumpWidget(await _app(w, router: router));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có ảnh nào quanh bạn'), findsOneWidget);
    await tester.tap(find.text('Khám phá nhiếp ảnh gia'));
    await tester.pumpAndSettle();
    expect(find.text('explore'), findsOneWidget);
  });

  testWidgets('an error shows the retry, which reloads', (tester) async {
    final w = DiscoveryWorld();
    w.posts.failWith = StateError('offline');
    await _pump(tester, w);
    expect(
      find.text('Không tải được ảnh. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    w.posts.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-a')), findsOneWidget);
  });

  testWidgets('scrolling near the end loads the next page', (tester) async {
    final w = DiscoveryWorld(
      posts: [
        for (var i = 0; i < 45; i++)
          fixturePost(
            'm${i.toString().padLeft(2, '0')}',
            photographerId: 'p1',
            age: Duration(minutes: i + 1),
            specialtyId: 'portrait',
          ),
      ],
    );
    await _pump(tester, w);
    await tester.scrollUntilVisible(
      find.byKey(const Key('post-m44')),
      600,
      scrollable: _feed,
      maxScrolls: 200,
    );
    expect(find.byKey(const Key('post-m44')), findsOneWidget);
  });

  testWidgets('each chip remembers its own scroll position', (tester) async {
    final w = DiscoveryWorld(
      posts: [
        for (var i = 0; i < 40; i++)
          fixturePost(
            'm${i.toString().padLeft(2, '0')}',
            photographerId: 'p1',
            age: Duration(minutes: i + 1),
            specialtyId: 'portrait',
          ),
      ],
    );
    await _pump(tester, w);
    double offset() => tester.state<ScrollableState>(_feed).position.pixels;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final saved = offset();
    expect(saved, greaterThan(500));
    await tester.tap(find.byKey(const Key('home-chip-portrait')));
    await tester.pumpAndSettle();
    expect(
      offset(),
      lessThan(saved),
      reason: 'the other chip starts at the top',
    );
    await tester.tap(find.byKey(const Key('home-chip-all')));
    await tester.pumpAndSettle();
    expect(offset(), closeTo(saved, 40));
  });

  testWidgets('pull down reloads the feed', (tester) async {
    final w = DiscoveryWorld();
    await _pump(tester, w);
    w.posts.add(
      fixturePost(
        'fresh',
        photographerId: 'p1',
        age: const Duration(seconds: 1),
        specialtyId: 'portrait',
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-fresh')), findsOneWidget);
  });

  testWidgets(
    'the local-fallback ranking is used silently when the remote one is down',
    (tester) async {
      final w = DiscoveryWorld(
        recommenderFactory: (x) => ResilientRecommendationRepository(
          primary: ThrowingRecommender(),
          fallback: x.localRecommender(),
        ),
      );
      await _pump(tester, w);
      expect(find.byKey(const Key('post-a')), findsOneWidget);
    },
  );

  for (final b in Brightness.values) {
    testWidgets('fits 320x640 at 1.3x on ${b.name} with no blur', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = DiscoveryWorld();
      await w.init();
      await tester.pumpWidget(
        screenApp(
          home: const HomeScreen(),
          overrides: w.overrides,
          textScale: 1.3,
          brightness: b,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }

  testWidgets('from 600dp the posts below the first card use two columns', (
    tester,
  ) async {
    await _pump(tester, DiscoveryWorld(), size: const Size(900, 1400));
    await tester.scrollUntilVisible(
      find.byKey(const Key('post-c')),
      300,
      scrollable: _feed,
    );
    final b = tester.getTopLeft(find.byKey(const Key('post-b')));
    final c = tester.getTopLeft(find.byKey(const Key('post-c')));
    expect(b.dy, c.dy);
    expect(c.dx, greaterThan(b.dx));
  });
}
