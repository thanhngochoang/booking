// On a pull request the Flutter workflow's `changes` job skips analyze, test
// and report unless a file matching its APP_PATHS list changes. A test that
// reads a file outside app_flutter/ would silently not run on a PR touching
// only that file, so the list must cover every such read.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/affected/analysis.dart';
import '../../../tool/affected/directives.dart';

void main() {
  test('the workflow APP_PATHS list covers every file tests read outside '
      'app_flutter/', () {
    final yml = File('../.github/workflows/flutter.yml').readAsStringSync();
    final m = RegExp(r'\n\s*APP_PATHS=\(([^)]*)\)').firstMatch(yml);
    expect(m, isNotNull, reason: 'APP_PATHS=(...) not found');
    final filters = [
      for (final f in RegExp(r"'([^']+)'").allMatches(m!.group(1)!))
        Glob(f.group(1)!),
    ];
    final uncovered = <String>[];
    final tests = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in tests) {
      for (final read in parseDiskReads(file.readAsStringSync())) {
        if (read.unknown || !read.path.startsWith('../')) continue;
        final target = normalizePath('app_flutter/${read.path}');
        final covered = filters.any(
          (g) => g.matches(target) || g.matches('$target/x'),
        );
        if (!covered) uncovered.add('${file.path} reads ${read.path}');
      }
    }
    expect(uncovered, isEmpty, reason: 'add these to APP_PATHS (changes job)');
  });
}
