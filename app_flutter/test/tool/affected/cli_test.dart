// End to end: a throwaway git repo with a package in a subfolder, a base
// branch and a feature branch, analysed through the real CLI.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/affected/analysis.dart';
import '../../../tool/affected/cli.dart';

late Directory repo;
late Directory pkg;

void git(List<String> args) {
  final r = Process.runSync('git', [
    '-c',
    'user.name=t',
    '-c',
    'user.email=t@t',
    '-c',
    'commit.gpgsign=false',
    '-c',
    'core.hooksPath=/dev/null',
    '-c',
    'gc.auto=0',
    '-c',
    'maintenance.auto=false',
    ...args,
  ], workingDirectory: repo.path);
  if (r.exitCode != 0) fail('git $args: ${r.stderr}');
}

void write(String path, String content) => (File(
  '${repo.path}/$path',
)..createSync(recursive: true)).writeAsStringSync(content);

Future<Map<String, dynamic>> cli(
  List<String> args, {
  Map<String, String> env = const {},
}) async {
  final out = StringBuffer();
  final code = await runCli(
    [...args, '--json'],
    config: const AffectedConfig(),
    cwd: pkg,
    environment: env,
    out: out,
  );
  expect(code, 0);
  final text = out.toString();
  return jsonDecode(text.substring(text.indexOf('{'))) as Map<String, dynamic>;
}

/// On Apple Silicon flutter_tester runs under Rosetta, where the
/// /usr/bin/git shim cannot start; put an arm64 git (Homebrew) first in PATH.
final String? _noGit = () {
  try {
    final r = Process.runSync('git', ['--version']);
    return r.exitCode == 0 ? null : 'git does not run here: ${r.stderr}';
  } on ProcessException catch (e) {
    return 'git not found: $e';
  }
}();

void main() {
  if (_noGit != null) {
    test('affected CLI end to end', () {}, skip: _noGit);
    return;
  }
  setUp(() {
    repo = Directory.systemTemp.createTempSync('affected_cli_');
    pkg = Directory('${repo.path}/app');
    git(['init', '-q', '-b', 'base']);
    write('app/pubspec.yaml', 'name: demo\n');
    write('app/lib/a.dart', 'class A {}\n');
    write('app/lib/b.dart', 'class B {}\n');
    const t = "import 'package:flutter_test/flutter_test.dart';\n";
    write('app/test/a_test.dart', "${t}import 'package:demo/a.dart';\n");
    write('app/test/b_test.dart', "${t}import 'package:demo/b.dart';\n");
    write('README.md', '# demo\n');
    git(['add', '.']);
    git(['commit', '-q', '-m', 'base']);
    git(['checkout', '-q', '-b', 'feature']);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  test('committed change selects only its tests', () async {
    write('app/lib/a.dart', 'class A { int x = 1; }\n');
    git(['commit', '-qam', 'change a']);
    final r = await cli(['base']);
    expect(r['scope'], 'affected');
    expect(r['tests'], ['test/a_test.dart']);
    expect(r['skippedTests'], 1);
    expect(r['changed'], [
      {'path': 'app/lib/a.dart', 'kind': 'source'},
    ]);
  });

  test('uncommitted and untracked files count too', () async {
    write('app/lib/b.dart', 'class B { int y = 2; }\n');
    write('app/test/new_test.dart', "import 'package:demo/a.dart';\n");
    final r = await cli(['base']);
    expect(r['tests'], ['test/b_test.dart', 'test/new_test.dart']);
  });

  test('a rename lists both paths', () async {
    File('${repo.path}/app/lib/b.dart')
        .renameSync('${repo.path}/app/lib/c.dart');
    git(['add', '-A']);
    git(['commit', '-qm', 'rename']);
    final r = await cli(['base']);
    final paths = [for (final c in r['changed'] as List) c['path']];
    expect(paths, containsAll(['app/lib/b.dart', 'app/lib/c.dart']));
  });

  test('pubspec change → all', () async {
    write('app/pubspec.yaml', 'name: demo\nversion: 2.0.0\n');
    final r = await cli(['base']);
    expect(r['scope'], 'all');
    expect(r['reasons'], ['app/pubspec.yaml changed']);
  });

  test('docs only → none, or all with --on-none=all', () async {
    write('README.md', '# demo, edited\n');
    expect((await cli(['base']))['scope'], 'none');
    expect((await cli(['base', '--on-none=all']))['scope'], 'all');
  });

  test('base from the environment', () async {
    write('app/lib/a.dart', 'class A { int x = 1; }\n');
    final r = await cli([], env: {'AFFECTED_BASE': 'base'});
    expect(r['tests'], ['test/a_test.dart']);
  });

  test('unknown base ref → all, never none', () async {
    final r = await cli(['no-such-ref']);
    expect(r['scope'], 'all');
    expect(r['reasons'].single, contains('analysis failed'));
  });

  test('no base at all → all', () async {
    final r = await cli([]);
    expect(r['scope'], 'all');
    expect(r['totalTests'], 2);
  });

  test('--all skips the analysis', () async {
    expect((await cli(['base', '--all']))['scope'], 'all');
  });

  test('--github-output writes the outputs the workflow reads', () async {
    write('app/lib/a.dart', 'class A { int x = 1; }\n');
    final output = File('${repo.path}/out.txt');
    final summary = File('${repo.path}/summary.md');
    await cli(
      ['base', '--github-output'],
      env: {'GITHUB_OUTPUT': output.path, 'GITHUB_STEP_SUMMARY': summary.path},
    );
    expect(
      output.readAsStringSync(),
      'scope=AFFECTED\nfiles=test/a_test.dart\ncount=1\n',
    );
    expect(summary.readAsStringSync(), contains('Running 1 of 2 tests'));
  });

  test('the text report names the fallback reason', () async {
    write('app/analysis_options.yaml', 'include: x\n');
    final out = StringBuffer();
    await runCli(
      ['base'],
      config: const AffectedConfig(),
      cwd: pkg,
      environment: const {},
      out: out,
    );
    expect(
      out.toString(),
      contains('Affected test analysis was inconclusive.'),
    );
    expect(out.toString(), contains('app/analysis_options.yaml changed'));
    expect(out.toString(), contains('Running ALL tests (2).'));
  });
}
