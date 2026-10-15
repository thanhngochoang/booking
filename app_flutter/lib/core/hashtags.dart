// A tag starts at a `#` that is not glued to a word, a path or an entity.
final _tag = RegExp(r'(?<![\p{L}\p{N}_/&#])#([\p{L}\p{N}_]+)', unicode: true);

/// Hashtags in [caption]: lower case, no `#`, unique, in order, 2 to 40
/// characters, at most 30. They are stored with the post; linking them to an
/// event timeline is done by the server (spec 3.7).
List<String> extractHashtags(String caption) {
  final seen = <String>{};
  final out = <String>[];
  for (final m in _tag.allMatches(caption)) {
    final tag = m.group(1)!.toLowerCase();
    if (tag.length < 2 || tag.length > 40 || !seen.add(tag)) {
      continue;
    }
    out.add(tag);
    if (out.length == 30) {
      break;
    }
  }
  return out;
}
