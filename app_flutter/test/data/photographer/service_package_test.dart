import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/service_package.dart';

const _input = ServicePackageInput(
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  editedCount: 40,
  deliveryDays: 3,
);

void main() {
  test('writes the document shape the discovery read model expects', () {
    expect(packageToFirestore(_input), {
      'name': 'Chân dung 2 giờ',
      'price': 1500000,
      'durationMinutes': 120,
      'deliverables': {'editedCount': 40, 'deliveryDays': 3},
    });
    expect(
      packageToFirestore(
        const ServicePackageInput(
          name: 'A b',
          priceVnd: 1,
          durationMinutes: 60,
        ),
      ),
      {
        'name': 'A b',
        'price': 1,
        'durationMinutes': 60,
        'deliverables': <String, dynamic>{},
      },
    );
  });

  test(
    'reads packages back, hidden ones included; broken ones are dropped',
    () {
      expect(
        packageFromFirestore('s1', {
          ...packageToFirestore(_input),
          'active': false,
        }),
        const ServicePackage(
          id: 's1',
          name: 'Chân dung 2 giờ',
          priceVnd: 1500000,
          durationMinutes: 120,
          editedCount: 40,
          deliveryDays: 3,
          active: false,
        ),
      );
      expect(
        packageFromFirestore('s2', {
          'name': 'X',
          'price': 0,
          'durationMinutes': 60,
        }),
        isNull,
      );
      expect(
        packageFromFirestore('s3', {
          'name': 'X',
          'price': 1.5,
          'durationMinutes': 60,
        }),
        isNull,
      );
      expect(
        packageFromFirestore('s4', {'price': 100, 'durationMinutes': 60}),
        isNull,
      );
      expect(
        packageFromFirestore('s5', {
          'name': 'X',
          'price': 100,
        })!.durationMinutes,
        60,
        reason: 'old documents without a duration default to one hour',
      );
    },
  );

  test('the fake adds, updates and hides in creation order', () async {
    final repo = FakeServicePackageRepository();
    final lists = <List<ServicePackage>>[];
    final sub = repo.watchMine('p1').listen(lists.add);
    final a = await repo.add('p1', _input);
    final b = await repo.add(
      'p1',
      const ServicePackageInput(
        name: 'Cặp đôi',
        priceVnd: 3200000,
        durationMinutes: 240,
      ),
    );
    await repo.update(
      'p1',
      a.id,
      const ServicePackageInput(
        name: 'Chân dung',
        priceVnd: 1800000,
        durationMinutes: 120,
      ),
    );
    await repo.hide('p1', b.id);
    await Future<void>.delayed(Duration.zero);
    expect(lists.last.map((p) => (p.name, p.priceVnd, p.active)), [
      ('Chân dung', 1800000, true),
      ('Cặp đôi', 3200000, false),
    ]);
    expect(repo.watchers, 1);
    await sub.cancel();
    expect(repo.watchers, 0);
    expect(repo.stored('p2'), isEmpty);
  });

  test('the fake shows a hidden package again with setActive', () async {
    final repo = FakeServicePackageRepository();
    final a = await repo.add('p1', _input);
    await repo.hide('p1', a.id);
    expect(repo.stored('p1').single.active, isFalse);
    await repo.setActive('p1', a.id, true);
    expect(repo.stored('p1').single.active, isTrue);
  });

  test('failing writes throw and change nothing', () async {
    final repo = FakeServicePackageRepository(failWrites: true);
    await expectLater(repo.add('p1', _input), throwsStateError);
    expect(repo.stored('p1'), isEmpty);
  });

  test('packageFromFirestore reads the order and ignores old price fields', () {
    final p = packageFromFirestore('s1', {
      'name': 'Chân dung',
      'price': 1500000,
      // Written by the first version of day pricing (#326).
      'dayPrices': {
        'mon': 1500000,
        'tue': 1500000,
        'wed': 1500000,
        'thu': 1500000,
        'fri': 1500000,
        'sat': 1800000,
        'sun': 1800000,
      },
      'priceMode': 'per_day',
      'specialPrice': 2500000,
      'occasionPrices': {'tet': 3000000},
      'order': 3,
      'durationMinutes': 120,
    })!;
    expect(p.order, 3);
    expect(p.priceVnd, 1500000);
    expect(
      p,
      const ServicePackage(
        id: 's1',
        name: 'Chân dung',
        priceVnd: 1500000,
        durationMinutes: 120,
        order: 3,
      ),
    );
  });

  test('packageToFirestore writes the price and the order, nothing else '
      'about price', () {
    final m = packageToFirestore(
      const ServicePackageInput(
        name: 'Chân dung',
        priceVnd: 1500000,
        durationMinutes: 120,
        order: 2,
      ),
    );
    expect(m, {
      'name': 'Chân dung',
      'price': 1500000,
      'order': 2,
      'durationMinutes': 120,
      'deliverables': <String, dynamic>{},
    });
  });

  test('the legacy price fields are the four the new rules refuse', () {
    expect(kLegacyPackagePriceFields, [
      'dayPrices',
      'specialPrice',
      'priceMode',
      'occasionPrices',
    ]);
  });

  test('the fake reorders to order 0..n-1 and lists by it', () async {
    final repo = FakeServicePackageRepository();
    final a = await repo.add('p1', _input);
    final b = await repo.add(
      'p1',
      const ServicePackageInput(
        name: 'Cặp đôi',
        priceVnd: 3200000,
        durationMinutes: 240,
      ),
    );
    final c = await repo.add(
      'p1',
      const ServicePackageInput(
        name: 'Gia đình',
        priceVnd: 1,
        durationMinutes: 60,
      ),
    );
    await repo.reorder('p1', [c.id, a.id, b.id]);
    expect(repo.stored('p1').map((p) => (p.id, p.order)), [
      (c.id, 0),
      (a.id, 1),
      (b.id, 2),
    ]);
    await repo.update('p1', a.id, _input);
    expect(
      repo.stored('p1').firstWhere((p) => p.id == a.id).order,
      1,
      reason: 'an edit keeps the position',
    );
    await expectLater(repo.reorder('p1', ['nope']), throwsStateError);
  });
}
