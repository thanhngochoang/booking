// test/data/discovery/firestore_explore_catalog_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/discovery/explore_catalog.dart';
import 'package:photobooking/data/discovery/firestore_explore_catalog_repository.dart';

void main() {
  group('FirestoreExploreCatalogRepository', () {
    test('reads counts and covers', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('catalog').doc('explore').set({
        'specialties': {
          'portrait': {
            'serviceCount': 5,
            'coverUrl': 'https://img.test/p.jpg',
          },
          'wedding': {
            'serviceCount': 2,
            'coverUrl': null,
          },
        },
      });

      final repo = FirestoreExploreCatalogRepository(db: db);
      final catalog = await repo.load();

      expect(catalog.specialties.length, 2);
      expect(
        catalog['portrait'],
        const ExploreCategoryStat(
          serviceCount: 5,
          coverUrl: 'https://img.test/p.jpg',
        ),
      );
      expect(
        catalog['wedding'],
        const ExploreCategoryStat(serviceCount: 2, coverUrl: null),
      );
      expect(catalog['unknown'], isNull);
    });

    test('a missing document is empty', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreExploreCatalogRepository(db: db);
      final catalog = await repo.load();

      expect(catalog, ExploreCatalog.empty);
    });

    test('malformed entries are skipped (negative count, non-string cover)', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('catalog').doc('explore').set({
        'specialties': {
          'valid': {
            'serviceCount': 3,
            'coverUrl': 'https://img.test/v.jpg',
          },
          'negative': {
            'serviceCount': -1,
            'coverUrl': 'https://img.test/n.jpg',
          },
          'badCountType': {
            'serviceCount': 'not-a-number',
            'coverUrl': 'https://img.test/b.jpg',
          },
          'badCoverType': {
            'serviceCount': 2,
            'coverUrl': 12345, // non-string cover becomes null
          },
          'emptyKey': {
            'serviceCount': 1,
          },
          '': {
            'serviceCount': 10,
          },
        },
      });

      final repo = FirestoreExploreCatalogRepository(db: db);
      final catalog = await repo.load();

      expect(catalog.specialties.containsKey('negative'), isFalse);
      expect(catalog.specialties.containsKey('badCountType'), isFalse);
      expect(catalog.specialties.containsKey(''), isFalse);

      expect(catalog['valid']?.serviceCount, 3);
      expect(catalog['badCoverType']?.serviceCount, 2);
      expect(catalog['badCoverType']?.coverUrl, isNull);
    });
  });
}
