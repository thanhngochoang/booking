import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/home/home_controller.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';

class _Spy extends DelegatingRecommender {
  _Spy(super.inner);
  final List<PostRecommendationQuery> queries = [];
  @override
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery q) {
    queries.add(q);
    return super.recommendPosts(q);
  }
}

Future<(ProviderContainer, DiscoveryWorld, _Spy)> _make({
  DiscoveryWorld? world,
}) async {
  _Spy? spy;
  final use =
      world ??
      DiscoveryWorld(
        recommenderFactory: (x) => spy = _Spy(x.localRecommender()),
      );
  await use.init();
  final c = ProviderContainer(overrides: use.overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  return (c, use, spy ?? _Spy(use.recommender));
}

void main() {
  test(
    'the first page is the recommender\'s order and seeds engagement',
    () async {
      final (c, _, spy) = await _make();
      final s = await c.read(homeFeedProvider.future);
      expect(s.category, isNull);
      expect(s.items.map((e) => e.post.id), ['a', 'b', 'c', 'e', 'd']);
      expect(spy.queries.single.limit, 20);
      expect(spy.queries.single.specialtyId, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(engagementProvider).keys, containsAll(['a', 'b']));
      expect(c.read(engagementProvider)['a']!.likeCount, 214);
    },
  );

  test('selecting a category reloads with that specialty', () async {
    final (c, _, spy) = await _make();
    await c.read(homeFeedProvider.future);
    await c.read(homeFeedProvider.notifier).selectCategory('wedding');
    final s = c.read(homeFeedProvider).requireValue;
    expect(s.category, 'wedding');
    expect(s.items.map((e) => e.post.id), ['b']);
    expect(spy.queries.last.specialtyId, 'wedding');
    await c.read(homeFeedProvider.notifier).selectCategory(null);
    expect(c.read(homeFeedProvider).requireValue.items, hasLength(5));
  });

  test('loadMore appends the next page once and stops at the end', () async {
    final many = DiscoveryWorld(
      posts: [
        for (var i = 0; i < 45; i++)
          fixturePost(
            'm$i',
            photographerId: 'p1',
            age: Duration(minutes: i + 1),
            specialtyId: 'portrait',
          ),
      ],
    );
    final (c, _, _) = await _make(world: many);
    final n = c.read(homeFeedProvider.notifier);
    var s = await c.read(homeFeedProvider.future);
    expect(s.items, hasLength(20));
    expect(s.cursor, isNotNull);
    await Future.wait([n.loadMore(), n.loadMore()]);
    s = c.read(homeFeedProvider).requireValue;
    expect(s.items, hasLength(40), reason: 'two taps at once load one page');
    await n.loadMore();
    s = c.read(homeFeedProvider).requireValue;
    expect(s.items, hasLength(45));
    expect(s.cursor, isNull);
    expect(s.loadingMore, isFalse);
    await n.loadMore();
    expect(c.read(homeFeedProvider).requireValue.items, hasLength(45));
  });

  test('a failed loadMore keeps the feed and the cursor for a retry', () async {
    final many = DiscoveryWorld(
      posts: [
        for (var i = 0; i < 30; i++)
          fixturePost(
            'm$i',
            photographerId: 'p1',
            age: Duration(minutes: i + 1),
          ),
      ],
    );
    final (c, w, _) = await _make(world: many);
    await c.read(homeFeedProvider.future);
    w.posts.failWith = StateError('offline');
    await c.read(homeFeedProvider.notifier).loadMore();
    final s = c.read(homeFeedProvider).requireValue;
    expect(s.items, hasLength(20));
    expect(s.cursor, isNotNull);
    expect(s.loadingMore, isFalse);
  });

  test(
    'refresh reloads, and keeps the old feed when the reload fails',
    () async {
      final (c, w, _) = await _make();
      await c.read(homeFeedProvider.future);
      w.posts.add(
        fixturePost(
          'new',
          photographerId: 'p1',
          age: const Duration(seconds: 1),
        ),
      );
      await c.read(homeFeedProvider.notifier).refresh();
      expect(c.read(homeFeedProvider).requireValue.items.first.post.id, 'new');
      w.posts.failWith = StateError('offline');
      await c.read(homeFeedProvider.notifier).refresh();
      expect(c.read(homeFeedProvider).requireValue.items.first.post.id, 'new');
    },
  );

  test('a failing first load is an error state', () async {
    final w = DiscoveryWorld();
    w.posts.failWith = StateError('offline');
    final (c, _, _) = await _make(world: w);
    await expectLater(c.read(homeFeedProvider.future), throwsStateError);
  });

  test(
    'free this week lists photographers free in the next 7 days, soonest first',
    () async {
      final (c, _, _) = await _make();
      final list = await c.read(freeThisWeekProvider.future);
      expect(list.map((p) => p.id), ['p2', 'p1', 'p3']);
    },
  );

  test('real shoots are customer posts with their photographer', () async {
    final (c, _, _) = await _make();
    final list = await c.read(realShootsProvider.future);
    expect(list.map((f) => f.post.id), ['r1', 'r2']);
    expect(list.map((f) => f.photographer.displayName), [
      'Minh Trí',
      'Hồng Nhung',
    ]);
  });

  test('a category change while a page loads drops that page', () async {
    final many = DiscoveryWorld(
      posts: [
        for (var i = 0; i < 45; i++)
          fixturePost(
            'm$i',
            photographerId: 'p1',
            age: Duration(minutes: i + 1),
            specialtyId: i.isEven ? 'portrait' : 'wedding',
          ),
      ],
    );
    final (c, _, _) = await _make(world: many);
    await c.read(homeFeedProvider.future);
    final n = c.read(homeFeedProvider.notifier);
    final pending = n.loadMore();
    await n.selectCategory('wedding');
    await pending;
    final s = c.read(homeFeedProvider).requireValue;
    expect(s.category, 'wedding');
    expect(
      s.items.every((e) => e.post.specialtyId == 'wedding'),
      isTrue,
      reason: 'no portrait post from the earlier category page',
    );
  });

  test('signing out resets the feed to the first page of "for you"', () async {
    final (c, w, _) = await _make();
    await c.read(homeFeedProvider.future);
    await c.read(homeFeedProvider.notifier).selectCategory('wedding');
    await w.auth.signOut();
    await Future<void>.delayed(Duration.zero);
    final s = await c.read(homeFeedProvider.future);
    expect(s.category, isNull);
    expect(s.items, hasLength(5));
  });
}
