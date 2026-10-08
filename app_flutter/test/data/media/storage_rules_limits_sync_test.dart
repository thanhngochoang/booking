import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/media/image_purpose.dart';

/// The text of the `match /<path> {` block (up to its closing brace).
String _block(String rules, String path) {
  final start = rules.indexOf('match /$path {');
  expect(start, isNonNegative, reason: 'match /$path not found');
  final end = rules.indexOf('\n    }', start);
  expect(end, isNonNegative, reason: 'end of match /$path not found');
  return rules.substring(start, end);
}

/// `<expr>` of `jpegUpTo(<expr>)` evaluated as a product of integers.
int _limit(String block) {
  final m = RegExp(r'jpegUpTo\(([\d\s*]+)\)').firstMatch(block);
  expect(m, isNotNull, reason: 'jpegUpTo(<product of integers>) not found');
  return m!
      .group(1)!
      .split('*')
      .map((s) => int.parse(s.trim()))
      .fold(1, (a, b) => a * b);
}

void main() {
  final rules = File('firebase/storage.rules').readAsStringSync();

  test('each upload path uses jpegUpTo with its purpose\'s maxBytes', () {
    const table = {
      'avatars/{uid}/{file}': ImagePurpose.avatar,
      'posts/{uid}/{postId}/{file}': ImagePurpose.portfolio,
      'awardProofs/{uid}/{awardId}/{file}': ImagePurpose.document,
      'chats/{chatId}/{uid}/{file}': ImagePurpose.chat,
      'eventCovers/{uid}/{eventId}/{file}': ImagePurpose.share,
    };
    for (final MapEntry(key: path, value: purpose) in table.entries) {
      expect(
        _limit(_block(rules, path)),
        purpose.maxBytes,
        reason: path,
      );
    }
  });

  test('share fits under the posts limit', () {
    // posts/ holds both portfolio and share images; its limit is the larger.
    expect(
      ImagePurpose.share.maxBytes,
      lessThanOrEqualTo(ImagePurpose.portfolio.maxBytes),
    );
  });

  test('no upload path accepts any image/* type', () {
    expect(rules, isNot(contains('image/.*')));
    expect(rules, isNot(contains('validImage()')));
    expect(rules, isNot(contains('image/(')));
  });

  test('every writable allow rule uses jpegUpTo', () {
    // `allow <methods>: if <expr>;`, possibly over several lines.
    final statements = RegExp(r'allow\s+([\w\s,]+?)\s*:\s*if\s+([^;]*);')
        .allMatches(rules)
        .where((m) => RegExp(r'\b(create|update|write)\b').hasMatch(m.group(1)!))
        .where((m) => m.group(2)!.trim() != 'false')
        .toList();
    // Five upload paths today; a new one must come with its own jpegUpTo line.
    expect(statements, isNotEmpty);
    for (final m in statements) {
      expect(
        m.group(0)!,
        contains('jpegUpTo('),
        reason: 'writable rule without the JPEG type and size guard: ${m.group(0)}',
      );
    }
  });

  test('users/{uid}/** is closed', () {
    expect(rules, isNot(contains('match /users/')));
  });
}
