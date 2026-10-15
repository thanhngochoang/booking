// test/data/content/fake_post_repository_by_author_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';
import 'package:photobooking/data/content/post_summary.dart';

import '../../support/content_fixtures.dart';
import 'firestore_post_repository_test.dart' show seededDb;

/// u1: w1 (newest), r1, w2, e1, e2, w3 (oldest); u2: x1, x2.
List<PostSummary> _seed() => [
  fixturePost('w1', authorId: 'u1', age: const Duration(hours: 1)),
  fixturePost(
    'r1',
    kind: PostKind.realShoot,
    authorId: 'u1',
    age: const Duration(hours: 2),
  ),
  fixturePost('w2', authorId: 'u1', age: const Duration(hours: 3)),
  fixturePost(
    'e1',
    kind: PostKind.eventShare,
    photographerId: '',
    serviceId: '',
    authorId: 'u1',
    eventId: 'ev1',
    age: const Duration(hours: 4),
  ),
  fixturePost(
    'e2',
    kind: PostKind.eventShare,
    photographerId: '',
    serviceId: '',
    authorId: 'u1',
    eventId: 'ev1',
    age: const Duration(hours: 5),
  ),
  fixturePost('w3', authorId: 'u1', age: const Duration(hours: 6)),
  fixturePost('x1', authorId: 'u2', age: const Duration(minutes: 30)),
  fixturePost(
    'x2',
    kind: PostKind.realShoot,
    authorId: 'u2',
    age: const Duration(hours: 7),
  ),
];

void _byAuthorTests(String name, Future<PostRepository> Function() create) {
  group('byAuthor / countByAuthor: $name', () {
    List<String> ids(PostPage p) => p.posts.map((e) => e.id).toList();

    test("byAuthor returns only u1's posts newest first", () async {
      final repo = await create();
      expect(ids(await repo.byAuthor('u1')), [
        'w1',
        'r1',
        'w2',
        'e1',
        'e2',
        'w3',
      ]);
    });

    test('byAuthor with kind returns only that kind', () async {
      final repo = await create();
      expect(ids(await repo.byAuthor('u1', kind: PostKind.work)), [
        'w1',
        'w2',
        'w3',
      ]);
      expect(ids(await repo.byAuthor('u1', kind: PostKind.eventShare)), [
        'e1',
        'e2',
      ]);
      expect(ids(await repo.byAuthor('u1', kind: PostKind.realShoot)), ['r1']);
    });

    test('byAuthor pages by cursor with the feed rules', () async {
      final repo = await create();
      final p1 = await repo.byAuthor('u1', limit: 2);
      expect(ids(p1), ['w1', 'r1']);
      expect(p1.nextCursor, isNotNull);
      final p2 = await repo.byAuthor('u1', limit: 2, cursor: p1.nextCursor);
      expect(ids(p2), ['w2', 'e1']);
      expect(p2.nextCursor, isNotNull);
      final p3 = await repo.byAuthor('u1', limit: 2, cursor: p2.nextCursor);
      expect(ids(p3), ['e2', 'w3']);
      expect(p3.nextCursor, isNull);
    });

    test('countByAuthor counts all and per kind', () async {
      final repo = await create();
      expect(await repo.countByAuthor('u1'), 6);
      expect(await repo.countByAuthor('u1', kind: PostKind.work), 3);
      expect(await repo.countByAuthor('u1', kind: PostKind.realShoot), 1);
      expect(await repo.countByAuthor('u1', kind: PostKind.eventShare), 2);
      expect(await repo.countByAuthor('nobody'), 0);
    });

    test("an id with '/' yields an empty page and 0", () async {
      final repo = await create();
      final page = await repo.byAuthor('u1/x');
      expect(page.posts, isEmpty);
      expect(page.nextCursor, isNull);
      expect(await repo.countByAuthor('u1/x'), 0);
      expect(await repo.countByAuthor(''), 0);
    });
  });
}

void main() {
  _byAuthorTests('fake', () async => FakePostRepository(_seed()));
  _byAuthorTests('firestore', () async {
    final FakeFirebaseFirestore db = await seededDb(_seed());
    return FirestorePostRepository(db: db);
  });

  test('the fake throws failWith from byAuthor and countByAuthor', () async {
    final repo = FakePostRepository(_seed())..failWith = StateError('offline');
    expect(() => repo.byAuthor('u1'), throwsStateError);
    expect(() => repo.countByAuthor('u1'), throwsStateError);
  });
}
