// test/data/content/firestore_post_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';
import 'package:photobooking/data/content/post_summary.dart';

import '../../support/content_fixtures.dart';
import 'content_contracts.dart';

Map<String, dynamic> postDoc(PostSummary p) => {
  'kind': p.kind.code,
  'authorId': p.authorId,
  'photographerId': p.photographerId,
  'serviceId': p.serviceId,
  if (p.bookingId != null) 'bookingId': p.bookingId,
  'imageUrls': [for (final i in p.images) i.url],
  'imageMeta': [
    for (final i in p.images)
      {'blurHash': i.blurHash, 'w': i.width, 'h': i.height},
  ],
  'caption': p.caption,
  if (p.locationName != null) 'location': {'name': p.locationName},
  if (p.styleId != null) 'style': p.styleId,
  if (p.specialtyId != null) 'specialty': p.specialtyId,
  'hashtags': p.hashtags,
  'inPortfolio': p.inPortfolio,
  'likeCount': p.likeCount,
  'saveCount': p.saveCount,
  'createdAt': Timestamp.fromDate(p.createdAt),
};

Future<FakeFirebaseFirestore> seededDb(List<PostSummary> posts) async {
  final db = FakeFirebaseFirestore();
  for (final p in posts) {
    await db.collection('posts').doc(p.id).set(postDoc(p));
  }
  return db;
}

void main() {
  postRepositoryContract('firestore', (seed) async {
    return FirestorePostRepository(db: await seededDb(seed));
  });
  engagementContract('firestore', () async {
    return FirestoreEngagementRepository(db: FakeFirebaseFirestore());
  });

  group('postFromFirestore', () {
    final full = {
      'kind': 'real_shoot',
      'authorId': 'u9',
      'photographerId': 'p1',
      'serviceId': 's1',
      'bookingId': 'b1',
      'imageUrls': ['https://img.test/1.jpg', 'https://img.test/2.jpg'],
      'imageMeta': [
        {'blurHash': 'LEHV6nWB2yk8', 'w': 800, 'h': 1000},
      ],
      'caption': 'Cảm ơn Minh Trí',
      'location': {'name': 'Bến Bạch Đằng', 'geohash': 'w3gv'},
      'style': 'natural_light',
      'specialty': 'portrait',
      'hashtags': ['chandung'],
      'inPortfolio': true,
      'likeCount': 214,
      'saveCount': 37.0,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 30, 10)),
    };

    test('maps every field, tolerating numbers and short imageMeta', () {
      final p = postFromFirestore('x', full)!;
      expect(p.kind, PostKind.realShoot);
      expect(p.authorId, 'u9');
      expect(p.bookingId, 'b1');
      expect(p.images, hasLength(2));
      expect(p.images[0].blurHash, 'LEHV6nWB2yk8');
      expect(p.images[0].width, 800);
      expect(p.images[1].blurHash, isNull);
      expect(p.locationName, 'Bến Bạch Đằng');
      expect(p.styleId, 'natural_light');
      expect(p.specialtyId, 'portrait');
      expect(p.hashtags, ['chandung']);
      expect(p.likeCount, 214);
      expect(p.saveCount, 37);
      expect(p.createdAt, DateTime.utc(2026, 9, 30, 10));
      expect(p.createdAt.isUtc, isTrue);
    });

    test('defaults: kind work, author = photographer, zero counters', () {
      final p = postFromFirestore('y', {
        'photographerId': 'p1',
        'serviceId': 's1',
        'imageUrls': ['https://img.test/1.jpg'],
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 30)),
      })!;
      expect(p.kind, PostKind.work);
      expect(p.authorId, 'p1');
      expect(p.likeCount, 0);
      expect(p.caption, '');
      expect(p.hashtags, isEmpty);
    });

    test('a pending server timestamp reads as "now", not a crash', () {
      final before = DateTime.now().toUtc();
      final p = postFromFirestore('z', {...full, 'createdAt': null})!;
      expect(
        p.createdAt.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('malformed or deleted posts are skipped', () {
      expect(postFromFirestore('a', {...full, 'photographerId': null}), isNull);
      expect(postFromFirestore('b', {...full, 'serviceId': null}), isNull);
      expect(
        postFromFirestore('c', {...full, 'imageUrls': <String>[]}),
        isNull,
      );
      expect(
        postFromFirestore('d', {...full, 'deletedAt': Timestamp.now()}),
        isNull,
      );
    });
  });

  group('FirestorePostRepository', () {
    test(
      'deleted posts never show up in the feed, the profile or by id',
      () async {
        final db = await seededDb(contractPosts());
        await db.collection('posts').doc('a').update({
          'deletedAt': Timestamp.now(),
        });
        final repo = FirestorePostRepository(db: db);
        expect((await repo.feed()).posts.map((p) => p.id), [
          'b',
          'c',
          'd',
          'e',
        ]);
        expect((await repo.byPhotographer('p1')).posts.map((p) => p.id), [
          'b',
          'c',
          'e',
        ]);
        expect(await repo.byId('a'), isNull);
      },
    );

    test('a malformed document is skipped without breaking the page', () async {
      final db = await seededDb(contractPosts());
      await db.collection('posts').doc('broken').set({
        'photographerId': 'p1',
        'createdAt': Timestamp.fromDate(fixtureNow),
      });
      final repo = FirestorePostRepository(db: db);
      expect((await repo.feed()).posts.map((p) => p.id), [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]);
    });

    test('a cursor that no longer exists gives an empty page', () async {
      final repo = FirestorePostRepository(db: await seededDb(contractPosts()));
      final page = await repo.feed(limit: 2, cursor: 'vanished');
      expect(page.posts, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('a post without images is skipped, not shown', () async {
      final db = await seededDb(contractPosts());
      await db.collection('posts').doc('a').update({
        'imageUrls': <String>[],
        'imageMeta': <Map<String, dynamic>>[],
      });
      final repo = FirestorePostRepository(db: db);
      expect((await repo.feed()).posts.map((p) => p.id), ['b', 'c', 'd', 'e']);
    });
  });

  group('FirestoreEngagementRepository documents', () {
    test(
      'write the documents the rules expect, and delete them on undo',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = FirestoreEngagementRepository(db: db);
        await repo.setLiked('u1', 'a', true);
        await repo.setSaved('u1', 'a', true);
        await repo.setFollowing('u1', 'p1', true);
        final like = await db.collection('likes').doc('u1_a').get();
        expect(like.data()!['userId'], 'u1');
        expect(like.data()!['postId'], 'a');
        expect(like.data()!.containsKey('createdAt'), isTrue);
        expect((await db.collection('saves').doc('u1_a').get()).exists, isTrue);
        final follow = await db.collection('follows').doc('u1_p1').get();
        expect(follow.data()!['photographerId'], 'p1');
        await repo.setLiked('u1', 'a', false);
        expect(
          (await db.collection('likes').doc('u1_a').get()).exists,
          isFalse,
        );
      },
    );

    test('setters write only the viewer\'s marker, never a counter', () async {
      final db = await seededDb(contractPosts());
      await db.collection('photographers').doc('p1').set({'followerCount': 7});
      final repo = FirestoreEngagementRepository(db: db);
      await repo.setLiked('u1', 'a', true);
      await repo.setSaved('u1', 'a', true);
      await repo.setFollowing('u1', 'p1', true);
      await repo.setLiked('u1', 'a', false);
      await repo.setLiked('u1', 'a', false);
      final post = (await db.collection('posts').doc('a').get()).data()!;
      expect(post['likeCount'], 3);
      expect(post['saveCount'], 0);
      final p1 = (await db.collection('photographers').doc('p1').get()).data()!;
      expect(p1['followerCount'], 7);
      expect(p1.keys, ['followerCount']);
      final touched = {
        for (final c in ['posts', 'photographers', 'likes', 'saves', 'follows'])
          c: (await db.collection(c).get()).docs.map((d) => d.id).toSet(),
      };
      expect(touched['likes'], isEmpty);
      expect(touched['saves'], {'u1_a'});
      expect(touched['follows'], {'u1_p1'});
      expect(touched['posts'], {'a', 'b', 'c', 'd', 'e'});
      expect(touched['photographers'], {'p1'});
    });
  });
}
