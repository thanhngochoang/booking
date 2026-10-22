// lib/data/instant/instant_geo.dart
import 'dart:math' as math;

import 'package:photobooking/core/core.dart';

/// Domain `estimateEtaMinutes` (spec §3.2): straight line × 1,4 at 20 km/h,
/// at least 1 minute. The epsilon keeps a float like 12.000000000000002 from
/// becoming 13, as on the server. The UI says "khoảng".
int estimateEtaMinutes(double km) =>
    math.max(1, (km * 1.4 * 60 / 20 - 1e-9).ceil());

/// The presence cells the server searches (Decision 12): `geohash5` (3 km
/// ring) and its 4-character prefix `geohash4` (6 and 10 km rings).
({String geohash5, String geohash4}) instantGeohashes(double lat, double lng) {
  final g5 = encodeGeohash(lat, lng, precision: 5);
  return (geohash5: g5, geohash4: g5.substring(0, 4));
}
