import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  test('Android needs no storage, media or camera permission for the system picker', () {
    for (final banned in [
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VISUAL_USER_SELECTED',
      'android.permission.CAMERA',
      'MANAGE_EXTERNAL_STORAGE',
    ]) {
      expect(manifest, isNot(contains(banned)), reason: banned);
    }
  });

  test('image_picker is imported in one file only', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('package:image_picker/'))
        .map((f) => f.path)
        .toList();
    expect(offenders, ['lib/data/media/plugin_image_picker.dart']);
  });
}
