import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/area.dart';

void main() {
  test('built-in areas: unique ids, 12 entries, valid centres', () {
    expect(
      builtInAreas.length,
      greaterThan(8),
      reason: 'S36 shows search above 8',
    );
    expect(
      builtInAreas.map((a) => a.id).toSet(),
      hasLength(builtInAreas.length),
    );
    for (final a in builtInAreas) {
      expect(a.name.trim(), isNotEmpty);
      expect(a.geohash5, hasLength(5));
      expect(a.lat, inInclusiveRange(8, 24), reason: a.name);
      expect(a.lng, inInclusiveRange(102, 110), reason: a.name);
    }
    expect(builtInAreas.map((a) => a.name), contains('Quận 1, TP.HCM'));
  });

  test('the repository returns the built-in list', () async {
    expect(await const BuiltInAreaRepository().list(), builtInAreas);
  });

  test('a saved area keeps name, id and geohash5 only', () {
    final saved = builtInAreas.first.toSaved();
    final json = saved.toJson();
    expect(json.keys.toSet(), {'id', 'name', 'geohash5'});
    expect(SavedArea.fromJson(json), saved);
  });

  test('the centre of a saved area is inside its own cell', () {
    final a = builtInAreas.first;
    final c = a.toSaved().center;
    expect((c.lat - a.lat).abs(), lessThan(0.05));
    expect((c.lng - a.lng).abs(), lessThan(0.05));
  });

  test('fromJson rejects broken data', () {
    expect(() => SavedArea.fromJson({'id': 'x'}), throwsFormatException);
    expect(
      () => SavedArea.fromJson({'id': 'x', 'name': 'X', 'geohash5': 'abc'}),
      throwsFormatException,
    );
    expect(
      () => SavedArea.fromJson({'id': 'x', 'name': 'X', 'geohash5': 'zzzza'}),
      throwsFormatException,
      reason: '"a" is not a geohash character',
    );
  });
}
