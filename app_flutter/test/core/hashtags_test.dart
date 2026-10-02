import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/hashtags.dart';

void main() {
  test('lower-cases, strips the hash and keeps the order', () {
    expect(extractHashtags('Chiều muộn #ChanDung và #photowalk'), [
      'chandung',
      'photowalk',
    ]);
  });

  test('duplicates are dropped ignoring case', () {
    expect(extractHashtags('#Cuoi #cuoi #CUOI #gia_dinh'), [
      'cuoi',
      'gia_dinh',
    ]);
  });

  test('Vietnamese letters and digits are part of a tag', () {
    expect(extractHashtags('#nhiếpảnh #PhotoWalkPhoCo1020'), [
      'nhiếpảnh',
      'photowalkphoco1020',
    ]);
  });

  test('a lone hash, a one-letter tag and punctuation do not make tags', () {
    expect(extractHashtags('# #a #! hello'), isEmpty);
    expect(extractHashtags('Đẹp quá #chandung, #cuoi.'), ['chandung', 'cuoi']);
  });

  test('a tag is not taken from inside a word or a link', () {
    expect(extractHashtags('mail a#b link https://x.vn/page#section'), isEmpty);
    expect(extractHashtags('(#hoa) "#nang"'), ['hoa', 'nang']);
  });

  test('a tag over 40 characters is ignored and at most 30 are kept', () {
    expect(extractHashtags('#${'a' * 41}'), isEmpty);
    final many = List.generate(40, (i) => '#tag$i').join(' ');
    expect(extractHashtags(many), hasLength(30));
    expect(extractHashtags(many).first, 'tag0');
  });

  test('empty text has no tags', () {
    expect(extractHashtags(''), isEmpty);
  });
}
