import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';

import '../../support/content_fixtures.dart';

void main() {
  group('saved posts paging', () {
    test('savedPosts returns newest saved first and a cursor only when more follow', () async {
      final posts = [
        fixturePost('post1'),
        fixturePost('post2'),
        fixturePost('post3'),
      ];
      final postRepo = FakePostRepository(posts);
      final repo = FakeSavedFollowRepository(postRepo: postRepo);

      final t1 = DateTime.utc(2026, 10, 1, 10, 0);
      final t2 = DateTime.utc(2026, 10, 1, 11, 0);
      final t3 = DateTime.utc(2026, 10, 1, 12, 0);

      repo.addSavedPost('u1', 'post1', t1);
      repo.addSavedPost('u1', 'post2', t2);
      repo.addSavedPost('u1', 'post3', t3);

      final page1 = await repo.savedPosts('u1', limit: 2);
      expect(page1.items.length, 2);
      expect(page1.items[0].id, 'post3');
      expect(page1.items[1].id, 'post2');
      expect(page1.cursor, isNotNull);

      final page2 = await repo.savedPosts('u1', cursor: page1.cursor, limit: 2);
      expect(page2.items.length, 1);
      expect(page2.items[0].id, 'post1');
      expect(page2.cursor, isNull);
    });

    test('a page whose targets are all gone loads the next page', () async {
      // 30 deleted posts, then 2 live posts
      final livePosts = [
        fixturePost('live1'),
        fixturePost('live2'),
      ];
      final postRepo = FakePostRepository(livePosts);
      final repo = FakeSavedFollowRepository(postRepo: postRepo);

      for (var i = 1; i <= 30; i++) {
        repo.addSavedPost(
          'u1',
          'deleted_$i',
          DateTime.utc(2026, 10, 1, 10, 0).add(Duration(minutes: 100 - i)),
        );
      }
      repo.addSavedPost('u1', 'live1', DateTime.utc(2026, 10, 1, 5, 0));
      repo.addSavedPost('u1', 'live2', DateTime.utc(2026, 10, 1, 4, 0));

      final page = await repo.savedPosts('u1', limit: 30);
      expect(page.items.length, 2);
      expect(page.items[0].id, 'live1');
      expect(page.items[1].id, 'live2');
    });

    test('look-ahead stops after 3 extra pages', () async {
      // 150 deleted posts, no live posts
      final postRepo = FakePostRepository([]);
      final repo = FakeSavedFollowRepository(postRepo: postRepo);

      for (var i = 1; i <= 150; i++) {
        repo.addSavedPost(
          'u1',
          'deleted_$i',
          DateTime.utc(2026, 10, 1, 10, 0).add(Duration(minutes: 200 - i)),
        );
      }

      final page = await repo.savedPosts('u1', limit: 30);
      expect(page.items, isEmpty);
      // It stopped after max rounds and returns a cursor to continue from
      expect(page.cursor, isNotNull);
    });
  });
}
