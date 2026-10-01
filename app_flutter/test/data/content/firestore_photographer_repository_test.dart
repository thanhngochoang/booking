// test/data/content/firestore_photographer_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

import '../../support/content_fixtures.dart';
import 'content_contracts.dart';

Future<void> seedPhotographer(
  FakeFirebaseFirestore db,
  PhotographerSummary p, {
  bool complete = true,
}) async {
  await db.collection('users').doc(p.id).set({
    'displayName': p.displayName,
    if (p.avatarUrl != null) 'avatarUrl': p.avatarUrl,
  });
  await db.collection('photographers').doc(p.id).set({
    'onboardingComplete': complete,
    'verified': p.verified,
    'specialties': p.specialtyIds,
    'styles': p.styleIds,
    if (p.coverUrl != null) 'coverUrl': p.coverUrl,
    'serviceArea': {
      'city': p.areaLabel,
      if (p.hasGeo) 'center': GeoPoint(p.lat!, p.lng!),
      'radiusKm': 20,
    },
    'stats': {
      'rating': p.ratingAvg,
      'reviewCount': p.reviewCount,
      'completedCount': p.completedCount,
      if (p.responseMinutes != null) 'responseMinutes': p.responseMinutes,
      if (p.nextFreeDate != null) 'nextFreeDate': p.nextFreeDate,
    },
    if (p.startingPriceVnd != null) 'startingPrice': p.startingPriceVnd,
    if (p.createdAt != null) 'createdAt': Timestamp.fromDate(p.createdAt!),
  });
}

Future<void> seedService(FakeFirebaseFirestore db, ServiceSummary s) => db
    .collection('photographers')
    .doc(s.photographerId)
    .collection('services')
    .doc(s.id)
    .set({
      'name': s.name,
      if (s.specialtyId != null) 'specialty': s.specialtyId,
      'price': s.priceVnd,
      'durationMinutes': s.durationMinutes,
      'deliverables': {
        'photoCount': s.photoCount,
        'editedCount': s.editedCount,
        'deliveryDays': s.deliveryDays,
      },
      'active': s.active,
    });

void main() {
  photographerRepositoryContract('firestore', (seed) async {
    final db = FakeFirebaseFirestore();
    for (final p in seed) {
      await seedPhotographer(db, p);
    }
    return FirestorePhotographerRepository(db: db);
  });

  serviceRepositoryContract('firestore', (seed) async {
    final db = FakeFirebaseFirestore();
    for (final s in seed) {
      await seedService(db, s);
    }
    return FirestoreServiceRepository(db: db);
  });

  group('photographerSummaryFrom', () {
    test('takes the name from users and the rest from photographers', () {
      final p = photographerSummaryFrom(
        id: 'p1',
        user: {
          'displayName': 'Minh Trí',
          'avatarUrl': 'https://img.test/a.jpg',
        },
        photographer: {
          'verified': true,
          'coverUrl': 'https://img.test/c.jpg',
          'specialties': ['family'],
          'skills': {
            'specialties': [
              {'id': 'wedding', 'level': 3},
              {'id': 'portrait', 'level': 2},
            ],
            'styles': ['film'],
          },
          'styles': ['minimal'],
          'serviceArea': {
            'city': 'Quận 3',
            'center': const GeoPoint(10.78, 106.68),
          },
          'stats': {
            'rating': 4,
            'reviewCount': 12.0,
            'completedCount': 30,
            'responseMinutes': 45,
            'nextFreeDate': '2026-10-05',
          },
          'startingPrice': 2000000,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
        },
      );
      expect(p.displayName, 'Minh Trí');
      expect(p.avatarUrl, 'https://img.test/a.jpg');
      expect(p.verified, isTrue);
      expect(p.specialtyIds, [
        'wedding',
        'portrait',
      ], reason: 'skills win over the flat list');
      expect(p.styleIds, ['film']);
      expect(p.areaLabel, 'Quận 3');
      expect((p.lat, p.lng), (10.78, 106.68));
      expect(p.ratingAvg, 4.0);
      expect(p.reviewCount, 12);
      expect(p.startingPriceVnd, 2000000);
      expect(p.createdAt, DateTime.utc(2026, 1, 2));
    });

    test(
      'falls back to the legacy serviceArea.geo when there is no center',
      () {
        final p = photographerSummaryFrom(
          id: 'p3',
          photographer: {
            'serviceArea': {'city': 'Q1', 'geo': const GeoPoint(10.5, 106.5)},
          },
        );
        expect((p.lat, p.lng), (10.5, 106.5));
      },
    );

    test('falls back to the flat specialties and survives a bare document', () {
      final p = photographerSummaryFrom(
        id: 'p2',
        user: null,
        photographer: {
          'specialties': ['family', 'couple'],
          'styles': ['minimal'],
        },
      );
      expect(p.styleIds, ['minimal']);
      expect(p.displayName, '');
      expect(p.specialtyIds, ['family', 'couple']);
      expect(p.hasGeo, isFalse);
      expect(p.hasRating, isFalse);
      expect(p.verified, isFalse);
      expect(p.nextFreeDate, isNull);
    });
  });

  group('serviceFromFirestore', () {
    test('maps deliverables and defaults to active', () {
      final s = serviceFromFirestore('s1', 'p1', {
        'name': 'Cưới cả ngày',
        'specialty': 'wedding',
        'price': 8000000,
        'durationMinutes': 480,
        'deliverables': {
          'photoCount': 300,
          'editedCount': 120,
          'deliveryDays': 14,
        },
        'coverUrl': 'https://img.test/s.jpg',
      })!;
      expect(
        (s.name, s.priceVnd, s.durationMinutes),
        ('Cưới cả ngày', 8000000, 480),
      );
      expect((s.photoCount, s.editedCount, s.deliveryDays), (300, 120, 14));
      expect(s.active, isTrue);
      expect(s.photographerId, 'p1');
    });

    test('rejects a service without a name or with a non-positive price', () {
      expect(serviceFromFirestore('s', 'p', {'price': 1}), isNull);
      expect(serviceFromFirestore('s', 'p', {'name': 'x', 'price': 0}), isNull);
      expect(serviceFromFirestore('s', 'p', {'name': 'x'}), isNull);
    });
  });

  group('FirestorePhotographerRepository', () {
    test('summaries ignores empty and slash ids', () async {
      final db = FakeFirebaseFirestore();
      await seedPhotographer(db, fixturePhotographer('p1'));
      final m = await FirestorePhotographerRepository(db: db)
          .summaries(['', 'a/b', 'p1']);
      expect(m.keys, ['p1']);
    });

    test(
      'candidates and free-this-week only list published photographers',
      () async {
        final db = FakeFirebaseFirestore();
        await seedPhotographer(
          db,
          fixturePhotographer('p1', nextFreeDate: '2026-10-02'),
        );
        await seedPhotographer(
          db,
          fixturePhotographer('hidden', nextFreeDate: '2026-10-02'),
          complete: false,
        );
        final repo = FirestorePhotographerRepository(db: db);
        expect((await repo.candidates()).map((p) => p.id), ['p1']);
        expect((await repo.freeThisWeek(now: fixtureNow)).map((p) => p.id), [
          'p1',
        ]);
      },
    );

    test('summaries still resolve an unpublished author (their old posts keep a name)', () async {
      final db = FakeFirebaseFirestore();
      await seedPhotographer(
        db,
        fixturePhotographer('old', name: 'Cũ'),
        complete: false,
      );
      final m = await FirestorePhotographerRepository(db: db)
          .summaries(['old']);
      expect(m['old']!.displayName, 'Cũ');
    });

    test('a photographer document without a user document gets an empty name, not a crash', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('p9').set({
        'onboardingComplete': true,
      });
      final m = await FirestorePhotographerRepository(db: db).summaries(['p9']);
      expect(m['p9']!.displayName, '');
    });
  });
}
