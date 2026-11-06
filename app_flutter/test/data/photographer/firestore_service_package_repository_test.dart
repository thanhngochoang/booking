import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/firestore_service_package_repository.dart';
import 'package:photobooking/data/photographer/service_package.dart';

/// A package as the first version of day pricing (#326) left it: the new
/// rules refuse any write that leaves one of the old price fields on it.
const _legacy = {
  'dayPrices': {
    'mon': 1500000,
    'tue': 1500000,
    'wed': 1500000,
    'thu': 1500000,
    'fri': 1500000,
    'sat': 1800000,
    'sun': 1800000,
  },
  'specialPrice': 2200000,
  'priceMode': 'per_day',
  'occasionPrices': {'tet': 3000000},
};

const _legacyKeys = [
  'dayPrices',
  'specialPrice',
  'priceMode',
  'occasionPrices',
];

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreServicePackageRepository repo;

  Future<void> seedLegacy(String id, {int order = 0}) => db
      .collection('photographers')
      .doc('u1')
      .collection('services')
      .doc(id)
      .set({
        'name': 'Chân dung',
        'price': 1500000,
        'durationMinutes': 120,
        'deliverables': {'editedCount': 40, 'deliveryDays': 3},
        'active': true,
        'order': order,
        ..._legacy,
      });

  Future<Map<String, dynamic>> read(String id) async =>
      (await db
              .collection('photographers')
              .doc('u1')
              .collection('services')
              .doc(id)
              .get())
          .data()!;

  void expectClean(Map<String, dynamic> d) {
    for (final k in _legacyKeys) {
      expect(d.containsKey(k), isFalse, reason: '$k is deleted');
    }
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreServicePackageRepository(db: db);
  });

  test(
    'update writes the price and deletes the four old price fields',
    () async {
      await seedLegacy('a', order: 4);
      await repo.update(
        'u1',
        'a',
        const ServicePackageInput(
          name: 'Chân dung 2 giờ',
          priceVnd: 1600000,
          durationMinutes: 120,
          editedCount: 40,
          deliveryDays: 3,
        ),
      );
      final d = await read('a');
      expectClean(d);
      expect(d['price'], 1600000);
      expect(d['name'], 'Chân dung 2 giờ');
      expect(d['order'], 4, reason: 'an edit keeps the place in the list');
      expect(d['active'], true);
      expect(d['updatedAt'], isNotNull);
    },
  );

  test('setActive shows or hides and deletes the old price fields', () async {
    await seedLegacy('a');
    await repo.setActive('u1', 'a', false);
    var d = await read('a');
    expectClean(d);
    expect(d['active'], false);
    expect(d['price'], 1500000);

    await seedLegacy('a');
    await repo.hide('u1', 'a');
    d = await read('a');
    expectClean(d);
    expect(d['active'], false);

    await seedLegacy('a');
    await repo.setActive('u1', 'a', true);
    d = await read('a');
    expectClean(d);
    expect(d['active'], true);
  });

  test('reorder writes order 0..n-1 in one batch and deletes the old price '
      'fields of every package', () async {
    await seedLegacy('a', order: 0);
    await seedLegacy('b', order: 1);
    await seedLegacy('c', order: 2);
    await repo.reorder('u1', ['c', 'a', 'b']);
    for (final e in {'c': 0, 'a': 1, 'b': 2}.entries) {
      final d = await read(e.key);
      expectClean(d);
      expect(d['order'], e.value, reason: e.key);
      expect(d['price'], 1500000);
    }
  });

  test('a package without old fields is written the same way', () async {
    await db
        .collection('photographers')
        .doc('u1')
        .collection('services')
        .doc('a')
        .set({
          'name': 'X',
          'price': 100,
          'durationMinutes': 60,
          'active': true,
        });
    await repo.setActive('u1', 'a', false);
    final d = await read('a');
    expectClean(d);
    expect(d['active'], false);
  });

  test('add writes the new shape and no old price field', () async {
    final p = await repo.add(
      'u1',
      const ServicePackageInput(
        name: 'Cặp đôi',
        priceVnd: 3200000,
        durationMinutes: 240,
        editedCount: 80,
      ),
    );
    final d = await read(p.id);
    expectClean(d);
    expect(d['price'], 3200000);
    expect(d['active'], true);
    expect(d['deliverables'], {'editedCount': 80});
  });

  test('watchMine reads packages that still carry old fields', () async {
    await seedLegacy('a');
    final list = await repo.watchMine('u1').first;
    expect(list.single.priceVnd, 1500000);
    expect(list.single.name, 'Chân dung');
  });
}
