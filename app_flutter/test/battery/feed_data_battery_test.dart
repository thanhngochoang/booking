// test/battery/feed_data_battery_test.dart
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';

import '../data/content/firestore_photographer_repository_test.dart'
    show seedPhotographer, seedService;
import '../data/content/firestore_post_repository_test.dart' show seededDb;
import '../support/content_fixtures.dart';

void main() {
  test('the data layer opens no listener and runs no timer', () {
    for (final f in Directory(
      'lib/data/content',
    ).listSync().whereType<File>()) {
      final src = f.readAsStringSync();
      expect(src, isNot(contains('.snapshots(')), reason: f.path);
      expect(src, isNot(contains('Timer.periodic')), reason: f.path);
      expect(src, isNot(contains('StreamController')), reason: f.path);
    }
    final ports = File('lib/data/content/content_repositories.dart')
        .readAsStringSync();
    expect(ports, isNot(contains('Stream<')));
  });

  test('a huge page request is clamped to 50 posts', () async {
    final posts = [
      for (var i = 0; i < 80; i++)
        fixturePost('m$i', age: Duration(minutes: i + 1)),
    ];
    final repo = FirestorePostRepository(db: await seededDb(posts));
    expect((await repo.feed(limit: 100000)).posts, hasLength(50));
    expect(
      (await repo.byPhotographer('p1', limit: 100000)).posts,
      hasLength(50),
    );
  });

  test('candidates are capped at 200 and free-this-week at 50', () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 230; i++) {
      await seedPhotographer(
        db,
        fixturePhotographer('c$i', nextFreeDate: '2026-10-03'),
      );
    }
    final repo = FirestorePhotographerRepository(db: db);
    expect(await repo.candidates(limit: 100000), hasLength(200));
    expect(
      await repo.freeThisWeek(now: fixtureNow, limit: 100000),
      hasLength(50),
    );
  });

  test("a photographer's service list is capped at 50", () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 70; i++) {
      await seedService(db, fixtureService('s$i'));
    }
    expect(
      await FirestoreServiceRepository(db: db).activeFor('p1'),
      hasLength(50),
    );
  });

  test('a like is one document write and an undo one delete', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreEngagementRepository(db: db);
    await repo.setLiked('u1', 'a', true);
    expect((await db.collection('likes').get()).docs, hasLength(1));
    await repo.setLiked('u1', 'a', false);
    expect((await db.collection('likes').get()).docs, isEmpty);
  });
}
