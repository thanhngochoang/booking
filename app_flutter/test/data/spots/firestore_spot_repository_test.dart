// test/data/spots/firestore_spot_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/spots/firestore_spot_repository.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}
class _MockCallable extends Mock implements HttpsCallable {}
class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreSpotRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreSpotRepository(db: db, functions: functions);
  });

  group('FirestoreSpotRepository', () {
    test('hot reads spot_rankings/{key} and falls back to all when missing', () async {
      await db.collection('spot_rankings').doc('hn').set({
        'entries': [
          {'spotId': 's_hn', 'name': 'Hồ Tây', 'areaCode': 'hn'},
        ],
      });
      await db.collection('spot_rankings').doc('all').set({
        'entries': [
          {'spotId': 's_all', 'name': 'Toàn quốc', 'areaCode': 'all'},
        ],
      });

      final hnEntries = await repo.hot('hn');
      expect(hnEntries.length, 1);
      expect(hnEntries.first.spotId, 's_hn');

      // Missing key falls back to 'all'
      final fallback = await repo.hot('missing_key');
      expect(fallback.length, 1);
      expect(fallback.first.spotId, 's_all');
    });

    test('directory reads spot_directory/all', () async {
      await db.collection('spot_directory').doc('all').set({
        'entries': [
          {'spotId': 's1', 'name': 'Spot 1'},
          {'spotId': 's2', 'name': 'Spot 2'},
        ],
      });

      final dir = await repo.directory();
      expect(dir.length, 2);
      expect(dir[0].spotId, 's1');
      expect(dir[1].spotId, 's2');
    });

    test('openSchedulesAt queries spotId and status open', () async {
      await db.collection('spot_schedules').doc('sch_open').set({
        'spotId': 's1',
        'providerId': 'p1',
        'window': {'start': '06:00', 'end': '11:00'},
        'days': ['2026-10-10'],
        'status': 'open',
      });
      await db.collection('spot_schedules').doc('sch_cancelled').set({
        'spotId': 's1',
        'providerId': 'p1',
        'window': {'start': '06:00', 'end': '11:00'},
        'days': ['2026-10-10'],
        'status': 'cancelled',
      });
      await db.collection('spot_schedules').doc('sch_other_spot').set({
        'spotId': 's2',
        'providerId': 'p1',
        'window': {'start': '06:00', 'end': '11:00'},
        'days': ['2026-10-10'],
        'status': 'open',
      });

      final list = await repo.openSchedulesAt('s1');
      expect(list.length, 1);
      expect(list.first.id, 'sch_open');
    });

    test('spotDay reads spot_days/{scheduleId}_{day}', () async {
      await db.collection('spot_days').doc('sch_1_2026-10-10').set({
        'scheduleId': 'sch_1',
        'day': '2026-10-10',
        'taken': [
          {'start': '06:00', 'end': '06:30', 'offerId': 'off_1'},
        ],
      });

      final day = await repo.spotDay('sch_1', '2026-10-10');
      expect(day, isNotNull);
      expect(day?.scheduleId, 'sch_1');
      expect(day?.day, '2026-10-10');
      expect(day?.taken.length, 1);
      expect(day?.taken.first.offerId, 'off_1');
    });

    test('postsAt orders by createdAt desc, 20 per page, startAfter before', () async {
      final now = DateTime.utc(2026, 10, 8, 12);
      for (var i = 1; i <= 25; i++) {
        await db.collection('posts').doc('post_$i').set({
          'spotId': 's1',
          'photographerId': 'p1',
          'serviceId': 'srv1',
          'imageUrls': ['https://test/$i.jpg'],
          'createdAt': Timestamp.fromDate(now.subtract(Duration(hours: 30 - i))),
        });
      }

      final page1 = await repo.postsAt('s1', limit: 20);
      expect(page1.length, 20);
      expect(page1.first.id, 'post_25'); // newest first

      final lastDate = page1.last.createdAt;
      final page2 = await repo.postsAt('s1', before: lastDate, limit: 20);
      expect(page2.length, 5);
      expect(page2.first.id, 'post_5');
    });

    test('eventsAt filters open|full and startAt ≥ now', () async {
      final now = DateTime.now();
      await db.collection('events').doc('ev_future_open').set({
        'spotId': 's1',
        'title': 'Event Open',
        'status': 'open',
        'startAt': Timestamp.fromDate(now.add(const Duration(days: 2))),
      });
      await db.collection('events').doc('ev_future_full').set({
        'spotId': 's1',
        'title': 'Event Full',
        'status': 'full',
        'startAt': Timestamp.fromDate(now.add(const Duration(days: 3))),
      });
      await db.collection('events').doc('ev_past').set({
        'spotId': 's1',
        'title': 'Event Past',
        'status': 'open',
        'startAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      });
      await db.collection('events').doc('ev_cancelled').set({
        'spotId': 's1',
        'title': 'Event Cancelled',
        'status': 'cancelled',
        'startAt': Timestamp.fromDate(now.add(const Duration(days: 2))),
      });

      final events = await repo.eventsAt('s1');
      expect(events.length, 2);
      expect(events.map((e) => e.id).toList(), containsAll(['ev_future_open', 'ev_future_full']));
    });

    test('watchMine filters providerId and status open', () async {
      await db.collection('spot_schedules').doc('sch_p1_open').set({
        'spotId': 's1',
        'providerId': 'p1',
        'window': {'start': '06:00', 'end': '11:00'},
        'days': ['2026-10-10'],
        'status': 'open',
      });
      await db.collection('spot_schedules').doc('sch_p1_cancelled').set({
        'spotId': 's1',
        'providerId': 'p1',
        'window': {'start': '06:00', 'end': '11:00'},
        'days': ['2026-10-10'],
        'status': 'cancelled',
      });
      await db.collection('spot_schedules').doc('sch_p2_open').set({
        'spotId': 's1',
        'providerId': 'p2',
        'window': {'start': '06:00', 'end': '11:00'},
        'days': ['2026-10-10'],
        'status': 'open',
      });

      final stream = repo.watchMine('p1');
      final firstEmission = await stream.first;
      expect(firstEmission.length, 1);
      expect(firstEmission.first.id, 'sch_p1_open');
    });

    test('saveSchedule sends input to callable and returns scheduleId and addedDays', () async {
      final mockResult = _MockResult();
      when(() => mockResult.data).thenReturn({
        'scheduleId': 'new_sch_1',
        'addedDays': ['2026-10-10', '2026-10-11'],
      });
      when(() => callable.call<dynamic>(any())).thenAnswer((_) async => mockResult);

      const input = SpotScheduleInput(
        spotId: 's1',
        days: ['2026-10-10', '2026-10-11'],
        window: SpotWindow(start: '06:00', end: '11:00'),
        serviceIds: ['srv_1'],
        assigneeId: 'm1',
      );

      final res = await repo.saveSchedule(input);
      expect(res.scheduleId, 'new_sch_1');
      expect(res.addedDays, ['2026-10-10', '2026-10-11']);

      verify(() => functions.httpsCallable('saveSpotSchedule')).called(1);
      verify(() => callable.call<dynamic>(input.toCallable())).called(1);
    });
  });
}
