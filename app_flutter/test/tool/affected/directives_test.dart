import 'package:flutter_test/flutter_test.dart';

import '../../../tool/affected/directives.dart';

List<String> uris(String src) =>
    parseDirectives(src).map((d) => '${d.kind.name} ${d.uri}').toList();

void main() {
  group('parseDirectives', () {
    test('reads imports, exports and parts with combinators', () {
      expect(
        uris('''
library;

import 'dart:io';
import 'package:demo/a.dart' as a show A, B hide C;
export "b.dart" show B;
import 'c.dart' deferred as c;
part 'x.g.dart';

class Foo {}
import 'not_a_directive.dart';
'''),
        [
          'import dart:io',
          'import package:demo/a.dart',
          'export b.dart',
          'import c.dart',
          'part x.g.dart',
        ],
      );
    });

    test('reads every URI of a conditional import', () {
      expect(
        uris(
          "import 'stub.dart'\n"
          "    if (dart.library.io) 'io.dart'\n"
          "    if (dart.library.js_interop) 'web.dart';\n",
        ),
        ['import stub.dart', 'import io.dart', 'import web.dart'],
      );
    });

    test('skips comments (nested), annotations and the script tag', () {
      expect(
        uris('''
#!/usr/bin/env dart
// import 'line_comment.dart';
/* outer /* import 'nested.dart'; */ still comment */
@Tags(['golden', "a)b"])
@visibleForTesting
library my.lib;

import
    'multi_line.dart';
'''),
        ['import multi_line.dart'],
      );
    });

    test('reads part of, by URI and by library name', () {
      expect(uris("part of 'lib.dart';"), ['partOf lib.dart']);
      expect(uris('part of my.lib;'), isEmpty);
    });

    test('joins adjacent string literals and raw strings', () {
      expect(uris("import 'pa' 'rt.dart';\nimport r'raw.dart';"), [
        'import part.dart',
        'import raw.dart',
      ]);
    });

    test('stops at the first declaration', () {
      expect(uris('void main() {}\nimport "late.dart";'), isEmpty);
      expect(uris(''), isEmpty);
    });

    test('throws on what it cannot read', () {
      for (final bad in [
        r"import 'a$b.dart';",
        "import 'a.dart'",
        '/* unterminated',
        'import ;',
        "import 'a.dart' if (x 'b.dart';",
      ]) {
        expect(() => parseDirectives(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('parseDiskReads', () {
    test('literal, multi-line, interpolated and raw paths', () {
      final reads = parseDiskReads(r'''
final a = File('android/app/AndroidManifest.xml');
final b = Directory(
  'lib/features',
);
final c = File('lib/core/widgets/$name');
final d = File(r'../packages/notes/spec.md');
''');
      expect(reads.map((r) => r.toString()), [
        'android/app/AndroidManifest.xml',
        'lib/features',
        'lib/core/widgets/*',
        '../packages/notes/spec.md',
      ]);
    });

    test('a non-literal or absolute path is an unknown read', () {
      final reads = parseDiskReads(
        "File(path); Directory('\$root/lib'); File('/etc/hosts');",
      );
      expect(reads.every((r) => r.unknown), isTrue);
      expect(reads, hasLength(3));
    });

    test('ignores lookalikes', () {
      expect(parseDiskReads('final f = MyFile("x"); profile("y");'), isEmpty);
    });
  });
}
