import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_geo.dart';

void main() {
  test(
    'estimateEtaMinutes matches the domain table (0→1, 1.2→6, 2.1→9, 10→42)',
    () {
      // packages/domain/src/instant.ts: max(1, ceil(km × 1.4 / 20 × 60)).
      expect(estimateEtaMinutes(0), 1);
      expect(estimateEtaMinutes(1.2), 6);
      expect(estimateEtaMinutes(2.1), 9);
      expect(estimateEtaMinutes(10), 42);
      expect(estimateEtaMinutes(0.1), 1);
      expect(estimateEtaMinutes(-1), 1);
    },
  );

  test(
    'presence geohashes: geohash4 is the first four characters of geohash5',
    () {
      final g = instantGeohashes(10.7769, 106.7009);
      expect(g.geohash5, hasLength(5));
      expect(g.geohash4, g.geohash5.substring(0, 4));
    },
  );
}
