import 'package:flutter_test/flutter_test.dart';

import '../../../tool/affected/analysis.dart';
import '../../../tool/affected/workspace.dart' show pubspecInputs;

const _pkg = 'app';

/// Dart source importing [uris].
String src(List<String> uris, {String body = 'void main() {}'}) =>
    '${uris.map((u) => "import '$u';").join('\n')}\n$body\n';

/// A test file importing [uris] (plus flutter_test, as real tests do).
String testSrc(List<String> uris, {String body = 'void main() {}'}) =>
    src(['package:flutter_test/flutter_test.dart', ...uris], body: body);

Snapshot snapshot(
  Map<String, String> files, {
  List<String> inputs = const [],
}) => Snapshot(
  packageDir: _pkg,
  packageName: 'demo',
  dartSources: {for (final e in files.entries) '$_pkg/${e.key}': e.value},
  pubspecInputs: inputs,
);

/// A → B → C → test_c; D → test_d; test_e reads android/ and ../docs/.
final world = snapshot({
  'lib/a.dart': src([]),
  'lib/b.dart': src(['package:demo/a.dart']),
  'lib/c.dart': src(['b.dart']),
  'lib/d.dart': src([]),
  'lib/model.dart': "import 'dart:core';\npart 'model.g.dart';\nclass M {}",
  'lib/model.g.dart': "part of 'model.dart';\n",
  'lib/l10n/app_localizations.dart': src([]),
  'lib/barrel.dart': "export 'package:demo/d.dart';\n",
  'test/c_test.dart': testSrc(['package:demo/c.dart']),
  'test/d_test.dart': testSrc(['package:demo/d.dart']),
  'test/barrel_test.dart': testSrc(['package:demo/barrel.dart']),
  'test/model_test.dart': testSrc(['package:demo/model.dart']),
  'test/l10n_test.dart': testSrc(['package:demo/l10n/app_localizations.dart']),
  'test/support/helper.dart': src(['package:demo/a.dart']),
  'test/helper_test.dart': testSrc(['support/helper.dart']),
  'test/widgets/golden_test.dart': testSrc([]),
  'test/disk_test.dart': testSrc(
    [],
    body: '''
void main() {
  File('android/app/src/main/AndroidManifest.xml');
  File('../packages/notes/spec.md');
  File('lib/features/\$name');
}''',
  ),
});

AffectedResult run(List<String> changed, {Snapshot? snap}) =>
    analyze(snap ?? world, changed);

List<String> selected(List<String> changed, {Snapshot? snap}) {
  final r = run(changed, snap: snap);
  expect(r.scope, Scope.affected, reason: r.reasons.join('; '));
  return r.tests;
}

void main() {
  group('dependency graph', () {
    test('direct dependency: A → test', () {
      expect(selected(['app/lib/d.dart']), contains('test/d_test.dart'));
    });

    test('transitive dependency: A → B → C → test', () {
      expect(selected(['app/lib/a.dart']), [
        'test/c_test.dart',
        'test/helper_test.dart',
      ]);
    });

    test('unrelated feature is not selected', () {
      final tests = selected(['app/lib/c.dart']);
      expect(tests, ['test/c_test.dart']);
    });

    test('multiple changes select the union', () {
      expect(selected(['app/lib/c.dart', 'app/lib/d.dart']), [
        'test/barrel_test.dart',
        'test/c_test.dart',
        'test/d_test.dart',
      ]);
    });

    test('exports propagate through a barrel', () {
      expect(selected(['app/lib/d.dart']), contains('test/barrel_test.dart'));
    });

    test('a changed test runs even if nothing else changed', () {
      expect(selected(['app/test/d_test.dart']), ['test/d_test.dart']);
    });

    test('a changed test helper selects the tests importing it', () {
      expect(selected(['app/test/support/helper.dart']), [
        'test/helper_test.dart',
      ]);
    });

    test('changed source and changed test: the union', () {
      expect(selected(['app/lib/c.dart', 'app/test/d_test.dart']), [
        'test/c_test.dart',
        'test/d_test.dart',
      ]);
    });

    test('a deleted test is not run', () {
      final r = run(['app/test/gone_test.dart']);
      expect(r.scope, Scope.none);
    });

    test('why: the chain back to the change', () {
      final r = run(['app/lib/a.dart']);
      expect(r.why['test/c_test.dart'], [
        'lib/c.dart',
        'lib/b.dart',
        'lib/a.dart',
        'changed',
      ]);
    });

    test('flutter_test_config.dart affects every test below it', () {
      final snap = snapshot({
        'lib/x.dart': src([]),
        'test/flutter_test_config.dart': src(['package:demo/x.dart']),
        'test/a/a_test.dart': testSrc([]),
        'other/b_test.dart': testSrc([]),
      });
      expect(selected(['app/lib/x.dart'], snap: snap), ['test/a/a_test.dart']);
      expect(selected(['app/test/flutter_test_config.dart'], snap: snap), [
        'test/a/a_test.dart',
      ]);
    });
  });

  group('generated code', () {
    test('a changed part selects the tests of its library', () {
      expect(selected(['app/lib/model.g.dart']), ['test/model_test.dart']);
    });

    test('an unreferenced generated file falls back to all tests', () {
      final r = run(['app/lib/orphan.freezed.dart']);
      expect(r.scope, Scope.all);
      expect(r.reasons.single, contains('cannot be mapped'));
    });

    test('a deleted generated file maps to its library', () {
      expect(selected(['app/lib/model.freezed.dart']), [
        'test/model_test.dart',
      ]);
    });

    test('a translation file selects the l10n dependants', () {
      expect(selected(['app/lib/l10n/app_vi.arb']), ['test/l10n_test.dart']);
    });
  });

  group('files read from disk', () {
    test('platform file: only the tests reading it', () {
      expect(selected(['app/android/app/src/main/AndroidManifest.xml']), [
        'test/disk_test.dart',
      ]);
    });

    test('a file outside the package read with ../', () {
      expect(selected(['packages/notes/spec.md']), ['test/disk_test.dart']);
    });

    test('an interpolated path is a prefix', () {
      expect(selected(['app/lib/features/new_screen.dart']), [
        'test/disk_test.dart',
      ]);
    });

    test('a test reading a non-literal path runs on any change', () {
      final snap = snapshot({
        'test/any_test.dart': testSrc([], body: 'void main() { File(p); }'),
      });
      expect(selected(['README.md'], snap: snap), ['test/any_test.dart']);
    });

    test('a golden selects the tests of the nearest directory with tests', () {
      expect(selected(['app/test/widgets/goldens/x.png']), [
        'test/widgets/golden_test.dart',
      ]);
    });
  });

  group('safe fallback', () {
    for (final f in [
      'app/pubspec.yaml',
      'app/pubspec.lock',
      'app/analysis_options.yaml',
      'app/build.yaml',
      'app/test/dart_test.yaml',
      'app/tool/gen.dart',
      'app/assets/logo.png',
    ]) {
      test('$f → all tests', () {
        final r = run([f, 'app/lib/c.dart']);
        expect(r.scope, Scope.all);
        expect(r.reasons, contains('$f changed'));
        expect(r.totalTests, 8);
      });
    }

    test('repo-level global files from the config', () {
      final r = analyze(world, [
        '.github/workflows/ci.yml',
      ], config: const AffectedConfig(repoGlobalFiles: ['.github/**']));
      expect(r.scope, Scope.all);
    });

    test('assets and path dependencies declared in the pubspec', () {
      final snap = snapshot(
        {'test/a_test.dart': testSrc([])},
        inputs: ['packages/shared/**'],
      );
      expect(run(['packages/shared/lib/x.dart'], snap: snap).scope, Scope.all);
    });

    test('an unparseable Dart file → all tests', () {
      final snap = snapshot({
        'lib/broken.dart': "import 'a.dart'", // no semicolon
        'test/a_test.dart': testSrc([]),
      });
      final r = run(['app/lib/other.dart'], snap: snap);
      expect(r.scope, Scope.all);
      expect(r.reasons.single, contains('could not parse'));
    });

    test('a test without imports means the scan is unreliable → all', () {
      final snap = snapshot({'test/a_test.dart': 'void main() {}'});
      expect(run(['app/lib/x.dart'], snap: snap).scope, Scope.all);
    });

    test('an unknown file in the package → all tests', () {
      expect(run(['app/lib/data.json']).scope, Scope.all);
      expect(run(['app/Makefile']).scope, Scope.all);
      expect(run(['app/integration_test/app_test.dart']).scope, Scope.all);
    });
  });

  group('no relevant changes', () {
    test('docs and other packages: no tests, with a reason', () {
      final r = run(['README.md', 'app/README.md', 'packages/domain/src/x.ts']);
      expect(r.scope, Scope.none);
      expect(r.tests, isEmpty);
      expect(r.reasons.single, contains('no test'));
      expect(r.changed.map((c) => c.kind), [
        ChangeKind.outside,
        ChangeKind.passive,
        ChangeKind.outside,
      ]);
    });

    test('platform file nobody reads', () {
      expect(run(['app/ios/Podfile']).scope, Scope.none);
    });

    test('no changed files', () {
      expect(run([]).scope, Scope.none);
    });
  });

  group('helpers', () {
    test('Glob', () {
      expect(Glob('tool/**').matches('tool/a/b.dart'), isTrue);
      expect(Glob('**/dart_test.yaml').matches('dart_test.yaml'), isTrue);
      expect(Glob('**/dart_test.yaml').matches('test/dart_test.yaml'), isTrue);
      expect(Glob('*.iml').matches('a/b.iml'), isFalse);
      expect(Glob('**/*.md').matches('docs/a.md'), isTrue);
    });

    test('pubspecInputs reads assets, fonts and path dependencies', () {
      expect(
        pubspecInputs('''
name: demo
dependencies:
  shared:
    path: ../packages/shared
flutter:
  generate: true
  assets:
    - assets/brand/logo.png
    - lib/data/seed.json # comment
  fonts:
    - family: Sans
      fonts:
        - asset: fonts/Sans.ttf
          weight: 500
  uses-material-design: true
'''),
        [
          '../packages/shared',
          'assets/brand/logo.png',
          'lib/data/seed.json',
          'fonts/Sans.ttf',
        ],
      );
    });
  });
}
