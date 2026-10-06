import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Does not catch CupertinoIcons or implicit icons (covered by the theme's
// actionIconTheme); raw hex colours are not scanned.
void main() {
  test('features use AppIcons only', () {
    final pattern = RegExp(r'\b(Icons|Symbols)\.');
    final offenders = <String>[];
    for (final f in Directory('lib/features').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
