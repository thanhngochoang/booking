// test/features/explore/nearby_events_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/nearby_events.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/events/nearby_events_repository_test.dart' show event;

// Thursday 1 Oct 2026, 12:00 in Vietnam. Origin: central Ho Chi Minh City.
final _now = DateTime.utc(2026, 10, 1, 5);
const _lat = 10.7769;
const _lng = 106.7009;

void main() {
  group('selectNearby', () {
    final a = event('a', lat: 10.7869, lng: 106.7009, title: 'A 1,1 km');
    final b = event('b', lat: 10.8369, lng: 106.7009, title: 'B 6,7 km');
    final c = event('c', lat: 11.0, lng: 106.7, title: 'C 24,8 km');
    final d = event('d', lat: 11.2, lng: 106.7, title: 'D 47 km');

    List<String> ids(List<NearbyEvent> r) => r.map((e) => e.event.id).toList();

    test('sorts by distance and rounds the label distance to 0.1 km', () {
      final r = selectNearby(
        [c, a, b],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(),
        now: _now,
      );
      expect(ids(r), ['a', 'b', 'c']);
      expect(r.map((e) => e.distanceKm), [1.1, 6.7, 24.8]);
    });

    test('radius limits the list; 50 km brings the far one in', () {
      final all = [a, b, c, d];
      expect(
        ids(
          selectNearby(
            all,
            lat: _lat,
            lng: _lng,
            filters: const NearbyFilters(),
            now: _now,
          ),
        ),
        ['a', 'b', 'c'],
      );
      expect(
        ids(
          selectNearby(
            all,
            lat: _lat,
            lng: _lng,
            filters: const NearbyFilters(radiusKm: 10),
            now: _now,
          ),
        ),
        ['a', 'b'],
      );
      expect(
        ids(
          selectNearby(
            all,
            lat: _lat,
            lng: _lng,
            filters: const NearbyFilters(radiusKm: 50),
            now: _now,
          ),
        ),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('equal distances fall back to the earlier start', () {
      final x = event(
        'x',
        lat: 10.7869,
        lng: 106.7009,
        startsIn: const Duration(days: 4),
      );
      final y = event(
        'y',
        lat: 10.7869,
        lng: 106.7009,
        startsIn: const Duration(days: 2),
      );
      final r = selectNearby(
        [x, y],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(),
        now: _now,
      );
      expect(ids(r), ['y', 'x']);
    });

    test(
      'drops events without geo, cancelled, draft and past; keeps full ones',
      () {
        final r = selectNearby(
          [
            event('nogeo', lat: null),
            event(
              'cancelled',
              lat: 10.78,
              lng: 106.70,
              status: EventStatus.cancelled,
            ),
            event('draft', lat: 10.78, lng: 106.70, status: EventStatus.draft),
            event(
              'past',
              lat: 10.78,
              lng: 106.70,
              startsIn: const Duration(hours: -2),
            ),
            event('full', lat: 10.78, lng: 106.70, status: EventStatus.full),
          ],
          lat: _lat,
          lng: _lng,
          filters: const NearbyFilters(),
          now: _now,
        );
        expect(ids(r), ['full']);
      },
    );

    test('"Tuần này" ends at Monday 00:00 Vietnam time', () {
      final sundayNight = event(
        'sun',
        lat: 10.78,
        lng: 106.70,
        startsIn: const Duration(days: 3, hours: 11),
      ); // Sun 23:00 VN
      final mondayAfter = event(
        'mon',
        lat: 10.78,
        lng: 106.70,
        startsIn: const Duration(days: 3, hours: 12, minutes: 30),
      ); // Mon 00:30 VN
      final r = selectNearby(
        [sundayNight, mondayAfter],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(thisWeek: true),
        now: _now,
      );
      expect(ids(r), ['sun']);
    });

    test('"Cuối tuần" keeps Saturday and Sunday within the next 7 days', () {
      final sat = event(
        'sat',
        lat: 10.78,
        lng: 106.70,
        startsIn: const Duration(days: 2),
      ); // Sat 3 Oct
      final tue = event(
        'tue',
        lat: 10.78,
        lng: 106.70,
        startsIn: const Duration(days: 5),
      ); // Tue
      final nextSat = event(
        'next',
        lat: 10.78,
        lng: 106.70,
        startsIn: const Duration(days: 9),
      ); // Sat 10 Oct
      final r = selectNearby(
        [sat, tue, nextSat],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(weekend: true),
        now: _now,
      );
      expect(ids(r), ['sat']);
    });

    test('"Không thu phí" keeps price 0 only', () {
      final free = event('free', lat: 10.78, lng: 106.70, priceVnd: 0);
      final paid = event('paid', lat: 10.78, lng: 106.70);
      final r = selectNearby(
        [free, paid],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(freeOnly: true),
        now: _now,
      );
      expect(ids(r), ['free']);
    });
  });

  group('NearbyFiltersController', () {
    ProviderContainer make() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('defaults and toggles', () {
      final c = make();
      expect(c.read(nearbyFiltersProvider), const NearbyFilters());
      final n = c.read(nearbyFiltersProvider.notifier);
      n.toggleFree();
      n.toggleWeekend();
      n.toggleThisWeek();
      n.setRadius(10);
      expect(
        c.read(nearbyFiltersProvider),
        const NearbyFilters(
          radiusKm: 10,
          thisWeek: true,
          weekend: true,
          freeOnly: true,
        ),
      );
      n.toggleFree();
      expect(c.read(nearbyFiltersProvider).freeOnly, isFalse);
    });

    test('widen steps 10 -> 25 -> 50 and then says no', () {
      final c = make();
      final n = c.read(nearbyFiltersProvider.notifier);
      n.setRadius(10);
      expect(n.widen(), isTrue);
      expect(c.read(nearbyFiltersProvider).radiusKm, 25);
      expect(n.widen(), isTrue);
      expect(c.read(nearbyFiltersProvider).radiusKm, 50);
      expect(n.widen(), isFalse);
      expect(c.read(nearbyFiltersProvider).radiusKm, 50);
    });
  });

  group('nearbyEventsProvider', () {
    Future<(ProviderContainer, FakeNearbyEventsRepository, SharedPreferences)>
    make({
      LocationPermissionStatus status = LocationPermissionStatus.granted,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = FakeNearbyEventsRepository([
        event('a', lat: 10.7869, lng: 106.7009),
        event('b', lat: 10.8369, lng: 106.7009),
        event('far', lat: 21.03, lng: 105.85),
      ]);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => _now),
          nearbyEventsRepositoryProvider.overrideWithValue(repo),
          locationRepositoryProvider.overrideWithValue(
            FakeLocationRepository(
              status: status,
              location: ApproxLocation(lat: _lat, lng: _lng, capturedAt: _now),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(locationControllerProvider);
      await pumpEventQueue();
      return (container, repo, prefs);
    }

    test('returns nearby events sorted by distance', () async {
      final (c, _, _) = await make();
      final r = await c.read(nearbyEventsProvider.future);
      expect(r.map((e) => e.event.id), ['a', 'b']);
    });

    test('without an origin there is nothing to query', () async {
      final (c, repo, _) = await make(
        status: LocationPermissionStatus.deniedForever,
      );
      expect(await c.read(nearbyEventsProvider.future), isEmpty);
      expect(repo.cellQueries, isEmpty);
    });

    test(
      'only geohash prefixes reach the repository, never coordinates',
      () async {
        final (c, repo, prefs) = await make();
        await c.read(nearbyEventsProvider.future);
        final cells = repo.cellQueries.single;
        // The default radius (25 km) uses a 5x5 block of 4-character cells.
        expect(cells, hasLength(25));
        for (final cell in cells) {
          expect(cell.length, inInclusiveRange(2, 5));
          expect(cell, matches(RegExp(r'^[0-9bcdefghjkmnpqrstuvwxyz]+$')));
        }
        expect(
          cells.first,
          startsWith('w3'),
          reason: 'cell around Ho Chi Minh City',
        );
        expect(cells.every((x) => x.length == 4), isTrue);
        expect(prefs.getKeys(), isNot(contains('lat')));
      },
    );

    test('a larger radius queries shorter, wider cells', () async {
      final (c, repo, _) = await make();
      c.read(nearbyFiltersProvider.notifier).setRadius(50);
      await c.read(nearbyEventsProvider.future);
      expect(repo.cellQueries.last, hasLength(9));
      expect(repo.cellQueries.last.every((x) => x.length == 3), isTrue);
    });

    test('changing a filter reloads with the new filter', () async {
      final (c, _, _) = await make();
      await c.read(nearbyEventsProvider.future);
      c.read(nearbyFiltersProvider.notifier).setRadius(10);
      final r = await c.read(nearbyEventsProvider.future);
      expect(r.map((e) => e.event.id), ['a', 'b']);
      c.read(nearbyFiltersProvider.notifier).toggleFree();
      expect(await c.read(nearbyEventsProvider.future), isEmpty);
    });

    test(
      'upcomingEventsProvider lists events regardless of location',
      () async {
        final (c, repo, _) = await make(
          status: LocationPermissionStatus.deniedForever,
        );
        final r = await c.read(upcomingEventsProvider.future);
        expect(r, hasLength(3));
        expect(repo.upcomingCalls, 1);
      },
    );
  });
}
