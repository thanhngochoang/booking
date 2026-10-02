import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no CircularProgressIndicator in lib', () {
    final offenders = <String>[];
    final libDir = Directory('lib');
    for (final file in libDir.listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        final content = file.readAsStringSync();
        if (content.contains('CircularProgressIndicator')) {
          offenders.add(file.path);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'CircularProgressIndicator found in: ${offenders.join(', ')}',
    );
  }, skip: 'enabled in Task 4');

  test('features do not hand-write AsyncValue loading', () {
    final offenders = <String>[];
    final featuresDir = Directory('lib/features');
    if (featuresDir.existsSync()) {
      for (final file in featuresDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          if (content.contains('.when(') && content.contains('loading:')) {
            offenders.add(file.path);
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Hand-written AsyncValue loading in: ${offenders.join(', ')}',
    );
  }, skip: 'enabled in Task 4');
}
