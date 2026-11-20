import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The framework design libraries moved to standalone packages. The legacy
// import strings are assembled from parts so this file does not match itself.
const _legacy = ['package:flutter/', 'material.dart'];
const _legacyCupertino = ['package:flutter/', 'cupertino.dart'];

void main() {
  test('no file imports the framework Material or Cupertino library', () {
    final needles = [_legacy.join(), _legacyCupertino.join()];
    final offenders = <String>[];
    for (final dir in [
      Directory('lib'),
      Directory('test'),
      Directory('tool'),
    ]) {
      for (final f in dir.listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.startsWith('lib/l10n/')) continue;
        final text = f.readAsStringSync();
        if (needles.any(text.contains)) offenders.add(f.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Import material_ui / cupertino_ui instead. Fix with: '
          'dart fix --apply --code=migrate_design_widgets. '
          'First ${offenders.length < 20 ? offenders.length : 20}: '
          '${offenders.take(20).join(', ')}',
    );
  });

  test('gen_tokens emits the material_ui import', () {
    final tool = File('tool/gen_tokens.dart').readAsStringSync();
    final tokens = File('lib/core/theme/tokens.g.dart').readAsStringSync();
    const wanted = 'package:material_ui/material_ui.dart';
    final legacy = _legacy.join();
    for (final text in [tool, tokens]) {
      expect(text, contains(wanted));
      expect(text, isNot(contains(legacy)));
    }
  });
}
