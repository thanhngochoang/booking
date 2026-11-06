import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';

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

  test('failing writes throw and change nothing', () async {
    final repo = FakeServicePackageRepository(failWrites: true);
    await expectLater(repo.add('p1', _input), throwsStateError);
    expect(repo.stored('p1'), isEmpty);
  });

  final twoLevels = {
    for (final w in Weekday.values) w: w.isWeekend ? 1800000 : 1500000,
  };

  test('packageFromFirestore reads dayPrices and specialPrice', () {
    final p = packageFromFirestore('s1', {
      'name': 'Chân dung',
      'price': 1500000,
      'dayPrices': {for (final e in twoLevels.entries) e.key.name: e.value},
      'priceMode': 'per_day',
      'specialPrice': 2500000,
      'order': 3,
      'durationMinutes': 120,
    })!;
    expect(p.dayPrices, twoLevels);
    expect(p.specialPrice, 2500000);
    expect(p.priceMode, PriceMode.perDay);
    expect(p.order, 3);
    expect(p.price, 1500000);
    expect(priceSummary(p), isA<TwoLevelPrice>());
  });

  test('old documents read as one price in two-level mode', () {
    final p = packageFromFirestore('s1', {
      'name': 'X',
      'price': 100,
      'durationMinutes': 60,
    })!;
    expect(
      (p.dayPrices, p.specialPrice, p.priceMode, p.order),
      (null, null, PriceMode.twoLevels, null),
    );
    expect(priceSummary(p), isA<SinglePrice>());
  });

  test('a malformed dayPrices map is ignored', () {
    final p = packageFromFirestore('s1', {
      'name': 'X',
      'price': 100,
      'dayPrices': {'mon': 1},
    })!;
    expect(p.dayPrices, isNull);
  });

  test('packageToFirestore writes dayPrices, mode and specialPrice', () {
    final m = packageToFirestore(
      ServicePackageInput(
        name: 'Chân dung',
        priceVnd: 999,
        durationMinutes: 120,
        dayPrices: twoLevels,
        specialPrice: 2500000,
        priceMode: PriceMode.perDay,
        order: 2,
      ),
    );
    expect(m['price'], 1500000, reason: 'price is Monday');
    expect(m['dayPrices'], {
      for (final e in twoLevels.entries) e.key.name: e.value,
    });
    expect(m['priceMode'], 'per_day');
    expect(m['specialPrice'], 2500000);
    expect(m['order'], 2);
  });

  test('packageToFirestore drops dayPrices when all equal', () {
    final m = packageToFirestore(
      ServicePackageInput(
        name: 'A b',
        priceVnd: 5,
        durationMinutes: 60,
        dayPrices: {for (final w in Weekday.values) w: 1500000},
      ),
    );
    expect(m['price'], 1500000);
    expect(m.containsKey('dayPrices'), isFalse);
    expect(m.containsKey('priceMode'), isFalse);
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
