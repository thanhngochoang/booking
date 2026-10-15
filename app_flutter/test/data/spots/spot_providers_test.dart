// test/data/spots/spot_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/explore/location_controller.dart';

import '../../support/fake_spot_repository.dart';

class _CountingSpotRepository extends FakeSpotRepository {
  int hotCalls = 0;

  @override
  Future<List<SpotEntry>> hot(String key) async {
    hotCalls++;
    return super.hot(key);
  }
}

class _TestLocationController extends LocationController {
  _TestLocationController(this.initial);
  final LocationState initial;

  @override
  LocationState build() => initial;

  void setArea(SavedArea? area) {
    state = LocationState(loaded: true, area: area);
  }
}

void main() {
  group('spot_providers', () {
    test('hotSpotsProvider reads once per key per session (two listens, one repository call)', () async {
      final repo = _CountingSpotRepository();
      repo.seedRanking('hn', [
        const SpotEntry(
          spotId: 's1',
          name: 'Hồ Tây',
          city: 'HN',
          areaCode: 'hn',
          cardUrl: null,
          lat: 21.05,
          lng: 105.82,
          radiusM: 1500,
          seasonMonths: [],
          inSeason: true,
          pinned: false,
          hidden: false,
          hotScore: 10,
          openSchedules: 1,
          providersWeek: 1,
          providersWeekend: 1,
          upcomingEvents: 0,
        ),
      ]);

      final container = ProviderContainer(
        overrides: [
          spotRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // First read/listen
      final first = await container.read(hotSpotsProvider('hn').future);
      expect(first.length, 1);
      expect(repo.hotCalls, 1);

      // Second read/listen uses the same cached Future
      final second = await container.read(hotSpotsProvider('hn').future);
      expect(second.length, 1);
      expect(repo.hotCalls, 1);
    });

    test('spotRegionProvider follows the picked area', () {
      final locController = _TestLocationController(
        const LocationState(
          loaded: true,
          area: SavedArea(id: 'da-lat', name: 'Đà Lạt', geohash5: 'w7cx5'),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          locationControllerProvider.overrideWith(() => locController),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(spotRegionProvider), 'da-lat');

      locController.setArea(
        const SavedArea(id: 'hn-hoan-kiem', name: 'Hoàn Kiếm', geohash5: 'w7e5q'),
      );
      expect(container.read(spotRegionProvider), 'hn');

      locController.setArea(null);
      expect(container.read(spotRegionProvider), 'all');
    });
  });
}
