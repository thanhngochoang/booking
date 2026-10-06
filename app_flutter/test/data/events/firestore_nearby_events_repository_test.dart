import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/firestore_nearby_events_repository.dart';

import '../../support/event_world.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreNearbyEventsRepository repo;

  // Ho Chi Minh City centre and Hà Nội: far apart, different cells.
  const hcm = (10.78, 106.70);
  const hanoi = (21.03, 105.85);

  Future<void> seed(
    String id, {
    (double, double) at = hcm,
    String status = 'open',
    Duration startsIn = const Duration(days: 3),
    Duration createdAgo = const Duration(days: 1),
  }) => db
      .collection('events')
      .doc(id)
      .set(
        eventDoc(
          status: status,
          lat: at.$1,
          lng: at.$2,
          startAt: eventNow.add(startsIn),
          createdAt: eventNow.subtract(createdAgo),
        ),
      );

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreNearbyEventsRepository(db: db, pageSize: 3);
  });

  final hcmCell = encodeGeohash(hcm.$1, hcm.$2, precision: 4);
  final hanoiCell = encodeGeohash(hanoi.$1, hanoi.$2, precision: 4);

  test('inCells reads every page of each cell', () async {
    for (var i = 0; i < 8; i++) {
      await seed('h$i', startsIn: Duration(days: i + 1));
    }
    await seed('hn', at: hanoi);
    final got = await repo.inCells([hcmCell], from: eventNow, limit: 2);
    expect(got.map((e) => e.id), [for (var i = 0; i < 8; i++) 'h$i']);
    final both = await repo.inCells([hcmCell, hanoiCell], from: eventNow);
    expect(both, hasLength(9));
    expect((await repo.inCells([hanoiCell], from: eventNow)).map((e) => e.id), [
      'hn',
    ]);
  });

  test('inCells keeps only public events from the given time', () async {
    await seed('ok');
    await seed('full', status: 'full', startsIn: const Duration(days: 4));
    await seed('draft', status: 'draft');
    await seed('closed', status: 'closed');
    await seed('past', startsIn: const Duration(days: -1));
    expect((await repo.inCells([hcmCell], from: eventNow)).map((e) => e.id), [
      'ok',
      'full',
    ]);
  });

  test('upcoming filters status and from', () async {
    await seed('b', startsIn: const Duration(days: 5));
    await seed('a', startsIn: const Duration(days: 1));
    await seed('c', at: hanoi, startsIn: const Duration(days: 3));
    await seed('draft', status: 'draft');
    await seed('cancelled', status: 'cancelled');
    await seed('past', startsIn: const Duration(days: -2));
    expect((await repo.upcoming(from: eventNow)).map((e) => e.id), [
      'a',
      'c',
      'b',
    ]);
    expect((await repo.upcoming(from: eventNow, limit: 2)).map((e) => e.id), [
      'a',
      'c',
    ]);
  });

  test('countCreatedSince caps', () async {
    for (var i = 0; i < 6; i++) {
      await seed('h$i');
    }
    await seed('hn', at: hanoi);
    await seed('draft', status: 'draft');
    expect(await repo.countCreatedSince(cap: 4), 4);
    expect(await repo.countCreatedSince(), 7);
    expect(await repo.countCreatedSince(cap: 100), 7);
    expect(await repo.countCreatedSince(cells: [hcmCell], cap: 10), 6);
    expect(await repo.countCreatedSince(cells: [hcmCell], cap: 3), 3);
    expect(await repo.countCreatedSince(cells: [hcmCell, hanoiCell]), 7);
  });

  test('countCreatedSince counts only events created after since', () async {
    await seed('new', createdAgo: const Duration(hours: 1));
    await seed('old', createdAgo: const Duration(days: 9));
    final since = eventNow.subtract(const Duration(days: 2));
    expect(await repo.countCreatedSince(since: since), 1);
    expect(await repo.countCreatedSince(cells: [hcmCell], since: since), 1);
    expect(await repo.countCreatedSince(cells: [hanoiCell], since: since), 0);
  });
}
