import 'dart:math' as math;

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Standard geohash of [lat], [lng] with [precision] characters.
String encodeGeohash(double lat, double lng, {int precision = 9}) {
  assert(precision >= 1 && precision <= 12);
  var latMin = -90.0;
  var latMax = 90.0;
  var lngMin = -180.0;
  var lngMax = 180.0;
  final cLat = lat.clamp(-90.0, 90.0);
  final cLng = lng.clamp(-180.0, 180.0);
  final out = StringBuffer();
  var evenBit = true; // the first bit is longitude
  var bit = 0;
  var ch = 0;
  while (out.length < precision) {
    if (evenBit) {
      final mid = (lngMin + lngMax) / 2;
      if (cLng >= mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch = ch << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (cLat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch = ch << 1;
        latMax = mid;
      }
    }
    evenBit = !evenBit;
    bit++;
    if (bit == 5) {
      out.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}

({double lat, double lng, double latErr, double lngErr}) _decodeBox(
  String hash,
) {
  var latMin = -90.0;
  var latMax = 90.0;
  var lngMin = -180.0;
  var lngMax = 180.0;
  var evenBit = true;
  for (final c in hash.toLowerCase().split('')) {
    final idx = _base32.indexOf(c);
    if (idx < 0) {
      throw ArgumentError.value(hash, 'hash', 'not a geohash');
    }
    for (var n = 4; n >= 0; n--) {
      final bit = (idx >> n) & 1;
      if (evenBit) {
        final mid = (lngMin + lngMax) / 2;
        if (bit == 1) {
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (bit == 1) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      evenBit = !evenBit;
    }
  }
  return (
    lat: (latMin + latMax) / 2,
    lng: (lngMin + lngMax) / 2,
    latErr: (latMax - latMin) / 2,
    lngErr: (lngMax - lngMin) / 2,
  );
}

/// Centre of the cell named by [hash].
({double lat, double lng}) decodeGeohash(String hash) {
  final b = _decodeBox(hash);
  return (lat: b.lat, lng: b.lng);
}

/// [hash] followed by its neighbours, all of the same length. Cells past a pole
/// do not exist and are skipped; longitude wraps at the antimeridian.
List<String> geohashCells(String hash) {
  final b = _decodeBox(hash);
  final neighbours = <String>{};
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final lat = b.lat + dy * 2 * b.latErr;
      if (lat > 90 || lat < -90) {
        continue;
      }
      var lng = b.lng + dx * 2 * b.lngErr;
      if (lng > 180) {
        lng -= 360;
      }
      if (lng < -180) {
        lng += 360;
      }
      neighbours.add(encodeGeohash(lat, lng, precision: hash.length));
    }
  }
  return [hash, ...neighbours.where((c) => c != hash)];
}

/// Great-circle distance in kilometres.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0088;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}

/// Nearest 0.1 km, the precision shown in the UI.
double roundKm(double km) => (km * 10).round() / 10;

/// Longest geohash length whose 3x3 block still covers [radiusKm] around any
/// point of the centre cell. Cell heights are about 4.9, 19.5, 156 and 1250 km
/// for lengths 5, 4, 3 and 2; widths shrink with latitude, so the thresholds
/// keep a margin that holds up to the latitude of northern Vietnam.
int geohashPrecisionForRadiusKm(double radiusKm) {
  if (radiusKm <= 4) {
    return 5;
  }
  if (radiusKm <= 17) {
    return 4;
  }
  if (radiusKm <= 140) {
    return 3;
  }
  return 2;
}
