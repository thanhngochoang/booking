import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/cached_photographer_repository.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';

import '../../support/content_fixtures.dart';

Future<void> _member(
  FakeFirebaseFirestore db,
  String uid,
  String? studioId,
  DateTime joinedAt,
) async {
  await db.collection('users').doc(uid).set({'displayName': 'Thợ $uid'});
  await db.collection('photographers').doc(uid).set({
    'onboardingComplete': true,
    'verified': true,
    'studioId': ?studioId,
    'studioJoinedAt': Timestamp.fromDate(joinedAt),
    'stats': {'tomatoCount': 9, 'brickCount': 1, 'tomatoPct': 90},
  });
}

void main() {
  group('membersOf', () {
    test(
      'membersOf queries studioId ordered by join date, limit 10, and builds summaries',
      () async {
        final db = FakeFirebaseFirestore();
        for (var i = 0; i < 12; i++) {
          await _member(db, 'm$i', 'cuc', DateTime.utc(2026, 9, 20 - i));
        }
        await _member(db, 'other', 'may', DateTime.utc(2026, 1, 1));
        await _member(db, 'solo', null, DateTime.utc(2026, 1, 1));

        final repo = FirestorePhotographerRepository(db: db);
        final members = await repo.membersOf('cuc');
        expect(members, hasLength(10));
        // Oldest member first: m11 joined on the 9th, m0 on the 20th.
        expect(members.first.id, 'm11');
        expect(members[1].id, 'm10');
        expect(members.first.displayName, 'Thợ m11');
        expect(members.first.tomatoPct, 90);
        expect(members.first.studioId, 'cuc');
        expect(members.every((m) => m.studioId == 'cuc'), isTrue);

        expect(await repo.membersOf('cuc', limit: 3), hasLength(3));
        expect(await repo.membersOf(''), isEmpty);
        expect(await repo.membersOf('a/b'), isEmpty);
      },
    );

    test('the fake and the cache answer membersOf too', () async {
      final fake = FakePhotographerRepository([
        fixturePhotographer('m1').copyWithStudio(studioId: 'cuc'),
        fixturePhotographer('m2').copyWithStudio(studioId: 'may'),
        fixturePhotographer('m3').copyWithStudio(studioId: 'cuc'),
      ]);
      expect((await fake.membersOf('cuc')).map((p) => p.id), ['m1', 'm3']);
      expect(await fake.membersOf('cuc', limit: 1), hasLength(1));
      final cached = CachedPhotographerRepository(
        fake,
        clock: () => DateTime.utc(2026, 10, 21),
      );
      expect((await cached.membersOf('cuc')).map((p) => p.id), ['m1', 'm3']);
    });
  });

  group('photographerSummaryFrom studio fields', () {
    test('PhotographerSummary carries studioId and memberCount', () {
      final member = photographerSummaryFrom(
        id: 'an',
        photographer: {'studioId': 'cuc', 'memberCount': 4},
      );
      expect(member.studioId, 'cuc');
      final studio = photographerSummaryFrom(
        id: 'cuc',
        photographer: {
          'providerType': 'studio',
          'memberCount': 4,
          'assignableMembers': 2,
        },
      );
      expect(studio.providerType, ProviderType.studio);
      expect(studio.memberCount, 4);
      expect(studio.assignableMembers, 2);
      expect(studio.studioId, isNull);
      expect(
        photographerSummaryFrom(id: 'x', photographer: {'studioId': ''}).studioId,
        isNull,
      );
    });

    test('a studio with no assignable member has no free day', () {
      Map<String, dynamic> studio(Map<String, dynamic> extra) => {
        'providerType': 'studio',
        'stats': {'nextFreeDate': '2026-10-22'},
        ...extra,
      };
      final none = photographerSummaryFrom(
        id: 'cuc',
        photographer: studio({'memberCount': 3, 'assignableMembers': 0}),
      );
      expect(none.hasNoAssignableMembers, isTrue);
      expect(none.nextFreeDate, isNull);

      // Absent count: fall back to the member count.
      final legacy = photographerSummaryFrom(
        id: 'cuc',
        photographer: studio({'memberCount': 2}),
      );
      expect(legacy.assignableMembers, isNull);
      expect(legacy.hasNoAssignableMembers, isFalse);
      expect(legacy.nextFreeDate, '2026-10-22');
      final empty = photographerSummaryFrom(
        id: 'cuc',
        photographer: studio({}),
      );
      expect(empty.hasNoAssignableMembers, isTrue);
      expect(empty.nextFreeDate, isNull);

      // Only studios read the field.
      final individual = photographerSummaryFrom(
        id: 'an',
        photographer: {
          'assignableMembers': 0,
          'stats': {'nextFreeDate': '2026-10-22'},
        },
      );
      expect(individual.assignableMembers, isNull);
      expect(individual.hasNoAssignableMembers, isFalse);
      expect(individual.nextFreeDate, '2026-10-22');
    });
  });
}

extension on PhotographerSummary {
  PhotographerSummary copyWithStudio({required String studioId}) =>
      PhotographerSummary(
        id: id,
        displayName: displayName,
        acceptingOrders: acceptingOrders,
        studioId: studioId,
      );
}
