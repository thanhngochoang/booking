// Affected-test analysis: which test files can a set of changed files reach?
//
// Pure functions over an in-memory [Snapshot] (git and disk access live in
// workspace.dart), so every rule here is unit-testable.
//
// Safety rule: when the analysis is unsure it answers "all tests". Extra
// tests are acceptable; a skipped test that could fail is not.

import 'directives.dart';

/// Path rules. Globs use `*` (within a segment) and `**` (any depth).
class AffectedConfig {
  const AffectedConfig({
    this.sourceRoots = const ['lib', 'test'],
    this.testRoot = 'test',
    this.testSuffix = '_test.dart',
    this.globalFiles = defaultGlobalFiles,
    this.repoGlobalFiles = const [],
    this.platformFiles = defaultPlatformFiles,
    this.passiveFiles = defaultPassiveFiles,
    this.generatedSuffixes = defaultGeneratedSuffixes,
    this.derivedDirs = const ['lib/l10n'],
    this.testConfigFile = 'flutter_test_config.dart',
  });

  /// Package-relative. A change here can affect any test: run them all.
  static const defaultGlobalFiles = [
    'pubspec.yaml',
    'pubspec.lock',
    'pubspec_overrides.yaml',
    'analysis_options.yaml',
    'build.yaml',
    'l10n.yaml',
    '**/dart_test.yaml',
    'tool/**', // code generators and this tool itself
    'assets/**', // loaded by widgets through the asset bundle
  ];

  /// Package-relative. Native projects: `flutter test` never builds them, so
  /// only tests that read them from disk can see a change.
  static const defaultPlatformFiles = [
    'android/**',
    'ios/**',
    'macos/**',
    'windows/**',
    'linux/**',
    'web/**',
  ];

  /// Package-relative files no test compiles or loads (seen only by tests
  /// that read them from disk).
  static const defaultPassiveFiles = [
    '**/*.md',
    'LICENSE',
    '.gitignore',
    '.metadata',
    '*.iml',
    'devtools_options.yaml',
  ];

  static const defaultGeneratedSuffixes = [
    '.g.dart',
    '.freezed.dart',
    '.gr.dart',
    '.config.dart',
    '.mocks.dart',
  ];

  /// Package-relative directories scanned for Dart files.
  final List<String> sourceRoots;
  final String testRoot;
  final String testSuffix;
  final List<String> globalFiles;

  /// Repo-relative globs that also force all tests (CI workflow, inputs of
  /// code generators that live outside the package, ...).
  final List<String> repoGlobalFiles;
  final List<String> platformFiles;
  final List<String> passiveFiles;
  final List<String> generatedSuffixes;

  /// Package-relative directories whose Dart files are generated from the
  /// non-Dart files next to them (`.arb` → `app_localizations*.dart`): a
  /// non-Dart change there marks every Dart file in the directory.
  final List<String> derivedDirs;

  /// `flutter test` runs this file around every test in its directory tree
  /// without anyone importing it.
  final String testConfigFile;
}

/// Everything the analysis reads, gathered by workspace.dart.
class Snapshot {
  const Snapshot({
    required this.packageDir,
    required this.packageName,
    required this.dartSources,
    this.pubspecInputs = const [],
  });

  /// Package root relative to the repo root (`''` when they are the same).
  final String packageDir;
  final String packageName;

  /// Repo-relative path → contents, for every Dart file under the source
  /// roots.
  final Map<String, String> dartSources;

  /// Repo-relative globs of files the pubspec pulls in (declared assets and
  /// fonts, path dependencies): a change there forces all tests.
  final List<String> pubspecInputs;
}

enum Scope { all, affected, none }

enum ChangeKind {
  config('config'),
  source('source'),
  generated('generated'),
  test('test'),
  testSupport('test support'),
  testData('test data'),
  derived('derived source'),
  platform('platform'),
  passive('docs/other'),
  outside('outside package'),
  unknown('unknown');

  const ChangeKind(this.label);
  final String label;
}

class ChangedFile {
  const ChangedFile(this.path, this.kind);

  /// Repo-relative.
  final String path;
  final ChangeKind kind;
}

class AffectedResult {
  const AffectedResult({
    required this.scope,
    required this.reasons,
    required this.changed,
    required this.tests,
    required this.totalTests,
    this.why = const {},
    this.notes = const [],
  });

  /// Analysis could not run at all (no base, git failure, unreadable tree).
  factory AffectedResult.fallback(
    String reason, {
    List<ChangedFile> changed = const [],
    int totalTests = 0,
  }) => AffectedResult(
    scope: Scope.all,
    reasons: [reason],
    changed: changed,
    tests: const [],
    totalTests: totalTests,
  );

  final Scope scope;

  /// Why every test runs (scope all) or why none does (scope none).
  final List<String> reasons;
  final List<ChangedFile> changed;

  /// Package-relative test files to run; empty unless scope is affected.
  final List<String> tests;
  final int totalTests;

  /// Test → dependency chain back to the change that selected it.
  final Map<String, List<String>> why;

  /// Things worth seeing with --verbose (unresolved imports, ...).
  final List<String> notes;
}

AffectedResult analyze(
  Snapshot snap,
  List<String> changedPaths, {
  AffectedConfig config = const AffectedConfig(),
}) {
  final pkg = snap.packageDir;
  String inPkg(String p) => joinPath(pkg, p);
  final testRoot = inPkg(config.testRoot);
  bool isTestFile(String p) =>
      isWithin(testRoot, p) && p.endsWith(config.testSuffix);

  // ── 1. Graph ──────────────────────────────────────────────────────
  final rdeps = <String, Set<String>>{};
  final diskReads = <String, List<DiskRead>>{};
  final tests = <String>[];
  final notes = <String>[];
  final parseErrors = <String>[];
  void edge(String from, String to) =>
      rdeps.putIfAbsent(to, () => {}).add(from);

  for (final MapEntry(key: file, value: source) in snap.dartSources.entries) {
    var directives = const <Directive>[];
    try {
      directives = parseDirectives(source);
    } on FormatException catch (e) {
      parseErrors.add('could not parse the directives of $file: ${e.message}');
    }
    if (isTestFile(file)) {
      tests.add(file);
      if (directives.isEmpty) {
        parseErrors.add('found no import in test $file');
      }
    }
    for (final d in directives) {
      final target = _resolve(file, d.uri, snap.packageName, pkg);
      if (target == null) continue;
      edge(file, target);
      // A part and its library are one unit: link both ways.
      if (d.kind == DirectiveKind.part || d.kind == DirectiveKind.partOf) {
        edge(target, file);
      }
      if (!snap.dartSources.containsKey(target)) {
        notes.add('unresolved ${d.kind.name} in $file: ${d.uri}');
      }
    }
    if (isWithin(testRoot, file)) {
      final reads = parseDiskReads(source);
      if (reads.isNotEmpty) diskReads[file] = reads;
    }
  }
  tests.sort();

  // flutter_test_config.dart wraps every test below it without an import.
  final testConfigs = snap.dartSources.keys
      .where((p) => basename(p) == config.testConfigFile)
      .toList();
  for (final t in tests) {
    for (final c in testConfigs) {
      if (isWithin(dirname(c), t)) edge(t, c);
    }
  }

  // ── 2. Classify changes ───────────────────────────────────────────
  final globals = [
    ...config.globalFiles.map(inPkg),
    ...config.repoGlobalFiles,
    ...snap.pubspecInputs,
  ].map(Glob.new).toList();
  final platform = config.platformFiles.map(Glob.new).toList();
  final passive = config.passiveFiles.map(Glob.new).toList();

  final changed = <ChangedFile>[];
  final reasons = <String>[];
  final seeds = <String, String>{}; // node → why it is a seed
  void seed(String node, String why) => seeds.putIfAbsent(node, () => why);

  for (final path in changedPaths) {
    final inside = pkg.isEmpty || isWithin(pkg, path);
    final rel = inside ? relativeTo(pkg, path) : path;
    final ChangeKind kind;
    if (globals.any((g) => g.matches(path))) {
      kind = ChangeKind.config;
      reasons.add('$path changed');
    } else if (!inside) {
      kind = ChangeKind.outside;
    } else if (path.endsWith('.dart') &&
        config.sourceRoots.any((r) => isWithin(inPkg(r), path))) {
      final gen = config.generatedSuffixes.where(path.endsWith).firstOrNull;
      if (gen != null) {
        kind = ChangeKind.generated;
        final owner = '${path.substring(0, path.length - gen.length)}.dart';
        final exists = snap.dartSources.containsKey(path);
        final ownerKnown =
            snap.dartSources.containsKey(owner) || changedPaths.contains(owner);
        if (exists && (rdeps[path]?.isNotEmpty ?? false)) {
          seed(path, 'changed');
        } else if (ownerKnown) {
          seed(path, 'changed');
          seed(owner, 'source of $path');
        } else {
          reasons.add(
            'generated file $path cannot be mapped to its source library',
          );
        }
      } else {
        kind = !isWithin(testRoot, path)
            ? ChangeKind.source
            : isTestFile(path)
            ? ChangeKind.test
            : ChangeKind.testSupport;
        seed(path, 'changed');
      }
      if (basename(path) == config.testConfigFile) {
        for (final t in tests.where((t) => isWithin(dirname(path), t))) {
          seed(t, 'under changed $path');
        }
      }
    } else if (config.derivedDirs.any((d) => isWithin(inPkg(d), path))) {
      kind = ChangeKind.derived;
      final dir = config.derivedDirs.firstWhere(
        (d) => isWithin(inPkg(d), path),
      );
      for (final f in snap.dartSources.keys.where(
        (f) => isWithin(inPkg(dir), f),
      )) {
        seed(f, 'generated from $path');
      }
    } else if (isWithin(testRoot, path)) {
      // Fixture or golden: the tests of the nearest directory that has any.
      kind = ChangeKind.testData;
      var dir = dirname(path);
      while (!tests.any((t) => isWithin(dir, t)) && dir != testRoot) {
        dir = dirname(dir);
      }
      for (final t in tests.where((t) => isWithin(dir, t))) {
        seed(t, 'near $path');
      }
    } else if (platform.any((g) => g.matches(rel))) {
      kind = ChangeKind.platform;
    } else if (passive.any((g) => g.matches(rel))) {
      kind = ChangeKind.passive;
    } else {
      kind = ChangeKind.unknown;
      reasons.add('$path changed and no rule says which tests it affects');
    }
    changed.add(ChangedFile(path, kind));
  }

  // A file the scanner could not read may import anything: unsafe to narrow.
  reasons.addAll(parseErrors);
  if (reasons.isNotEmpty) {
    return AffectedResult(
      scope: Scope.all,
      reasons: reasons,
      changed: changed,
      tests: const [],
      totalTests: tests.length,
      notes: notes,
    );
  }

  // ── 3. Tests that read changed paths from disk ────────────────────
  for (final MapEntry(key: file, value: reads) in diskReads.entries) {
    for (final r in reads) {
      if (r.unknown) {
        if (changedPaths.isNotEmpty) {
          seed(file, 'reads files from a non-literal path');
        }
        continue;
      }
      final target = normalizePath(joinPath(pkg, r.path));
      if (target.startsWith('../')) continue; // outside the repo
      final hit = changedPaths.where(
        (c) => r.prefix ? c.startsWith(target) : isWithin(target, c),
      );
      if (hit.isNotEmpty) seed(file, 'reads ${r.path} (${hit.first} changed)');
    }
  }

  // ── 4. Walk the reverse graph ─────────────────────────────────────
  final via = <String, String?>{for (final s in seeds.keys) s: null};
  final queue = [...seeds.keys];
  while (queue.isNotEmpty) {
    final node = queue.removeLast();
    for (final dependant in rdeps[node] ?? const <String>{}) {
      if (via.containsKey(dependant)) continue;
      via[dependant] = node;
      queue.add(dependant);
    }
  }

  final selected = tests.where(via.containsKey).toList();
  final why = <String, List<String>>{};
  for (final t in selected) {
    final chain = <String>[];
    String? n = via[t];
    while (n != null) {
      chain.add(n);
      n = via[n];
    }
    final root = chain.isEmpty ? t : chain.last;
    why[relativeTo(pkg, t)] = [
      ...chain.map((c) => relativeTo(pkg, c)),
      seeds[root] ?? '',
    ];
  }

  if (selected.isEmpty) {
    return AffectedResult(
      scope: Scope.none,
      reasons: [
        changed.isEmpty
            ? 'no changed files'
            : 'no test imports or reads any changed file',
      ],
      changed: changed,
      tests: const [],
      totalTests: tests.length,
      notes: notes,
    );
  }
  return AffectedResult(
    scope: Scope.affected,
    reasons: const [],
    changed: changed,
    tests: selected.map((t) => relativeTo(pkg, t)).toList(),
    totalTests: tests.length,
    why: why,
    notes: notes,
  );
}

/// Repo-relative target of [uri] written in [from], or null when it points
/// outside this package's sources (dart:, other packages).
String? _resolve(String from, String uri, String packageName, String pkg) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    if (slash < 0 || rest.substring(0, slash) != packageName) return null;
    return joinPath(pkg, 'lib/${rest.substring(slash + 1)}');
  }
  if (uri.contains(':')) return null; // other schemes
  return normalizePath(joinPath(dirname(from), uri));
}

// ── Posix path helpers (git always prints `/`) ──────────────────────

String joinPath(String a, String b) =>
    a.isEmpty ? b : (b.isEmpty ? a : '$a/$b');

String dirname(String p) {
  final i = p.lastIndexOf('/');
  return i < 0 ? '' : p.substring(0, i);
}

String basename(String p) => p.substring(p.lastIndexOf('/') + 1);

String normalizePath(String p) {
  final out = <String>[];
  for (final seg in p.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..' && out.isNotEmpty && out.last != '..') {
      out.removeLast();
    } else {
      out.add(seg);
    }
  }
  return out.join('/');
}

/// True when [path] is [dir] itself or inside it (`''` is the repo root).
bool isWithin(String dir, String path) =>
    dir.isEmpty || path == dir || path.startsWith('$dir/');

String relativeTo(String dir, String path) =>
    dir.isEmpty ? path : (path == dir ? '' : path.substring(dir.length + 1));

class Glob {
  Glob(this.pattern) : _re = _compile(pattern);

  final String pattern;
  final RegExp _re;

  bool matches(String path) => _re.hasMatch(path);

  static RegExp _compile(String glob) {
    final b = StringBuffer('^');
    for (var i = 0; i < glob.length; i++) {
      final c = glob[i];
      if (c == '*') {
        if (i + 1 < glob.length && glob[i + 1] == '*') {
          i++;
          if (i + 1 < glob.length && glob[i + 1] == '/') {
            i++;
            b.write('(?:.*/)?');
          } else {
            b.write('.*');
          }
        } else {
          b.write('[^/]*');
        }
      } else if (c == '?') {
        b.write('[^/]');
      } else {
        b.write(RegExp.escape(c));
      }
    }
    b.write(r'$');
    return RegExp(b.toString());
  }
}
