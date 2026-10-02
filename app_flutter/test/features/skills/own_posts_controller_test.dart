// test/features/skills/own_posts_controller_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/features/skills/own_posts_controller.dart';

import '../../support/content_fixtures.dart';
import '../../support/skills_world.dart';

void main() {
  test('own posts only, 30 per page, newest first', () async {
    final w = await SkillsWorld.create(
      posts: (uid) => [
        for (var i = 0; i < 40; i++)
          fixturePost(
            'm$i',
            photographerId: uid,
            age: Duration(minutes: i + 1),
          ),
        fixturePost(
          'shared',
          photographerId: uid,
          authorId: 'customer1',
          kind: PostKind.realShoot,
        ),
        fixturePost('other', photographerId: 'someone-else'),
      ],
    );
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(ownPostsProvider, (_, _) {});
    final first = await c.read(ownPostsProvider.future);
    expect(first.posts, hasLength(30));
    expect(first.posts.first.id, 'm0');
    expect(first.posts.first.imageUrl, 'https://img.test/m0-0.jpg');
    expect(first.hasMore, isTrue);
    await c.read(ownPostsProvider.notifier).loadMore();
    final all = c.read(ownPostsProvider).requireValue;
    expect(all.posts.map((p) => p.id), [for (var i = 0; i < 40; i++) 'm$i']);
    expect(all.hasMore, isFalse);
    await c.read(ownPostsProvider.notifier).loadMore();
    expect(
      c.read(ownPostsProvider).requireValue.posts,
      hasLength(40),
      reason: 'no page after the last',
    );
  });

  test('a failed next page keeps what is shown, is not retried by scrolling, and retries on request', () async {
    final w = await SkillsWorld.create(
      posts: (uid) => [
        for (var i = 0; i < 35; i++)
          fixturePost(
            'm$i',
            photographerId: uid,
            age: Duration(minutes: i + 1),
          ),
      ],
    );
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(ownPostsProvider, (_, _) {});
    await c.read(ownPostsProvider.future);
    w.posts.failWith = StateError('offline');
    await c.read(ownPostsProvider.notifier).loadMore();
    await c.read(ownPostsProvider.notifier).loadMore();
    final s = c.read(ownPostsProvider).requireValue;
    expect(s.posts, hasLength(30));
    expect(s.loadingMore, isFalse);
    expect(
      w.posts.byPhotographerCursors.where((c) => c == 'm29'),
      hasLength(1),
      reason: 'the failing page is requested once, not on every scroll',
    );
    expect(s.loadMoreFailed, isTrue);
    expect(s.hasMore, isTrue);
    w.posts.failWith = null;
    await c.read(ownPostsProvider.notifier).retryLoadMore();
    final after = c.read(ownPostsProvider).requireValue;
    expect(
      w.posts.byPhotographerCursors.where((c) => c == 'm29'),
      hasLength(2),
      reason: 'the retry row asks for the failed page again',
    );
    expect(after.posts, hasLength(35));
    expect(after.loadMoreFailed, isFalse);
  });

  test('a page of customer posts does not hide own posts behind it', () async {
    final w = await SkillsWorld.create(
      posts: (uid) => [
        for (var i = 0; i < 30; i++)
          fixturePost(
            'c$i',
            photographerId: uid,
            authorId: 'customer1',
            kind: PostKind.realShoot,
            age: Duration(minutes: i + 1),
          ),
        for (var i = 0; i < 5; i++)
          fixturePost(
            'm$i',
            photographerId: uid,
            age: Duration(hours: 2, minutes: i),
          ),
      ],
    );
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(ownPostsProvider, (_, _) {});
    final first = await c.read(ownPostsProvider.future);
    expect(first.posts.map((p) => p.id), [for (var i = 0; i < 5; i++) 'm$i']);
    expect(first.hasMore, isFalse);
    expect(w.posts.byPhotographerCursors, [null, 'c29']);
  });

  test('7 pages of customer posts only: own posts load in one call', () async {
    final w = await SkillsWorld.create(
      posts: (uid) => [
        for (var i = 0; i < 210; i++)
          fixturePost(
            'c$i',
            photographerId: uid,
            authorId: 'customer1',
            kind: PostKind.realShoot,
            age: Duration(minutes: i + 1),
          ),
        for (var i = 0; i < 3; i++)
          fixturePost(
            'm$i',
            photographerId: uid,
            age: Duration(days: 1, minutes: i),
          ),
      ],
    );
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(ownPostsProvider, (_, _) {});
    final first = await c.read(ownPostsProvider.future);
    expect(first.posts.map((p) => p.id), ['m0', 'm1', 'm2']);
    expect(first.hasMore, isFalse);
    expect(w.posts.byPhotographerCursors, hasLength(8));
  });

  test(
    'keeps fetching until 30 own posts are held, without scrolling',
    () async {
      final w = await SkillsWorld.create(
        posts: (uid) => [
          for (var i = 0; i < 2; i++)
            fixturePost(
              'a$i',
              photographerId: uid,
              age: Duration(minutes: i),
            ),
          for (var i = 0; i < 28; i++)
            _customer('x$i', uid, Duration(hours: 1, minutes: i)),
          fixturePost('b0', photographerId: uid, age: const Duration(hours: 5)),
          for (var i = 0; i < 29; i++)
            _customer('y$i', uid, Duration(hours: 6, minutes: i)),
          for (var i = 0; i < 35; i++)
            fixturePost(
              'z$i',
              photographerId: uid,
              age: Duration(days: 1, minutes: i),
            ),
        ],
      );
      final c = w.container();
      addTearDown(c.dispose);
      c.listen(ownPostsProvider, (_, _) {});
      final first = await c.read(ownPostsProvider.future);
      expect(first.posts, hasLength(33));
      expect(first.hasMore, isTrue);
      expect(w.posts.byPhotographerCursors, hasLength(3));
    },
  );

  test('one call stops after 20 pages without own posts', () async {
    final w = await SkillsWorld.create(
      posts: (uid) => [
        for (var i = 0; i < 700; i++)
          _customer('c$i', uid, Duration(minutes: i + 1)),
        for (var i = 0; i < 3; i++)
          fixturePost(
            'm$i',
            photographerId: uid,
            age: Duration(days: 1, minutes: i),
          ),
      ],
    );
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(ownPostsProvider, (_, _) {});
    final first = await c.read(ownPostsProvider.future);
    expect(first.posts, isEmpty);
    expect(first.hasMore, isTrue);
    expect(w.posts.byPhotographerCursors, hasLength(20));
    await c.read(ownPostsProvider.notifier).loadMore();
    final all = c.read(ownPostsProvider).requireValue;
    expect(all.posts.map((p) => p.id), ['m0', 'm1', 'm2']);
    expect(all.hasMore, isFalse);
  });

  test(
    'a session reads at most 100 pages, then waits for a manual chunk',
    () async {
      final w = await SkillsWorld.create(
        posts: (uid) => [
          for (var i = 0; i < 4500; i++)
            _customer('c$i', uid, Duration(minutes: i + 1)),
        ],
      );
      final c = w.container();
      addTearDown(c.dispose);
      c.listen(ownPostsProvider, (_, _) {});
      await c.read(ownPostsProvider.future);
      final n = c.read(ownPostsProvider.notifier);
      for (var i = 0; i < 10; i++) {
        await n.loadMore();
      }
      expect(w.posts.byPhotographerCursors, hasLength(100));
      final s = c.read(ownPostsProvider).requireValue;
      expect(s.capped, isTrue);
      expect(s.hasMore, isTrue);
      await n.loadMoreManually();
      expect(w.posts.byPhotographerCursors, hasLength(120));
      expect(c.read(ownPostsProvider).requireValue.capped, isTrue);
    },
  );

  test('closing the sheet stops the read chain', () async {
    final w = await SkillsWorld.create(
      posts: (uid) => [
        for (var i = 0; i < 300; i++)
          _customer('c$i', uid, Duration(minutes: i + 1)),
      ],
    );
    final gate = Completer<void>();
    w.posts.holdByPhotographer = gate.future;
    final c = w.container();
    addTearDown(c.dispose);
    final sub = c.listen(ownPostsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(w.posts.byPhotographerCursors, hasLength(1));
    sub.close();
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(w.posts.byPhotographerCursors, hasLength(1));
  });

  test(
    'several loadMore calls while one is in flight fetch one page',
    () async {
      final w = await SkillsWorld.create(
        posts: (uid) => [
          for (var i = 0; i < 35; i++)
            fixturePost(
              'm$i',
              photographerId: uid,
              age: Duration(minutes: i + 1),
            ),
        ],
      );
      final c = w.container();
      addTearDown(c.dispose);
      c.listen(ownPostsProvider, (_, _) {});
      await c.read(ownPostsProvider.future);
      final n = c.read(ownPostsProvider.notifier);
      await Future.wait([n.loadMore(), n.loadMore(), n.loadMore()]);
      expect(c.read(ownPostsProvider).requireValue.posts, hasLength(35));
      expect(w.posts.byPhotographerCursors, [
        null,
        'm29',
      ], reason: 'page 2 is requested exactly once');
    },
  );
}

PostSummary _customer(String id, String uid, Duration age) => fixturePost(
  id,
  photographerId: uid,
  authorId: 'customer1',
  kind: PostKind.realShoot,
  age: age,
);
