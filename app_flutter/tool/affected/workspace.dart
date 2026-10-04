// Git and filesystem access for the affected-test analysis.

import 'dart:convert';
import 'dart:io';

import 'analysis.dart';

class WorkspaceException implements Exception {
  WorkspaceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The nearest directory at or above [start] holding a pubspec.yaml.
Directory findPackageRoot(Directory start) {
  var dir = start.absolute;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw WorkspaceException('no pubspec.yaml at or above ${start.path}');
    }
    dir = parent;
  }
}

/// Runs git in [dir]; throws [WorkspaceException] on a non-zero exit.
String git(Directory dir, List<String> args) {
  final r = Process.runSync(
    'git',
    ['-c', 'core.quotePath=false', ...args],
    workingDirectory: dir.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (r.exitCode != 0) {
    throw WorkspaceException(
      'git ${args.join(' ')} failed: ${(r.stderr as String).trim()}',
    );
  }
  return r.stdout as String;
}

class ChangeSet {
  const ChangeSet(this.files, this.compared);

  /// Repo-relative paths, old and new name of every rename included.
  final List<String> files;

  /// What the diff ran against, for the report (`origin/develop @ 1a2b3c4`).
  final String compared;
}

/// Files that differ between [base] and the working tree: committed,
/// staged, unstaged and untracked changes, so a local run sees what CI
/// will see after the next push. In CI the working tree is HEAD.
ChangeSet changedFiles(Directory packageRoot, String base) {
  final repo = Directory(
    git(packageRoot, ['rev-parse', '--show-toplevel']).trim(),
  );
  final baseSha = git(repo, [
    'rev-parse',
    '--verify',
    '--quiet',
    '$base^{commit}',
  ]).trim();
  String from;
  String compared;
  try {
    from = git(repo, ['merge-base', baseSha, 'HEAD']).trim();
    compared = '$base (merge-base ${from.substring(0, 7)})';
  } on WorkspaceException {
    // Shallow clone or unrelated history: diffing the trees directly lists a
    // superset of the branch's changes, which is still safe.
    from = baseSha;
    compared = '$base (no merge-base, comparing trees)';
  }
  List<String> lines(String out) =>
      out.split('\x00').where((l) => l.isNotEmpty).toList();
  final diff = git(repo, [
    '-c',
    'diff.relative=false',
    'diff',
    '--name-only',
    '--no-renames', // a rename lists both paths
    '-z',
    from,
  ]);
  final untracked = git(repo, [
    'ls-files',
    '--others',
    '--exclude-standard',
    '-z',
  ]);
  final files = {...lines(diff), ...lines(untracked)}.toList()..sort();
  return ChangeSet(files, compared);
}

/// Reads every Dart file under the source roots plus the pubspec.
Snapshot readSnapshot(Directory packageRoot, AffectedConfig config) {
  final packageDir = normalizePath(
    git(packageRoot, ['rev-parse', '--show-prefix']).trim(),
  );
  final pubspec = File('${packageRoot.path}/pubspec.yaml').readAsStringSync();
  final name = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec);
  if (name == null) throw WorkspaceException('pubspec.yaml has no name');

  final sources = <String, String>{};
  for (final root in config.sourceRoots) {
    final dir = Directory('${packageRoot.path}/$root');
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true, followLinks: false)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final rel = e.path.substring(packageRoot.path.length + 1);
      // Throws on invalid UTF-8: the caller falls back to all tests.
      sources[joinPath(packageDir, rel.replaceAll(r'\', '/'))] = e
          .readAsStringSync();
    }
  }
  return Snapshot(
    packageDir: packageDir,
    packageName: name.group(1)!,
    dartSources: sources,
    pubspecInputs: [
      for (final p in pubspecInputs(pubspec))
        ...() {
          final path = normalizePath(joinPath(packageDir, p));
          return p.endsWith('/') ? ['$path/**'] : [path, '$path/**'];
        }(),
    ],
  );
}

/// Package-relative paths the pubspec pulls in: entries of `assets:` and
/// `fonts:` blocks, and `path:` dependencies. A small line reader, not a
/// YAML parser; it only has to over-approximate.
List<String> pubspecInputs(String pubspec) {
  final out = <String>[];
  int? block; // indentation of the open assets:/fonts: key
  final entry = RegExp(
    r'''^\s*-?\s*(?:asset:\s*|path:\s*)?['"]?([^'"\s#:]+)['"]?\s*$''',
  );
  for (final raw in const LineSplitter().convert(pubspec)) {
    final line = raw.replaceFirst(RegExp(r'\s+#.*$'), '');
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final indent = line.length - trimmed.length;
    if (RegExp(r'^(assets|fonts):\s*$').hasMatch(trimmed)) {
      block = indent;
      continue;
    }
    if (block != null && indent <= block) block = null;
    final dep = RegExp(r'''^path:\s*['"]?([^'"\s]+)''').firstMatch(trimmed);
    if (dep != null) {
      out.add(dep.group(1)!);
    } else if (block != null) {
      final m = entry.firstMatch(line);
      if (m != null) out.add(m.group(1)!);
    }
  }
  return out;
}
