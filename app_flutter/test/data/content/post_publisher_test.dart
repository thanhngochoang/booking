// test/data/content/post_publisher_test.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/firestore_post_publisher.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/post_summary.dart';

import '../../support/content_fixtures.dart';

PostDraft draft({
  String id = '01J9ZZZZZZZZZZZZZZZZZZZZZZ',
  String caption = 'Chiều muộn ở bến Bạch Đằng #ChanDung #phoco',
  String? location = 'Bến Bạch Đằng',
  String? style = 'natural_light',
  String? specialty = 'portrait',
  bool portfolio = true,
  int images = 2,
}) => PostDraft(
  id: id,
  photographerId: 'p1',
  serviceId: 's1',
  specialtyId: specialty,
  images: [
    for (var i = 0; i < images; i++)
      PostImage(url: 'https://storage.test/posts/p1/$id/$i.jpg'),
  ],
  caption: caption,
  locationName: location,
  styleId: style,
  inPortfolio: portfolio,
);

typedef Env = ({PostPublisher publisher, PostRepository reader});

void postPublisherContract(String name, Future<Env> Function() create) {
  group('PostPublisher contract: $name', () {
    late Env env;
    setUp(() async => env = await create());

    test(
      'the published post can be read back with everything that was entered',
      () async {
        final made = await env.publisher.publish(draft());
        expect(made.id, '01J9ZZZZZZZZZZZZZZZZZZZZZZ');
        final read = (await env.reader.byId(made.id))!;
        expect(read.kind, PostKind.work);
        expect(read.authorId, 'p1');
        expect(read.photographerId, 'p1');
        expect(read.serviceId, 's1');
        expect(read.specialtyId, 'portrait');
        expect(read.styleId, 'natural_light');
        expect(read.locationName, 'Bến Bạch Đằng');
        expect(read.caption, 'Chiều muộn ở bến Bạch Đằng #ChanDung #phoco');
        expect(read.hashtags, ['chandung', 'phoco']);
        expect(read.images.map((i) => i.url), [
          'https://storage.test/posts/p1/01J9ZZZZZZZZZZZZZZZZZZZZZZ/0.jpg',
          'https://storage.test/posts/p1/01J9ZZZZZZZZZZZZZZZZZZZZZZ/1.jpg',
        ]);
        expect(read.inPortfolio, isTrue);
        expect((read.likeCount, read.saveCount), (0, 0));
      },
    );

    test('the new post is the first of the feed', () async {
      await env.publisher.publish(draft(id: '01J9AAAAAAAAAAAAAAAAAAAAAA'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await env.publisher.publish(draft(id: '01J9BBBBBBBBBBBBBBBBBBBBBB'));
      final feed = await env.reader.feed();
      expect(feed.posts.first.id, '01J9BBBBBBBBBBBBBBBBBBBBBB');
    });

    test('publishing the same draft twice leaves one post', () async {
      await env.publisher.publish(draft());
      await env.publisher.publish(draft(caption: 'Đã sửa lỗi chính tả'));
      final feed = await env.reader.feed();
      expect(feed.posts, hasLength(1));
      expect(feed.posts.single.caption, 'Đã sửa lỗi chính tả');
    });

    test('optional fields may be absent', () async {
      final made = await env.publisher.publish(
        draft(
          location: null,
          style: null,
          specialty: null,
          portfolio: false,
          images: 1,
        ),
      );
      final read = (await env.reader.byId(made.id))!;
      expect(
        (read.locationName, read.styleId, read.specialtyId),
        (null, null, null),
      );
      expect(read.inPortfolio, isFalse);
      expect(read.images, hasLength(1));
    });
  });
}

void main() {
  postPublisherContract('fake', () async {
    final posts = FakePostRepository();
    return (
      publisher: FakePostPublisher(
        posts: posts,
        clock: () => DateTime.now().toUtc(),
      ),
      reader: posts,
    );
  });

  postPublisherContract('firestore', () async {
    final db = FakeFirebaseFirestore();
    return (
      publisher: FirestorePostPublisher(db: db),
      reader: FirestorePostRepository(db: db),
    );
  });

  group('FakePostPublisher', () {
    test('records drafts, fails on demand and stores nothing then', () async {
      final posts = FakePostRepository();
      final pub = FakePostPublisher(posts: posts, clock: () => fixtureNow);
      final made = await pub.publish(draft());
      expect(made.createdAt, fixtureNow);
      expect(pub.published.single.id, made.id);
      pub.failWith = StateError('offline');
      await expectLater(
        pub.publish(draft(id: '01J9CCCCCCCCCCCCCCCCCCCCCC')),
        throwsStateError,
      );
      expect((await posts.feed()).posts, hasLength(1));
    });
  });

  group('FirestorePostPublisher documents', () {
    test(
      'writes the shape the rules expect and no counters but zero',
      () async {
        final db = FakeFirebaseFirestore();
        await FirestorePostPublisher(db: db).publish(draft());
        final d =
            (await db
                    .collection('posts')
                    .doc('01J9ZZZZZZZZZZZZZZZZZZZZZZ')
                    .get())
                .data()!;
        expect(d.keys.toSet(), {
          'kind',
          'authorId',
          'photographerId',
          'serviceId',
          'specialty',
          'imageUrls',
          'imageMeta',
          'caption',
          'location',
          'style',
          'hashtags',
          'inPortfolio',
          'likeCount',
          'saveCount',
          'createdAt',
        });
        expect(d['kind'], 'work');
        expect((d['likeCount'], d['saveCount']), (0, 0));
        expect(d['createdAt'], isA<Timestamp>());
        expect((d['imageMeta'] as List), hasLength(2));
        expect(d['location'], {'name': 'Bến Bạch Đằng'});
      },
    );

    test('the portfolio gets the post id, even when the photographer document is new', () async {
      final db = FakeFirebaseFirestore();
      final pub = FirestorePostPublisher(db: db);
      await pub.publish(draft(id: '01J9AAAAAAAAAAAAAAAAAAAAAA'));
      await pub.publish(draft(id: '01J9BBBBBBBBBBBBBBBBBBBBBB'));
      final p = (await db.collection('photographers').doc('p1').get()).data()!;
      expect(p['portfolio'], [
        '01J9AAAAAAAAAAAAAAAAAAAAAA',
        '01J9BBBBBBBBBBBBBBBBBBBBBB',
      ]);
    });

    test('a post kept out of the portfolio does not touch the photographer document', () async {
      final db = FakeFirebaseFirestore();
      await FirestorePostPublisher(db: db).publish(draft(portfolio: false));
      expect(
        (await db.collection('photographers').doc('p1').get()).exists,
        isFalse,
      );
    });

    test('a failed commit whose post already exists reports success', () async {
      final db = FakeFirebaseFirestore();
      await FirestorePostPublisher(db: db).publish(draft());
      final retry = FirestorePostPublisher(
        db: db,
        commit: (_) async => throw TimeoutException('offline'),
      );
      final made = await retry.publish(draft());
      expect(made.id, '01J9ZZZZZZZZZZZZZZZZZZZZZZ');
    });

    test('a failed commit with no post rethrows the commit error', () async {
      final pub = FirestorePostPublisher(
        db: FakeFirebaseFirestore(),
        commit: (_) async => throw TimeoutException('offline'),
      );
      await expectLater(pub.publish(draft()), throwsA(isA<TimeoutException>()));
    });

    test(
      'the commit has a deadline so an offline phone does not wait forever',
      () {
        final src = File('lib/data/content/firestore_post_publisher.dart')
            .readAsStringSync();
        expect(src, contains('.timeout('));
        expect(src, contains('Duration(seconds: 20)'));
      },
    );
  });
}
