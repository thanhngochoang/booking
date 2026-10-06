import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spectrum colours are used only by the brand loaders', () {
    const allowed = {
      'lib/core/widgets/signature_loader.dart',
      'lib/core/widgets/dot_ring_loader.dart',
      'lib/core/theme/tokens.g.dart',
    };
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (allowed.contains(f.path)) continue;
      if (f.readAsStringSync().contains('.spectrum')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}
