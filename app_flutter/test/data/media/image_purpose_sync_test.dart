import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/media/image_purpose.dart';

void main() {
  test('ImagePurpose is in sync with upload-policy.json contract', () {
    final file = File('test/data/contracts/upload-policy.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final purposes = (json['purposes'] as List).cast<Map<String, dynamic>>();

    final purposeByCode = {
      for (final p in ImagePurpose.values) p.code: p,
    };

    // Verify every entry of upload-policy.json matches an ImagePurpose
    for (final entry in purposes) {
      final code = entry['code'] as String;
      final purpose = purposeByCode[code];
      expect(purpose, isNotNull, reason: 'No ImagePurpose for policy $code');
      expect(purpose!.longSide, entry['longSide'], reason: '$code longSide');
      expect(purpose.quality, entry['quality'], reason: '$code quality');
      expect(purpose.maxBytes, entry['maxBytes'], reason: '$code maxBytes');
      expect(
        purpose.publicCache,
        entry['visibility'] == 'public',
        reason: '$code publicCache == (visibility == public)',
      );
      expect(
        purpose.cacheControl,
        entry['cacheControl'],
        reason: '$code cacheControl',
      );
    }

    // Verify every ImagePurpose appears in upload-policy.json
    final policyCodes = purposes.map((p) => p['code'] as String).toSet();
    for (final purpose in ImagePurpose.values) {
      expect(
        policyCodes.contains(purpose.code),
        isTrue,
        reason: '${purpose.code} missing from upload-policy.json',
      );
    }
  });
}
