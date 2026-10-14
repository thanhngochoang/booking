import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/saved_follow.dart';

import '../../support/content_fixtures.dart';

void main() {
  group('cursor helpers', () {
    test('markerCursor round-trips and a malformed cursor reads as no cursor', () {
      final now = DateTime.utc(2026, 10, 1, 12, 0, 0);
      const docId = 'user1_post1';
      final cursor = markerCursor(now, docId);
      final parsed = parseMarkerCursor(cursor);

      expect(parsed, isNotNull);
      expect(parsed!.$1, now);
      expect(parsed.$2, docId);

      expect(parseMarkerCursor(null), isNull);
      expect(parseMarkerCursor(''), isNull);
      expect(parseMarkerCursor('not_a_valid_cursor'), isNull);
      expect(parseMarkerCursor('_docOnly'), isNull);
      expect(parseMarkerCursor('12345_'), isNull);
      expect(parseMarkerCursor('invalidMillis_doc'), isNull);
    });

    test('keepOrder keeps marker order and drops missing targets', () {
      final ids = ['p1', 'p2', 'p3', 'p4'];
      final found = {'p3': 'three', 'p1': 'one'};
      final ordered = keepOrder(ids, found);
      expect(ordered, ['one', 'three']);
    });
  });

  group('FakeSavedFollowRepository', () {
    test('followers maps display name, avatar and since', () async {
      final repo = FakeSavedFollowRepository(
        userDirectory: {
          'u1': (displayName: 'Lan Anh', avatarUrl: 'https://img/u1.jpg'),
          'u2': (displayName: 'Minh', avatarUrl: null),
        },
      );
      final t1 = DateTime.utc(2026, 10, 1, 10, 0);
      final t2 = DateTime.utc(2026, 10, 2, 10, 0);
      repo.addFollow('u1', 'p1', t1);
      repo.addFollow('u2', 'p1', t2);

      final page = await repo.followers('p1');
      expect(page.items.length, 2);
      expect(page.items[0].displayName, 'Minh'); // t2 is newer
      expect(page.items[0].avatarUrl, isNull);
      expect(page.items[0].since, t2);

      expect(page.items[1].displayName, 'Lan Anh');
      expect(page.items[1].avatarUrl, 'https://img/u1.jpg');
      expect(page.items[1].since, t1);
    });

    test('counts sums saved posts and saved photographers', () async {
      final repo = FakeSavedFollowRepository();
      repo.addFollow('u1', 'p1', DateTime.now().toUtc());
      repo.addFollow('u1', 'p2', DateTime.now().toUtc());
      repo.addSavedPost('u1', 'post1', DateTime.now().toUtc());
      repo.addSavedPhotographer('u1', 'p1', DateTime.now().toUtc());

      final c = await repo.counts('u1');
      expect(c.following, 2);
      expect(c.savedPosts, 1);
      expect(c.savedPhotographers, 1);
      expect(c.saved, 2);
    });

    test('setPhotographerSaved writes then removes the marker', () async {
      final repo = FakeSavedFollowRepository();
      expect(await repo.isPhotographerSaved('u1', 'p1'), isFalse);

      await repo.setPhotographerSaved('u1', 'p1', true);
      expect(await repo.isPhotographerSaved('u1', 'p1'), isTrue);

      await repo.setPhotographerSaved('u1', 'p1', false);
      expect(await repo.isPhotographerSaved('u1', 'p1'), isFalse);
    });

    test('savedPhotographers drops profiles that are not published', () async {
      final p1 = fixturePhotographer('p1'); // published
      final p2 = const PhotographerSummary(
        id: 'p2',
        displayName: '', // unpublished / missing user
        avatarUrl: '',
        coverUrl: '',
        reviewCount: 0,
      );
      final photoRepo = FakePhotographerRepository([p1, p2]);
      final repo = FakeSavedFollowRepository(photographerRepo: photoRepo);

      repo.addSavedPhotographer('u1', 'p1', DateTime.utc(2026, 10, 1));
      repo.addSavedPhotographer('u1', 'p2', DateTime.utc(2026, 10, 2));

      final page = await repo.savedPhotographers('u1');
      expect(page.items.length, 1);
      expect(page.items.first.id, 'p1');
    });
  });
}
