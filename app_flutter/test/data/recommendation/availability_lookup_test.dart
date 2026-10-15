import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/firestore_availability_lookup.dart';

void lookupContract(String name, Future<AvailabilityLookup> Function() create) {
  group('AvailabilityLookup contract: $name', () {
    test(
      'reports only the non-free states, for the asked day and ids',
      () async {
        final lookup = await create();
        final r = await lookup.on('2026-10-12', ['p1', 'p2', 'p3', 'p4']);
        expect(r, {
          'p1': DayAvailability.booked,
          'p2': DayAvailability.pending,
          'p3': DayAvailability.off,
        });
      },
    );

    test(
      'another day is free for everybody; no ids is an empty answer',
      () async {
        final lookup = await create();
        expect(await lookup.on('2026-10-13', ['p1', 'p2']), isEmpty);
        expect(await lookup.on('2026-10-12', const []), isEmpty);
      },
    );
  });
}

void main() {
  lookupContract('fake', () async {
    return FakeAvailabilityLookup()
      ..set('p1', '2026-10-12', DayAvailability.booked)
      ..set('p2', '2026-10-12', DayAvailability.pending)
      ..set('p3', '2026-10-12', DayAvailability.off)
      ..set('p4', '2026-10-14', DayAvailability.booked);
  });

  lookupContract('firestore', () async {
    final db = FakeFirebaseFirestore();
    Future<void> day(String uid, String key, String state) => db
        .collection('availability')
        .doc(uid)
        .collection('days')
        .doc(key)
        .set({'state': state});
    await day('p1', '2026-10-12', 'booked');
    await day('p2', '2026-10-12', 'pending');
    await day('p3', '2026-10-12', 'off');
    await day('p4', '2026-10-14', 'booked');
    return FirestoreAvailabilityLookup(db: db);
  });

  test('the fake records what was asked, and can fail', () async {
    final fake = FakeAvailabilityLookup();
    await fake.on('2026-10-12', ['a', 'b']);
    expect(fake.requested, [
      ['a', 'b'],
    ]);
    fake.failWith = StateError('offline');
    expect(() => fake.on('2026-10-12', ['a']), throwsStateError);
  });

  test('an unknown state in the database is treated as booked', () async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('availability')
        .doc('p1')
        .collection('days')
        .doc('2026-10-12')
        .set({'state': 'weird'});
    final r = await FirestoreAvailabilityLookup(db: db)
        .on('2026-10-12', ['p1']);
    expect(r['p1'], DayAvailability.booked);
  });

  test('duplicate ids are read once', () async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('availability')
        .doc('p1')
        .collection('days')
        .doc('2026-10-12')
        .set({'state': 'off'});
    final r = await FirestoreAvailabilityLookup(db: db)
        .on('2026-10-12', ['p1', 'p1']);
    expect(r, {'p1': DayAvailability.off});
  });
}
