// test/data/events/nearby_events_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';

final _now = DateTime.utc(2026, 10, 1, 5);

EventSummary event(
  String id, {
  double? lat = 10.78,
  double? lng = 106.70,
  int priceVnd = 250000,
  int capacity = 20,
  int registered = 5,
  int held = 0,
  EventStatus status = EventStatus.open,
  Duration startsIn = const Duration(days: 3),
  Duration createdAgo = const Duration(days: 1),
  String title = 'Photo walk',
}) => EventSummary(
  id: id,
  title: title,
  hostName: 'Quốc Bảo',
  hostVerified: true,
  type: EventType.photoWalk,
  startsAt: _now.add(startsIn),
  locationName: 'Công viên Bạch Đằng',
  geohash: lat == null ? null : encodeGeohash(lat, lng!),
  lat: lat,
  lng: lng,
  priceVnd: priceVnd,
  capacity: capacity,
  registeredCount: registered,
  heldCount: held,
  status: status,
  createdAt: _now.subtract(createdAgo),
);

void main() {
  group('EventSummary', () {
    test('free, seats left and geo flags', () {
      final e = event('a', priceVnd: 0, capacity: 10, registered: 6, held: 2);
      expect(e.isFree, isTrue);
      expect(e.seatsLeft, 2);
      expect(e.hasGeo, isTrue);
      expect(event('b', lat: null).hasGeo, isFalse);
      expect(event('c', capacity: 5, registered: 7).seatsLeft, 0);
    });

    test('codes round-trip and unknown codes are safe', () {
      expect(EventType.fromCode('mini_session'), EventType.miniSession);
      expect(EventType.fromCode('???'), EventType.other);
      expect(EventType.photoWalk.code, 'photo_walk');
      expect(EventStatus.fromCode('full'), EventStatus.full);
      expect(EventStatus.fromCode('???'), EventStatus.closed);
    });
  });

  group('FakeNearbyEventsRepository', () {
    test(
      'inCells matches geohash prefixes, hides non-public and past events',
      () async {
        final repo = FakeNearbyEventsRepository([
          event('near'),
          event('far', lat: 21.03, lng: 105.85),
          event('draft', status: EventStatus.draft),
          event('past', startsIn: const Duration(days: -1)),
          event('nogeo', lat: null),
        ]);
        final cell = encodeGeohash(10.78, 106.70, precision: 3);
        final got = await repo.inCells([cell], from: _now);
        expect(got.map((e) => e.id), ['near']);
        expect(repo.cellQueries.single, [cell]);
      },
    );

    test('upcoming lists public future events by start time', () async {
      final repo = FakeNearbyEventsRepository([
        event('b', startsIn: const Duration(days: 5)),
        event('a', startsIn: const Duration(days: 2)),
        event('x', status: EventStatus.cancelled),
      ]);
      expect((await repo.upcoming(from: _now)).map((e) => e.id), ['a', 'b']);
      expect(repo.upcomingCalls, 1);
    });

    test('countCreatedSince counts new events, within cells, capped', () async {
      final repo = FakeNearbyEventsRepository([
        for (var i = 0; i < 12; i++)
          event('e$i', createdAgo: Duration(hours: i + 1)),
        event('old', createdAgo: const Duration(days: 30)),
      ]);
      expect(await repo.countCreatedSince(), 10, reason: 'capped at 10');
      expect(
        await repo.countCreatedSince(
          since: _now.subtract(const Duration(hours: 3, minutes: 30)),
        ),
        3,
      );
      expect(await repo.countCreatedSince(cells: ['zzz']), 0);
    });

    test('failWith makes every call throw', () async {
      final repo = FakeNearbyEventsRepository()
        ..failWith = StateError('offline');
      expect(() => repo.upcoming(from: _now), throwsStateError);
      expect(() => repo.inCells(['w'], from: _now), throwsStateError);
      expect(() => repo.countCreatedSince(), throwsStateError);
    });
  });

  test('the production default has no events', () async {
    const repo = EmptyNearbyEventsRepository();
    expect(await repo.inCells(['w'], from: _now), isEmpty);
    expect(await repo.upcoming(from: _now), isEmpty);
    expect(await repo.countCreatedSince(), 0);
  });
}
