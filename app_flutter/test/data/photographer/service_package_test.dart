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

  test('failing writes throw and change nothing', () async {
    final repo = FakeServicePackageRepository(failWrites: true);
    await expectLater(repo.add('p1', _input), throwsStateError);
    expect(repo.stored('p1'), isEmpty);
  });
}
