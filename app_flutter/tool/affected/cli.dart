// Command line of tool/affected_test.dart. See docs/testing/affected-tests.md.

import 'dart:convert';
import 'dart:io';

import 'analysis.dart';
import 'workspace.dart';

const usage = '''
Usage: dart run tool/affected_test.dart [<base-ref>] [options] [-- <flutter test args>]

Selects the Flutter tests a branch can affect, from the Dart import graph
and the files tests read from disk. When unsure it selects ALL tests.

<base-ref>   commit or ref to compare with (origin/develop, a SHA, ...).
             Default: \$AFFECTED_BASE, else origin/\$GITHUB_BASE_REF.

  --list           print the report (default)
  --run            run the selected tests with `flutter test` (\$FLUTTER overrides
                   the command); arguments after `--` go to flutter test
  --all            skip the analysis and select all tests
  --json           print the result as JSON instead of the report
  --verbose, -v    also print each changed file's kind and why each test runs
  --github-output  write scope/files/count to \$GITHUB_OUTPUT and a summary to
                   \$GITHUB_STEP_SUMMARY
  --on-none=MODE   no test affected: skip (default, reported loudly) or all
                   (\$AFFECTED_ON_NONE)
  --help, -h       this text
''';

class _Options {
  String? base;
  var run = false;
  var all = false;
  var json = false;
  var verbose = false;
  var githubOutput = false;
  String? onNone;
  final testArgs = <String>[];
}

const _rule = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';

Future<int> runCli(
  List<String> args, {
  required AffectedConfig config,
  Directory? cwd,
  Map<String, String>? environment,
  StringSink? out,
}) async {
  final env = environment ?? Platform.environment;
  final sink = out ?? stdout;
  final o = _Options();
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    switch (a) {
      case '--':
        o.testArgs.addAll(args.skip(i + 1));
        i = args.length;
      case '--list':
        break;
      case '--run':
        o.run = true;
      case '--all':
        o.all = true;
      case '--json':
        o.json = true;
      case '--verbose' || '-v':
        o.verbose = true;
      case '--github-output':
        o.githubOutput = true;
      case '--help' || '-h':
        sink.write(usage);
        return 0;
      default:
        if (a.startsWith('--on-none=')) {
          o.onNone = a.substring('--on-none='.length);
        } else if (a.startsWith('--base=')) {
          o.base = a.substring('--base='.length);
        } else if (!a.startsWith('-') && o.base == null) {
          o.base = a;
        } else {
          stderr.writeln('Unknown argument: $a\n\n$usage');
          return 64;
        }
    }
  }
  // Empty means unset (an undefined repo variable expands to '').
  String? fromEnv(String name) =>
      (env[name]?.isEmpty ?? true) ? null : env[name];
  final baseRef = fromEnv('GITHUB_BASE_REF');
  o.base ??=
      fromEnv('AFFECTED_BASE') ?? (baseRef == null ? null : 'origin/$baseRef');
  final onNone = o.onNone ?? fromEnv('AFFECTED_ON_NONE') ?? 'skip';
  if (onNone != 'skip' && onNone != 'all') {
    stderr.writeln('--on-none must be skip or all, not $onNone');
    return 64;
  }

  final watch = Stopwatch()..start();
  Directory? root;
  Snapshot? snap;
  var compared = o.base ?? '-';
  AffectedResult result;
  try {
    root = findPackageRoot(cwd ?? Directory.current);
    snap = readSnapshot(root, config);
    if (o.all) {
      result = AffectedResult.fallback(
        '--all requested',
        totalTests: _countTests(snap, config),
      );
    } else if (o.base == null) {
      result = AffectedResult.fallback(
        'no base ref given (pass one, or set AFFECTED_BASE)',
        totalTests: _countTests(snap, config),
      );
    } else {
      final changes = changedFiles(root, o.base!);
      compared = changes.compared;
      result = analyze(snap, changes.files, config: config);
      if (result.scope == Scope.none && onNone == 'all') {
        result = AffectedResult(
          scope: Scope.all,
          reasons: [...result.reasons, '--on-none=all'],
          changed: result.changed,
          tests: const [],
          totalTests: result.totalTests,
        );
      }
    }
  } on Object catch (e) {
    // Never let a broken analysis skip tests.
    result = AffectedResult.fallback(
      'analysis failed: $e',
      totalTests: snap == null ? 0 : _countTests(snap, config),
    );
  }
  watch.stop();

  if (o.githubOutput) _writeGithub(result, compared, env, sink);
  if (o.json) {
    sink.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'base': compared,
        'scope': result.scope.name,
        'reasons': result.reasons,
        'changed': [
          for (final c in result.changed) {'path': c.path, 'kind': c.kind.name},
        ],
        'tests': result.tests,
        'totalTests': result.totalTests,
        'skippedTests': _skipped(result),
        if (o.verbose) 'why': result.why,
        if (o.verbose) 'notes': result.notes,
        'analysisMs': watch.elapsedMilliseconds,
      }),
    );
  } else {
    _report(result, compared, o.verbose, watch.elapsedMilliseconds, sink);
  }

  if (!o.run) return 0;
  if (result.scope == Scope.none) {
    sink.writeln('Nothing to run.');
    return 0;
  }
  if (root == null) {
    stderr.writeln('No Flutter package found: cannot run tests.');
    return 1;
  }
  final cmd = [
    'test',
    ...o.testArgs,
    if (result.scope == Scope.affected) ...result.tests,
  ];
  final flutter = env['FLUTTER'] ?? 'flutter';
  sink.writeln('\$ $flutter ${cmd.join(' ')}\n');
  final p = await Process.start(
    flutter,
    cmd,
    workingDirectory: root.path,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  return p.exitCode;
}

int _countTests(Snapshot snap, AffectedConfig config) {
  final root = joinPath(snap.packageDir, config.testRoot);
  return snap.dartSources.keys
      .where((p) => isWithin(root, p) && p.endsWith(config.testSuffix))
      .length;
}

int _skipped(AffectedResult r) => switch (r.scope) {
  Scope.all => 0,
  Scope.affected => r.totalTests - r.tests.length,
  Scope.none => r.totalTests,
};

void _report(
  AffectedResult r,
  String compared,
  bool verbose,
  int ms,
  StringSink out,
) {
  out
    ..writeln(_rule)
    ..writeln('Flutter Affected Tests')
    ..writeln(_rule)
    ..writeln()
    ..writeln('Base: $compared')
    ..writeln()
    ..writeln('Changed files: ${r.changed.length}')
    ..writeln();
  final width = r.changed.fold(
    0,
    (w, c) => c.path.length > w ? c.path.length : w,
  );
  for (final c in r.changed) {
    out.writeln(
      verbose ? '  ${c.path.padRight(width)}  ${c.kind.label}' : '  ${c.path}',
    );
  }
  if (r.changed.isNotEmpty) out.writeln();

  switch (r.scope) {
    case Scope.all:
      out
        ..writeln(_rule)
        ..writeln(
          r.reasons.length == 1 && r.reasons.first == '--all requested'
              ? 'All tests requested.'
              : 'Affected test analysis was inconclusive.',
        )
        ..writeln()
        ..writeln('Reason:');
      for (final reason in r.reasons.take(10)) {
        out.writeln('  $reason');
      }
      if (r.reasons.length > 10) {
        out.writeln('  ... and ${r.reasons.length - 10} more');
      }
      out
        ..writeln()
        ..writeln('Safety fallback:')
        ..writeln('  Running ALL tests (${r.totalTests}).')
        ..writeln(_rule);
    case Scope.none:
      out
        ..writeln(_rule)
        ..writeln('No affected tests.')
        ..writeln()
        ..writeln('Reason:')
        ..writeln('  ${r.reasons.join('; ')}')
        ..writeln()
        ..writeln(
          'Skipped tests: ${r.totalTests} (no test can see these changes)',
        )
        ..writeln(_rule);
    case Scope.affected:
      out
        ..writeln('Affected tests: ${r.tests.length}')
        ..writeln();
      for (final t in r.tests) {
        out.writeln('  ✓ $t');
        if (verbose) {
          final chain = r.why[t] ?? const [];
          if (chain.length > 1) {
            out.writeln(
              '      ⇐ ${chain.sublist(0, chain.length - 1).join(' ⇐ ')}',
            );
          }
          if (chain.isNotEmpty) out.writeln('      (${chain.last})');
        }
      }
      out
        ..writeln()
        ..writeln('Skipped tests: ${_skipped(r)}')
        ..writeln()
        ..writeln('${r.tests.length} affected tests')
        ..writeln(_rule);
  }
  if (verbose) {
    for (final n in r.notes) {
      out.writeln('note: $n');
    }
    out.writeln('analysis took $ms ms');
  }
}

void _writeGithub(
  AffectedResult r,
  String compared,
  Map<String, String> env,
  StringSink out,
) {
  // The workflow splits `files` on whitespace; a path with a space cannot
  // be passed safely, so run everything instead.
  final unsafe = r.tests.any((t) => t.contains(RegExp(r'\s')));
  final scope = unsafe ? Scope.all : r.scope;
  final outputs = env['GITHUB_OUTPUT'];
  if (outputs != null && outputs.isNotEmpty) {
    File(outputs).writeAsStringSync(
      'scope=${scope.name.toUpperCase()}\n'
      'files=${scope == Scope.affected ? r.tests.join(' ') : ''}\n'
      'count=${scope == Scope.affected ? r.tests.length : (scope == Scope.all ? r.totalTests : 0)}\n',
      mode: FileMode.append,
    );
  }
  switch (scope) {
    case Scope.all:
      out.writeln(
        '::notice title=Affected tests::Running ALL tests: '
        '${unsafe ? 'a test path contains whitespace' : r.reasons.first}',
      );
    case Scope.none:
      out.writeln(
        '::warning title=Affected tests::No test is affected by this change; '
        'tests are skipped (${r.reasons.first})',
      );
    case Scope.affected:
      out.writeln(
        '::notice title=Affected tests::Running ${r.tests.length} of '
        '${r.totalTests} tests',
      );
  }
  final summary = env['GITHUB_STEP_SUMMARY'];
  if (summary == null || summary.isEmpty) return;
  final b = StringBuffer()
    ..writeln('## Flutter affected tests')
    ..writeln()
    ..writeln('Base: `$compared`')
    ..writeln()
    ..writeln(switch (scope) {
      Scope.all => '**Running ALL ${r.totalTests} tests** (safety fallback)',
      Scope.none => '**No affected tests**: all ${r.totalTests} skipped',
      Scope.affected =>
        '**Running ${r.tests.length} of ${r.totalTests} tests**',
    })
    ..writeln();
  for (final reason in r.reasons) {
    b.writeln('- $reason');
  }
  b
    ..writeln()
    ..writeln('<details><summary>Changed files (${r.changed.length})</summary>')
    ..writeln();
  for (final c in r.changed) {
    b.writeln('- `${c.path}` (${c.kind.label})');
  }
  b.writeln('</details>');
  if (scope == Scope.affected) {
    b
      ..writeln()
      ..writeln(
        '<details><summary>Selected tests (${r.tests.length})</summary>',
      )
      ..writeln();
    for (final t in r.tests) {
      b.writeln('- `$t`');
    }
    b.writeln('</details>');
  }
  File(summary).writeAsStringSync(b.toString(), mode: FileMode.append);
}
