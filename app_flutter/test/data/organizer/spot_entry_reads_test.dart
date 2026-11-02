import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/spots/firestore_spot_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

Timestamp _ts(String iso) => Timestamp.fromDate(DateTime.parse(iso));

Map<String, dynamic> _entry({
  required String spotId,
  String status = 'open',
  String type = 'entry',
}) => {
  'title': 'Vé vào cửa',
  'type': type,
  'status': status,
  'spotId': spotId,
  'host': {'type': 'organizer', 'id': 'org1', 'name': 'Bãi đá'},
  'startAt': _ts('2026-10-31T17:00:00Z'),
  'endAt': _ts('2026-11-30T17:00:00Z'),
  'openHours': {'start': '07:00', 'end': '18:00'},
  'ticketTypes': [
    {'id': 't1', 'name': 'Người lớn', 'price': 70000, 'hidden': false},
  ],
  'dailyCapacity': null,
  'refundCutoffHours': 48,
  'createdAt': _ts('2026-10-20T00:00:00Z'),
};

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreSpotRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreSpotRepository(db: db, functions: _MockFunctions());
  });

  test('watchEntryEvent queries events(type entry, spotId, status in [open, full])', () async {
    await db
        .collection('events')
        .doc('draft')
        .set(_entry(spotId: 's1', status: 'draft'));
    await db.collection('events').doc('other').set(_entry(spotId: 's2'));
    await db
        .collection('events')
        .doc('walk')
        .set(_entry(spotId: 's1', type: 'photo_walk'));
    expect(await repo.watchEntryEvent('s1').first, isNull);

    await db
        .collection('events')
        .doc('e1')
        .set(_entry(spotId: 's1', status: 'full'));
    final e = await repo.watchEntryEvent('s1').first;
    expect(e!.id, 'e1');
    expect(e.organizerId, 'org1');
  });

  test('watchResidents lists spots/{id}/residents, valid ones only', () async {
    final col = db.collection('spots').doc('s1').collection('residents');
    await col.doc('p1').set({
      'waivesProvider': true,
      'waivesGuests': false,
      'validUntil': null,
      'addedAt': _ts('2026-10-20T00:00:00Z'),
      'addedBy': 'org1',
    });
    await col.doc('p2').set({
      'waivesProvider': true,
      'waivesGuests': true,
      'validUntil': '2026-10-01',
      'addedAt': _ts('2026-09-20T00:00:00Z'),
      'addedBy': 'org1',
    });
    final all = await repo.watchResidents('s1').first;
    expect(all.map((r) => r.providerId).toSet(), {'p1', 'p2'});
  });

  test('eventsAt leaves entry events out (Decision 11)', () async {
    final now = DateTime.now().toUtc();
    final at = Timestamp.fromDate(now.add(const Duration(days: 3)));
    await db.collection('events').doc('w1').set({
      'title': 'Dạo phố',
      'type': 'photo_walk',
      'status': 'open',
      'spotId': 's1',
      'startAt': at,
      'price': 0,
    });
    await db.collection('events').doc('e1').set({
      ..._entry(spotId: 's1'),
      'startAt': at,
    });
    final events = await repo.eventsAt('s1');
    expect(events.map((e) => e.id), ['w1']);
  });
}
