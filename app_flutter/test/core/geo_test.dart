import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/geo.dart';

void main() {
  group('geohash', () {
    test('encodes the reference points', () {
      expect(encodeGeohash(42.6, -5.6, precision: 5), 'ezs42');
      expect(encodeGeohash(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
    });

    test('default precision is 9', () {
      expect(encodeGeohash(10.7769, 106.7009), hasLength(9));
    });

    test('decode returns the cell centre and round-trips', () {
      final c = decodeGeohash('ezs42');
      expect(c.lat, closeTo(42.605, 0.003));
      expect(c.lng, closeTo(-5.603, 0.003));
      expect(encodeGeohash(c.lat, c.lng, precision: 5), 'ezs42');
    });

    test('decode rejects characters outside the alphabet', () {
      expect(() => decodeGeohash('ezs4a'), throwsArgumentError);
    });

    test('cells are the hash plus eight distinct neighbours', () {
      final cells = geohashCells('ezs42');
      expect(cells.first, 'ezs42');
      expect(cells.toSet(), hasLength(9));
      expect(cells.every((c) => c.length == 5), isTrue);
    });

    test('a point 1.2 cell widths away in any direction is in the block', () {
      final c = decodeGeohash('ezs42');
      const w = 360 / 8192; // width of a 5-character cell in degrees
      final cells = geohashCells('ezs42');
      for (final (dx, dy) in [
        (1.2, 0.0),
        (-1.2, 0.0),
        (0.0, 1.2),
        (0.0, -1.2),
        (1.2, 1.2),
        (-1.2, -1.2),
      ]) {
        final p = encodeGeohash(c.lat + dy * w, c.lng + dx * w, precision: 5);
        expect(cells, contains(p), reason: 'dx=$dx dy=$dy');
      }
    });

    test('a point two cells away is not in the block', () {
      final c = decodeGeohash('ezs42');
      const w = 360 / 8192;
      final far = encodeGeohash(c.lat, c.lng + 2.2 * w, precision: 5);
      expect(geohashCells('ezs42'), isNot(contains(far)));
    });

    test('longitude wraps across the antimeridian and poles are skipped', () {
      final edge = encodeGeohash(10.0, 179.99, precision: 4);
      final cells = geohashCells(edge);
      expect(cells.toSet(), hasLength(9));
      final pole = encodeGeohash(89.99, 10.0, precision: 4);
      expect(geohashCells(pole).length, lessThan(9));
    });
  });

  group('distance', () {
    test('haversine matches known city pairs', () {
      expect(haversineKm(48.8566, 2.3522, 51.5074, -0.1278), closeTo(343.5, 2));
      expect(
        haversineKm(21.0285, 105.8542, 10.7769, 106.7009),
        closeTo(1138, 15),
      );
    });

    test('0.01 degree of latitude is about 1.11 km, and zero is zero', () {
      expect(haversineKm(10.0, 106.0, 10.01, 106.0), closeTo(1.112, 0.005));
      expect(haversineKm(10.0, 106.0, 10.0, 106.0), 0);
    });

    test('roundKm rounds to the nearest 0.1', () {
      expect(roundKm(1.24), 1.2);
      expect(roundKm(1.26), 1.3);
      expect(roundKm(0), 0);
    });
  });

  group('geohashPrecisionForRadiusKm', () {
    test('shorter hashes for bigger radii', () {
      expect(geohashPrecisionForRadiusKm(3), 5);
      expect(geohashPrecisionForRadiusKm(10), 4);
      expect(geohashPrecisionForRadiusKm(25), 3);
      expect(geohashPrecisionForRadiusKm(50), 3);
      expect(geohashPrecisionForRadiusKm(300), 2);
    });
  });

  group('rings and geohashQueryFor', () {
    test('two rings give a 5x5 block, cell first', () {
      final cells = geohashCells('w3gv', rings: 2);
      expect(cells.toSet(), hasLength(25));
      expect(cells.first, 'w3gv');
    });

    test('a point 25 km from HCMC is inside the queried cells', () {
      final q = geohashQueryFor(25);
      final centre = encodeGeohash(10.7769, 106.7009, precision: q.precision);
      final cells = geohashCells(centre, rings: q.rings);
      final far = encodeGeohash(10.7769 + 0.225, 106.7009, precision: 4);
      expect(
        haversineKm(10.7769, 106.7009, 10.7769 + 0.225, 106.7009),
        closeTo(25, 0.5),
      );
      expect(cells, contains(far));
    });

    test('boundaries', () {
      expect(geohashQueryFor(4), (precision: 5, rings: 1));
      expect(geohashQueryFor(4.1), (precision: 4, rings: 2));
      expect(geohashQueryFor(39), (precision: 4, rings: 2));
      expect(geohashQueryFor(40), (precision: 3, rings: 1));
      expect(geohashQueryFor(140), (precision: 3, rings: 1));
      expect(geohashQueryFor(141), (precision: 2, rings: 1));
    });
  });
}
