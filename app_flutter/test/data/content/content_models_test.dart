import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/reason.dart';

import '../../support/content_fixtures.dart';

void main() {
  group('Reason', () {
    test('codes round-trip and unknown codes are null', () {
      for (final c in ReasonCode.values) {
        expect(ReasonCode.fromCode(c.code), c);
      }
      expect(ReasonCode.skillMatch.code, 'skill_match');
      expect(ReasonCode.freeOnDate.code, 'free_on_date');
      expect(ReasonCode.fromCode('???'), isNull);
      expect(ReasonCode.fromCode(null), isNull);
    });

    test('has value equality', () {
      expect(
        const Reason(code: ReasonCode.near, text: '1,2 km'),
        const Reason(code: ReasonCode.near, text: '1,2 km'),
      );
      expect(
        const Reason(code: ReasonCode.near, text: '1,2 km'),
        isNot(const Reason(code: ReasonCode.near, text: '2 km')),
      );
    });
  });

  group('PhotographerSummary', () {
    test('rating, geo, hero and next free day', () {
      final p = fixturePhotographer('p1', nextFreeDate: '2026-10-03');
      expect(p.hasRating, isTrue);
      expect(p.hasGeo, isTrue);
      expect(p.heroUrl, p.avatarUrl, reason: 'no cover: the avatar stands in');
      expect(p.nextFreeDay, DateTime.utc(2026, 10, 3));
    });

    test('a new photographer has no rating, no geo and no free day', () {
      const p = PhotographerSummary(id: 'p9', displayName: 'Mới');
      expect(p.hasRating, isFalse);
      expect(p.hasGeo, isFalse);
      expect(p.heroUrl, isNull);
      expect(p.nextFreeDay, isNull);
    });

    test('a cover wins over the avatar; a malformed day is ignored', () {
      final p = fixturePhotographer(
        'p1',
        coverUrl: 'https://img.test/c.jpg',
        nextFreeDate: '12/10',
      );
      expect(p.heroUrl, 'https://img.test/c.jpg');
      expect(p.nextFreeDay, isNull);
    });
  });

  group('PostSummary', () {
    test('kind codes round-trip; unknown becomes work', () {
      expect(PostKind.fromCode('real_shoot'), PostKind.realShoot);
      expect(PostKind.fromCode('event_share'), PostKind.eventShare);
      expect(PostKind.realShoot.code, 'real_shoot');
      expect(PostKind.fromCode('???'), PostKind.work);
      expect(PostKind.fromCode(null), PostKind.work);
    });

    test('the cover is the first image', () {
      final p = fixturePost('a', images: 3);
      expect(p.images, hasLength(3));
      expect(p.cover.url, 'https://img.test/a-0.jpg');
    });

    test('an empty page has no cursor', () {
      const page = PostPage();
      expect(page.posts, isEmpty);
      expect(page.nextCursor, isNull);
    });
  });
}
