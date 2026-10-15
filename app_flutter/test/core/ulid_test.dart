import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/ulid.dart';

void main() {
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  test('26 characters from the Crockford alphabet', () {
    final id = newUlid();
    expect(id, hasLength(26));
    expect(id.split('').every(alphabet.contains), isTrue);
  });

  test('the first ten characters are the time, so ids sort by creation', () {
    final a = newUlid(now: DateTime.utc(2026, 10, 1, 5), random: Random(1));
    final b = newUlid(
      now: DateTime.utc(2026, 10, 1, 5, 0, 0, 1),
      random: Random(1),
    );
    final c = newUlid(now: DateTime.utc(2027), random: Random(1));
    expect([c, a, b]..sort(), [a, b, c]);
    expect(a.substring(0, 10).compareTo(b.substring(0, 10)), lessThan(0));
  });

  test('the time can be read back', () {
    final t = DateTime.utc(2026, 10, 1, 5, 30, 15, 123);
    expect(ulidTime(newUlid(now: t)), t);
  });

  test('same millisecond, different randomness: different ids', () {
    final t = DateTime.utc(2026, 10, 1);
    expect(
      newUlid(now: t, random: Random(1)),
      isNot(newUlid(now: t, random: Random(2))),
    );
    expect(
      newUlid(now: t, random: Random(7)),
      newUlid(now: t, random: Random(7)),
    );
  });

  test('ulidTime rejects things that are not ULIDs', () {
    expect(ulidTime('abc'), isNull);
    expect(ulidTime('x' * 26), isNull);
    expect(ulidTime('I' * 26), isNull, reason: 'I is not in the alphabet');
  });
}
