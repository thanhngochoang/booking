import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('no CircularProgressIndicator in lib', () {
    final offenders = <String>[];
    final libDir = Directory('lib');
    for (final file in libDir.listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        final lines = file.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
            continue;
          }
          if (line.contains('CircularProgressIndicator')) {
            offenders.add(file.path);
            break;
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'CircularProgressIndicator found in: ${offenders.join(', ')}',
    );
  });

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
  });

  test('MobilePassScanner is the only file importing mobile_scanner', () {
    final importers = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is File &&
          file.path.endsWith('.dart') &&
          file
              .readAsStringSync()
              .contains("import 'package:mobile_scanner/")) {
        importers.add(file.path.replaceAll(Platform.pathSeparator, '/'));
      }
    }
    expect(importers, ['lib/core/scan/mobile_pass_scanner.dart']);
  });

  test('screen_brightness is used only behind core/scan/brightness.dart', () {
    final importers = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is File &&
          file.path.endsWith('.dart') &&
          file
              .readAsStringSync()
              .contains("import 'package:screen_brightness/")) {
        importers.add(file.path.replaceAll(Platform.pathSeparator, '/'));
      }
    }
    expect(importers, ['lib/core/scan/brightness.dart']);
  });

  test('pubspec lists screen_brightness', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final deps = pubspec['dependencies'] as YamlMap;
    expect(deps['screen_brightness'], '^2.1.0');
  });
}
