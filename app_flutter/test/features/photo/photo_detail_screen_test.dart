// test/features/photo/photo_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/photo/photo_detail_screen.dart';

import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

GoRouter _router(String start) => GoRouter(
  initialLocation: start,
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const Text('home')),
    GoRoute(
      path: '/p/:id',
      builder: (_, s) => PhotoDetailScreen(postId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/u/:id',
      builder: (_, s) =>
          Text('profile ${s.pathParameters['id']} ${s.uri.query}'),
    ),
    GoRoute(path: '/u/:id/book', builder: (_, s) => Text('book ${s.uri}')),
    GoRoute(
      path: '/profile/phone',
      builder: (_, s) => Text('phone ${s.uri.queryParameters['returnTo']}'),
    ),
  ],
);

Future<GoRouter> _open(
  WidgetTester tester,
  DiscoveryWorld w, {
  String start = '/p/a',
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await w.init();
  final router = _router(start);
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: w.overrides,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _in(String key, Finder f) =>
    find.descendant(of: find.byKey(Key(key)), matching: f);

void main() {
  testWidgets('shows the post, its author, counts, location and package', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld());
    expect(find.text('Chiều muộn ở bến Bạch Đằng #chandung'), findsOneWidget);
    expect(find.textContaining('Minh Trí', findRichText: true), findsWidgets);
    expect(find.byType(VerifiedMark), findsOneWidget);
    expect(find.text('Chân dung · Quận 3 · ★ 4,9 (58)'), findsOneWidget);
    expect(_in('like', find.text('214')), findsOneWidget);
    expect(_in('save', find.text('37')), findsOneWidget);
    expect(find.text('Bến Bạch Đằng'), findsOneWidget);
    expect(_in('service-card', find.text('Chân dung 2 giờ')), findsOneWidget);
    expect(_in('service-card', find.text('1.500.000₫')), findsOneWidget);
    expect(
      _in('service-card', find.text('40 ảnh · giao sau 5 ngày · 2 giờ')),
      findsOneWidget,
    );
  });

  testWidgets('the package card shows the package thumbnail beside its name', (
    tester,
  ) async {
    final w = DiscoveryWorld(
      services: [
        const ServiceSummary(
          id: 's1',
          photographerId: 'p1',
          name: 'Chân dung 2 giờ',
          priceVnd: 1500000,
          durationMinutes: 120,
          coverUrl: 'https://img.test/s1-cover.jpg',
        ),
      ],
    );
    await _open(tester, w);
    expect(_in('service-card', find.byType(NetworkPhoto)), findsOneWidget);
    expect(_in('service-card', find.text('2 giờ')), findsOneWidget);
  });

  testWidgets('"Thêm của" shows up to three other photos of the photographer', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld());
    await tester.scrollUntilVisible(
      find.text('Thêm của Minh Trí'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('more-r1')), findsOneWidget);
    expect(find.byKey(const Key('more-e')), findsOneWidget);
    expect(
      find.byKey(const Key('more-a')),
      findsNothing,
      reason: 'not the post being viewed',
    );
  });

  testWidgets(
    'like: instant, counted, undone by a second tap, reverted when the write fails',
    (tester) async {
      final w = DiscoveryWorld();
      await _open(tester, w);
      await tester.tap(find.byKey(const Key('like')));
      await tester.pump();
      expect(_in('like', find.text('215')), findsOneWidget);
      expect(_in('like', find.byIcon(Icons.favorite)), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('like')));
      await tester.pumpAndSettle();
      expect(_in('like', find.text('214')), findsOneWidget);

      w.engagement.failWith = StateError('offline');
      await tester.tap(find.byKey(const Key('like')));
      await tester.pumpAndSettle();
      expect(_in('like', find.text('214')), findsOneWidget);
      expect(find.text('Chưa thực hiện được. Thử lại nhé.'), findsOneWidget);
    },
  );

  testWidgets('double tap on the photo likes it, and only likes it', (
    tester,
  ) async {
    final w = DiscoveryWorld();
    await _open(tester, w);
    final gallery = find.byKey(const Key('photo-gallery'));
    await tester.tap(gallery);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(gallery);
    await tester.pumpAndSettle();
    expect(_in('like', find.text('215')), findsOneWidget);
    await tester.tap(gallery);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(gallery);
    await tester.pumpAndSettle();
    expect(
      _in('like', find.text('215')),
      findsOneWidget,
      reason: 'a second double tap does not unlike',
    );
  });

  testWidgets('save and follow toggle', (tester) async {
    final w = DiscoveryWorld();
    await _open(tester, w);
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(_in('save', find.text('38')), findsOneWidget);
    expect(find.text('Theo dõi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow')));
    await tester.pumpAndSettle();
    expect(find.text('Đang theo dõi'), findsOneWidget);
    expect(w.engagement.writeCalls, 2);
  });

  testWidgets('a post with several photos pages through them with dots', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld(), start: '/p/e');
    double dot(int i) =>
        ((tester.widget<DecoratedBox>(find.byKey(Key('page-dot-$i'))).decoration
                    as BoxDecoration)
                .color!)
            .a;
    expect(dot(0), 1.0);
    expect(dot(1), 0.5);
    await tester.fling(
      find.byKey(const Key('photo-gallery')),
      const Offset(-400, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(dot(0), 0.5);
    expect(dot(1), 1.0);
  });

  testWidgets('a single photo has no dots', (tester) async {
    await _open(tester, DiscoveryWorld());
    expect(find.byKey(const Key('page-dot-0')), findsNothing);
  });

  testWidgets(
    '"Đặt gói này" opens the booking with the package, or S04.05 first without a phone',
    (tester) async {
      final router = await _open(tester, DiscoveryWorld());
      await tester.tap(find.byKey(const Key('photo-book')));
      await tester.pumpAndSettle();
      expect(find.text('book /u/p1/book?serviceId=s1'), findsOneWidget);
      router.pop();

      await _open(tester, DiscoveryWorld(hasPhone: false));
      await tester.tap(find.byKey(const Key('photo-book')));
      await tester.pumpAndSettle();
      expect(find.text('phone /u/p1/book?serviceId=s1'), findsOneWidget);
    },
  );

  testWidgets('"Xem hồ sơ" opens S03.01', (tester) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('photo-profile')));
    await tester.pumpAndSettle();
    expect(find.text('profile p1 '), findsOneWidget);
  });

  testWidgets(
    'a retired package is faded and the button leads to the other packages',
    (tester) async {
      final w = DiscoveryWorld(
        posts: [fixturePost('old', photographerId: 'p1', serviceId: 'sOld')],
      );
      await _open(tester, w, start: '/p/old');
      expect(find.text('Gói này đã ngừng'), findsOneWidget);
      expect(find.text('Đặt gói này'), findsNothing);
      await tester.tap(find.byKey(const Key('photo-book')));
      await tester.pumpAndSettle();
      expect(find.text('profile p1 tab=services'), findsOneWidget);
    },
  );

  testWidgets(
    'a customer\'s real-shoot photo says who shot it and with which package',
    (tester) async {
      await _open(tester, DiscoveryWorld(), start: '/p/r1');
      expect(
        find.text('Chụp bởi Minh Trí · gói Chân dung 2 giờ'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a real-shoot photo whose package is gone shows no package', (
    tester,
  ) async {
    await _open(
      tester,
      DiscoveryWorld(
        posts: [
          ...discoveryPosts(),
          fixturePost(
            'r3',
            kind: PostKind.realShoot,
            authorId: 'cu1',
            photographerId: 'p1',
            serviceId: 'gone',
          ),
        ],
      ),
      start: '/p/r3',
    );
    expect(find.text('Chụp bởi Minh Trí'), findsOneWidget);
    expect(find.textContaining('· gói'), findsNothing);
  });

  testWidgets('a removed post says so and leads home', (tester) async {
    await _open(tester, DiscoveryWorld(), start: '/p/ghost');
    expect(find.text('Bài đăng không còn'), findsOneWidget);
    await tester.tap(find.text('Về trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a failing load shows the retry', (tester) async {
    final w = DiscoveryWorld();
    w.posts.failWith = StateError('offline');
    await _open(tester, w);
    expect(
      find.text('Không tải được bài đăng. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    w.posts.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Chiều muộn ở bến Bạch Đằng #chandung'), findsOneWidget);
  });

  testWidgets('Back goes home when there is nothing to go back to', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('photo-back')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets(
      'fits 320x640 at 1.3x on ${b.name} with no blur; the bottom buttons stack',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final w = DiscoveryWorld();
        await w.init();
        await tester.pumpWidget(
          screenRouterApp(
            router: _router('/p/a'),
            overrides: w.overrides,
            textScale: 1.3,
            brightness: b,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BackdropFilter), findsNothing);
        final profile = tester.getRect(find.byKey(const Key('photo-profile')));
        final book = tester.getRect(find.byKey(const Key('photo-book')));
        expect((profile.height, book.height), (controlHeight, controlHeight));
        expect(book.top, greaterThanOrEqualTo(profile.bottom));
      },
    );
  }
}
