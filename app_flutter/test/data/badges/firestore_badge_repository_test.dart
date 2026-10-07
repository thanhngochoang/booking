import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/badges/badge.dart';
import 'package:photobooking/data/badges/badge_providers.dart';
import 'package:photobooking/data/badges/badge_repository.dart';
import 'package:photobooking/data/badges/badges_seen_store.dart';
import 'package:photobooking/data/badges/firestore_badge_repository.dart';

BadgeDefinition def(String id, int order, {String? shortName}) =>
    BadgeDefinition(
      id: id,
      name: 'Tên $id',
      shortName: shortName,
      description: 'Mô tả $id',
      icon: 'favorite',
      source: BadgeSource.system,
      audience: 'both',
      order: order,
      hiddenWhenLocked: false,
      hasProgress: false,
    );

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreBadgeRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreBadgeRepository(db: db);
  });

  test('a badge doc parses; missing shortName is null', () async {
    await db.collection('badges').doc('top_rated').set({
      'name': 'Được đánh giá cao',
      'description': 'Từ 4,8 sao với ít nhất 20 đánh giá',
      'icon': 'favorite',
      'source': 'review',
      'audience': 'photographer',
      'order': 10,
      'hiddenWhenLocked': false,
      'progress': 'minSample',
    });
    await db.collection('badges').doc('new_member').set({
      'name': 'Thành viên mới',
      'shortName': 'Mới',
      'description': '30 ngày đầu trên app',
      'icon': 'celebration',
      'source': 'system',
      'audience': 'both',
      'order': 40,
      'hiddenWhenLocked': true,
      'progress': 'none',
    });
    await db.collection('badges').doc('broken').set({'order': 1});

    final cat = await repo.catalog();
    expect(cat.map((b) => b.id), ['top_rated', 'new_member']);
    final top = cat.first;
    expect(top.shortName, isNull);
    expect(top.label, 'Được đánh giá cao');
    expect(top.source, BadgeSource.review);
    expect(top.hasProgress, isTrue);
    expect(top.hiddenWhenLocked, isFalse);
    final member = cat.last;
    expect(member.label, 'Mới');
    expect(member.hasProgress, isFalse);
    expect(member.hiddenWhenLocked, isTrue);
  });

  test('earned badges parse with the snapshot text', () async {
    final at = DateTime.utc(2026, 9, 1);
    final col = db.collection('users').doc('u1').collection('badges');
    await col.doc('top_rated').set({
      'badgeId': 'top_rated',
      'uid': 'u1',
      'awardedAt': Timestamp.fromDate(at),
      'snapshot': {'text': '4,9 sao từ 58 đánh giá'},
    });
    await col.doc('punctual').set({
      'badgeId': 'punctual',
      'uid': 'u1',
      'awardedAt': Timestamp.fromDate(at),
    });
    final earned = await repo.watchEarned('u1').first;
    final byId = {for (final e in earned) e.badgeId: e};
    expect(byId['top_rated']!.snapshotText, '4,9 sao từ 58 đánh giá');
    expect(byId['top_rated']!.awardedAt, at);
    expect(byId['punctual']!.snapshotText, isNull);
  });

  test('progress doc entries parse', () async {
    final doc = db
        .collection('users')
        .doc('u1')
        .collection('private')
        .doc('badgeProgress');
    expect(await repo.watchProgress('u1').first, isEmpty);
    await doc.set({
      'entries': {
        'top_rated': {'current': 12, 'target': 20},
        'shoots_50': {'current': 9.0, 'target': 50},
        'bad': {'current': 'x'},
      },
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
    });
    final p = await repo.watchProgress('u1').first;
    expect(p.keys, {'top_rated', 'shoots_50'});
    expect(p['top_rated']!.current, 12);
    expect(p['top_rated']!.target, 20);
    expect(p['shoots_50']!.current, 9);
  });

  test('badgeChips orders by catalogue order and uses shortName', () async {
    final fake = FakeBadgeRepository(
      catalog: [
        def('c', 30),
        def('a', 10, shortName: 'A ngắn'),
        def('b', 20),
        def('locked', 40),
      ],
      earned: {
        'u1': [
          EarnedBadge(badgeId: 'c', awardedAt: DateTime.utc(2026, 1, 1)),
          EarnedBadge(badgeId: 'a', awardedAt: DateTime.utc(2026, 2, 1)),
        ],
      },
    );
    final c = ProviderContainer(
      overrides: [badgeRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(badgeChipsProvider('u1'), (_, _) {});
    expect(sub.read().isLoading, isTrue);
    await c.read(badgeCatalogProvider.future);
    await c.read(earnedBadgesProvider('u1').future);
    final chips = c.read(badgeChipsProvider('u1')).requireValue;
    expect(chips.map((b) => b.name), ['A ngắn', 'Tên c']);
    expect(chips.every((b) => b.earned), isTrue);
    expect(chips.first.code, 'favorite');
    // The catalogue is read once and cached.
    c.read(badgeChipsProvider('u2'));
    await c.read(badgeCatalogProvider.future);
    expect(fake.catalogReads, 1);
  });

  test('BadgesSeenStore keeps seenAt per uid', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BadgesSeenStore(await SharedPreferences.getInstance());
    expect(store.seenAt('u1'), isNull);
    final at = DateTime.utc(2026, 10, 6, 8);
    await store.markSeen('u1', at);
    expect(store.seenAt('u1'), at);
    expect(store.seenAt('u2'), isNull);
  });
}
