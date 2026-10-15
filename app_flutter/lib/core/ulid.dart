import 'dart:math' as math;

const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// A ULID: 10 characters of UTC millisecond time, then 16 random ones.
/// Ids made later sort later, and they can be created on the device without
/// asking the server (data-model/README.md, section 2.1).
String newUlid({DateTime? now, math.Random? random}) {
  var time = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  final rng = random ?? math.Random.secure();
  final out = List<String>.filled(26, '0');
  for (var i = 9; i >= 0; i--) {
    out[i] = _alphabet[time % 32];
    time ~/= 32;
  }
  for (var i = 10; i < 26; i++) {
    out[i] = _alphabet[rng.nextInt(32)];
  }
  return out.join();
}

/// The creation time inside a ULID, or null when [id] is not one.
DateTime? ulidTime(String id) {
  if (id.length != 26) {
    return null;
  }
  var ms = 0;
  for (var i = 0; i < 10; i++) {
    final v = _alphabet.indexOf(id[i]);
    if (v < 0) {
      return null;
    }
    ms = ms * 32 + v;
  }
  for (var i = 10; i < 26; i++) {
    if (!_alphabet.contains(id[i])) {
      return null;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
