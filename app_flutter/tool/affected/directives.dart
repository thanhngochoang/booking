// Reads the two things the affected-test analysis needs from a Dart file:
//
//  * its directives (import / export / part / part of), and
//  * the paths a test opens from disk with File('...') / Directory('...').
//
// Directives are read with a small scanner over the file's prologue: Dart
// requires every directive to come before the first declaration, so the
// scanner stops there and never has to understand the rest of the language.
// Anything it cannot read throws FormatException; the caller then runs all
// tests instead of guessing.

enum DirectiveKind { import, export, part, partOf }

class Directive {
  const Directive(this.kind, this.uri);

  final DirectiveKind kind;
  final String uri;

  @override
  String toString() => '${kind.name} $uri';
}

/// A path a test reads from disk, relative to the package root.
///
/// [prefix] is true when the literal was cut at an interpolation
/// (`File('lib/features/$name')` → `lib/features/`): every path starting
/// with it may be read. [unknown] is true when the argument is not a string
/// literal at all, so the test may read anything.
class DiskRead {
  const DiskRead(this.path, {this.prefix = false}) : unknown = false;
  const DiskRead.unknown() : path = '', prefix = false, unknown = true;

  final String path;
  final bool prefix;
  final bool unknown;

  @override
  String toString() => unknown ? '<unknown>' : (prefix ? '$path*' : path);
}

/// Every directive URI of [source], conditional-import alternatives
/// included. Throws [FormatException] when the prologue cannot be read.
List<Directive> parseDirectives(String source) => _Scanner(source).directives();

final _diskCall = RegExp(r'\b(?:File|Directory|Link)\s*\(\s*');

/// Paths read with `File(...)`, `Directory(...)` or `Link(...)` in [source].
///
/// Comments are not stripped: a commented-out read only adds a test, it
/// never drops one.
List<DiskRead> parseDiskReads(String source) {
  final reads = <DiskRead>[];
  for (final m in _diskCall.allMatches(source)) {
    var i = m.end;
    var raw = false;
    if (i < source.length && source[i] == 'r') {
      raw = true;
      i++;
    }
    if (i >= source.length || (source[i] != "'" && source[i] != '"')) {
      reads.add(const DiskRead.unknown());
      continue;
    }
    final quote = source[i];
    final buf = StringBuffer();
    var cut = false;
    for (i++; i < source.length && source[i] != quote; i++) {
      final c = source[i];
      if (!raw && c == r'$') {
        cut = true;
        break;
      }
      if (!raw && c == r'\') {
        i++;
        if (i < source.length) buf.write(source[i]);
        continue;
      }
      if (c == '\n') break;
      buf.write(c);
    }
    final path = buf.toString();
    if (path.isEmpty || path.startsWith('/')) {
      reads.add(const DiskRead.unknown());
    } else {
      reads.add(DiskRead(path, prefix: cut));
    }
  }
  return reads;
}

class _Scanner {
  _Scanner(this.s);

  final String s;
  var i = 0;

  bool get _eof => i >= s.length;

  Never _fail(String what) {
    final line = '\n'.allMatches(s.substring(0, i.clamp(0, s.length))).length;
    throw FormatException('$what (line ${line + 1})');
  }

  List<Directive> directives() {
    final out = <Directive>[];
    if (s.startsWith('﻿')) i = 1;
    if (s.startsWith('#!', i)) _skipLine();
    while (true) {
      _skipTrivia();
      if (_eof) return out;
      if (s[i] == '@') {
        _skipAnnotation();
        continue;
      }
      final start = i;
      final word = _word();
      switch (word) {
        case 'library':
          _skipTo(';');
        case 'import':
          _uriDirective(DirectiveKind.import, out);
        case 'export':
          _uriDirective(DirectiveKind.export, out);
        case 'part':
          _skipTrivia();
          if (_peekString()) {
            out.add(Directive(DirectiveKind.part, _uri()));
            _expect(';');
          } else if (_word() == 'of') {
            _skipTrivia();
            // `part of 'lib.dart';` or the old `part of lib.name;`
            if (_peekString()) out.add(Directive(DirectiveKind.partOf, _uri()));
            _skipTo(';');
          } else {
            _fail('`part` not followed by a URI or `of`');
          }
        default:
          // First declaration: the prologue is over.
          i = start;
          return out;
      }
    }
  }

  void _uriDirective(DirectiveKind kind, List<Directive> out) {
    _skipTrivia();
    if (!_peekString()) _fail('`${kind.name}` not followed by a URI');
    out.add(Directive(kind, _uri()));
    // Combinators, prefixes and configurations up to the `;`.
    while (true) {
      _skipTrivia();
      if (_eof) _fail('unterminated ${kind.name}');
      final c = s[i];
      if (c == ';') {
        i++;
        return;
      }
      if (c == ',') {
        i++;
        continue;
      }
      final w = _word();
      if (w.isEmpty) _fail('unexpected `$c` in ${kind.name}');
      if (w == 'if') {
        _skipTrivia();
        _expect('(');
        _skipBalanced('(', ')');
        _skipTrivia();
        if (!_peekString()) _fail('configuration without a URI');
        out.add(Directive(kind, _uri()));
      }
    }
  }

  /// One or more adjacent string literals (`'a' 'b'` is legal), no
  /// interpolation.
  String _uri() {
    final buf = StringBuffer();
    var any = false;
    while (true) {
      _skipTrivia();
      if (!_peekString()) break;
      final (value, interpolated) = _string();
      if (interpolated) _fail('interpolation in a directive URI');
      buf.write(value);
      any = true;
    }
    if (!any) _fail('missing URI');
    return buf.toString();
  }

  bool _peekString() {
    if (_eof) return false;
    final c = s[i];
    if (c == "'" || c == '"') return true;
    return c == 'r' && i + 1 < s.length && (s[i + 1] == "'" || s[i + 1] == '"');
  }

  /// Reads a string literal starting at [i]; returns its text and whether
  /// it contained `$` interpolation.
  (String, bool) _string() {
    var raw = false;
    if (s[i] == 'r') {
      raw = true;
      i++;
    }
    final q = s[i];
    final triple = s.startsWith('$q$q$q', i);
    final close = triple ? '$q$q$q' : q;
    i += close.length;
    final buf = StringBuffer();
    var interpolated = false;
    while (true) {
      if (_eof) _fail('unterminated string');
      if (s.startsWith(close, i)) {
        i += close.length;
        return (buf.toString(), interpolated);
      }
      final c = s[i];
      if (!triple && c == '\n') _fail('newline in string');
      if (!raw && c == r'\') {
        i += 2;
        continue;
      }
      if (!raw && c == r'$') {
        interpolated = true;
        i++;
        if (!_eof && s[i] == '{') {
          i++;
          _skipBalanced('{', '}');
        }
        continue;
      }
      buf.write(c);
      i++;
    }
  }

  void _skipAnnotation() {
    i++; // @
    if (_word().isEmpty) _fail('bad annotation');
    while (!_eof && s[i] == '.') {
      i++;
      _word();
    }
    _skipTrivia();
    if (!_eof && s[i] == '<') {
      i++;
      _skipBalanced('<', '>');
      _skipTrivia();
    }
    if (!_eof && s[i] == '(') {
      i++;
      _skipBalanced('(', ')');
    }
  }

  /// Skips to just after the bracket closing one already consumed, stepping
  /// over strings and comments.
  void _skipBalanced(String open, String close) {
    var depth = 1;
    while (depth > 0) {
      _skipTrivia();
      if (_eof) _fail('unbalanced `$open`');
      if (_peekString()) {
        _string();
        continue;
      }
      final c = s[i++];
      if (c == open) depth++;
      if (c == close) depth--;
    }
  }

  void _skipTo(String end) {
    while (true) {
      _skipTrivia();
      if (_eof) _fail('missing `$end`');
      if (_peekString()) {
        _string();
        continue;
      }
      if (s[i++] == end) return;
    }
  }

  void _expect(String c) {
    _skipTrivia();
    if (_eof || s[i] != c) _fail('expected `$c`');
    i++;
  }

  String _word() {
    final start = i;
    while (!_eof && _isIdent(s.codeUnitAt(i))) {
      i++;
    }
    return s.substring(start, i);
  }

  static bool _isIdent(int c) =>
      (c >= 0x61 && c <= 0x7A) || // a-z
      (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x30 && c <= 0x39) || // 0-9
      c == 0x5F || // _
      c == 0x24; // $

  void _skipLine() {
    while (!_eof && s[i] != '\n') {
      i++;
    }
  }

  /// Whitespace and comments; block comments nest in Dart.
  void _skipTrivia() {
    while (!_eof) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        i++;
      } else if (s.startsWith('//', i)) {
        _skipLine();
      } else if (s.startsWith('/*', i)) {
        i += 2;
        var depth = 1;
        while (depth > 0) {
          if (_eof) _fail('unterminated block comment');
          if (s.startsWith('/*', i)) {
            depth++;
            i += 2;
          } else if (s.startsWith('*/', i)) {
            depth--;
            i += 2;
          } else {
            i++;
          }
        }
      } else {
        return;
      }
    }
  }
}
