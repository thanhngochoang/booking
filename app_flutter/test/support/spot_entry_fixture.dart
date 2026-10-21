// test/support/spot_entry_fixture.dart
import 'package:photobooking/data/spots/spot.dart';

/// A directory entry of an active spot, for the S12.01 and S10.01 tests.
SpotEntry spotEntryFixture({
  required String id,
  required String name,
  String city = 'Hà Nội',
  double lat = 21.05,
  double lng = 105.82,
  int radiusM = 1000,
  int hotScore = 0,
  bool inSeason = false,
  List<int> seasonMonths = const [],
  String? cardUrl,
}) => SpotEntry(
  spotId: id,
  name: name,
  city: city,
  areaCode: 'hn',
  cardUrl: cardUrl,
  lat: lat,
  lng: lng,
  radiusM: radiusM,
  seasonMonths: seasonMonths,
  inSeason: inSeason,
  pinned: false,
  hidden: false,
  hotScore: hotScore,
  openSchedules: 0,
  providersWeek: 0,
  providersWeekend: 0,
  upcomingEvents: 0,
);
