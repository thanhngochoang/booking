import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/firestore_special_days_repository.dart';
import 'package:photobooking/data/pricing/special_days.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreSpecialDayRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreSpecialDayRepository(db: db);
  });

  test('firestore special days repository maps from/to strings', () async {
    await repo.save(
      'p1',
      const SpecialDayRange(name: 'Tết', from: '2027-02-05', to: '2027-02-11'),
    );
    final docs = await db
        .collection('photographers')
        .doc('p1')
        .collection('special_days')
        .get();
    expect(docs.docs, hasLength(1));
    final d = docs.docs.single.data();
    expect(d['name'], 'Tết');
    expect(d['from'], '2027-02-05');
    expect(d['to'], '2027-02-11');
    expect(d['createdAt'], isNotNull);
    expect(d['updatedAt'], isNotNull);

    final id = docs.docs.single.id;
    final seen = await repo.watch('p1').first;
    expect(seen, [
      SpecialDayRange(
        id: id,
        name: 'Tết',
        from: '2027-02-05',
        to: '2027-02-11',
      ),
    ]);
  });

  test(
    'save with an id updates; delete removes; list is ordered by from',
    () async {
      await repo.save(
        'p1',
        const SpecialDayRange(name: 'B', from: '2027-03-01', to: '2027-03-02'),
      );
      await repo.save(
        'p1',
        const SpecialDayRange(name: 'A', from: '2027-01-01', to: '2027-01-02'),
      );
      var list = await repo.watch('p1').first;
      expect(list.map((r) => r.name), ['A', 'B']);
      await repo.save(
        'p1',
        SpecialDayRange(
          id: list[0].id,
          name: 'A2',
          from: '2027-01-01',
          to: '2027-01-03',
        ),
      );
      await repo.delete('p1', list[1].id);
      list = await repo.watch('p1').first;
      expect(list.map((r) => (r.name, r.to)), [('A2', '2027-01-03')]);
      expect(await repo.watch('p2').first, isEmpty);
    },
  );

  test('broken documents are dropped', () {
    expect(
      specialDayFromFirestore('x', {
        'name': 'N',
        'from': '2027-13-01',
        'to': '2027-01-02',
      }),
      isNull,
    );
    expect(
      specialDayFromFirestore('x', {'name': 'N', 'from': '2027-01-01'}),
      isNull,
    );
  });

  group('holidays', () {
    test('reads holidays/{year}; a missing year has none', () async {
      await db.collection('holidays').doc('2027').set({
        'days': [
          {'day': '2027-01-01', 'name': 'Tết Dương lịch'},
          {'day': 'bad', 'name': 'x'},
        ],
      });
      final h = FirestoreHolidayRepository(db: db);
      expect(await h.forYear(2027), [
        const Holiday(day: '2027-01-01', name: 'Tết Dương lịch'),
      ]);
      expect(await h.forYear(2030), isEmpty);
    });

    test('specialDaysOf prices a holiday and a range', () {
      final sd = specialDaysOf(
        const [Holiday(day: '2026-12-31', name: 'x')],
        const [
          SpecialDayRange(
            id: 'a',
            name: 'Tết',
            from: '2027-02-05',
            to: '2027-02-11',
          ),
        ],
      );
      const s = PricedService(price: 1000000, specialPrice: 2500000);
      expect(priceForDayKey(s, '2026-12-31', sd).kind, DayPriceKind.special);
      expect(priceForDayKey(s, '2027-02-11', sd).amount, 2500000);
      expect(
        priceForDayKey(s, '2027-02-12', sd).kind,
        isNot(DayPriceKind.special),
      );
    });
  });

  test('the fakes behave like the Firestore ones', () async {
    final fake = FakeSpecialDayRepository();
    await fake.save(
      'p1',
      const SpecialDayRange(name: 'B', from: '2027-03-01', to: '2027-03-02'),
    );
    await fake.save(
      'p1',
      const SpecialDayRange(name: 'A', from: '2027-01-01', to: '2027-01-02'),
    );
    expect((await fake.watch('p1').first).map((r) => r.name), ['A', 'B']);
    final id = fake.stored('p1').first.id;
    await fake.delete('p1', id);
    expect(fake.stored('p1').map((r) => r.name), ['B']);
    fake.failWrites = true;
    await expectLater(
      fake.save(
        'p1',
        const SpecialDayRange(name: 'C', from: '2027-05-01', to: '2027-05-01'),
      ),
      throwsStateError,
    );
    expect(await FakeHolidayRepository().forYear(2027), isEmpty);
  });
}
