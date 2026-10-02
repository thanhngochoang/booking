// test/features/skills/own_posts_controller_test.dart
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

  test(
    'a failed next page keeps what is shown and is not retried by scrolling',
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
      w.posts.failWith = StateError('offline');
      await c.read(ownPostsProvider.notifier).loadMore();
      await c.read(ownPostsProvider.notifier).loadMore();
      final s = c.read(ownPostsProvider).requireValue;
      expect(s.posts, hasLength(30));
      expect(s.loadingMore, isFalse);
    },
  );

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
    },
  );
}
