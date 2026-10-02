// test/core/widgets/evidence_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/photo_scope.dart';
import 'widget_host.dart';

List<PostThumb> _thumbs(int n) => [
  for (var i = 0; i < n; i++)
    PostThumb(id: 'p$i', imageUrl: 'https://img.test/p$i.jpg'),
];

Widget _host({
  int count = 6,
  Set<String> initial = const {},
  List<Set<String>>? changes,
  VoidCallback? onMax,
  VoidCallback? onEnd,
  List<PhotoRequest>? photos,
  double height = 400,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) {
  var selected = initial;
  return hostWidget(
    testPhotoScope(
      log: photos,
      child: SizedBox(
        height: height,
        child: StatefulBuilder(
          builder: (context, setState) => EvidencePicker(
            posts: _thumbs(count),
            selected: selected,
            onChanged: (v) {
              changes?.add(v);
              setState(() => selected = v);
            },
            onMaxReached: onMax,
            onEndReached: onEnd,
          ),
        ),
      ),
    ),
    width: width,
    textScale: textScale,
    brightness: brightness,
  );
}

void main() {
  testWidgets('tapping selects and unselects, in tap order', (tester) async {
    final changes = <Set<String>>[];
    await tester.pumpWidget(_host(changes: changes));
    await tester.tap(find.byKey(const Key('evidence-p2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('evidence-p0')));
    await tester.pump();
    expect(changes.last.toList(), ['p2', 'p0']);
    expect(
      find.descendant(
        of: find.byKey(const Key('evidence-p2')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('evidence-p2')));
    await tester.pump();
    expect(changes.last.toList(), ['p0']);
  });

  testWidgets('a 4th pick is refused and reported', (tester) async {
    final changes = <Set<String>>[];
    var maxed = 0;
    await tester.pumpWidget(
      _host(
        initial: {'p0', 'p1', 'p2'},
        changes: changes,
        onMax: () => maxed++,
      ),
    );
    await tester.tap(find.byKey(const Key('evidence-p3')));
    await tester.pump();
    expect(changes, isEmpty);
    expect(maxed, 1);
  });

  testWidgets('tiles are buttons with a selected state and a label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(initial: {'p1'}));
    expect(
      tester.getSemantics(find.byKey(const Key('evidence-p1'))),
      isSemantics(
        label: 'Ảnh 2',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('evidence-p0'))).width,
      greaterThanOrEqualTo(48),
    );
    handle.dispose();
  });

  testWidgets('the grid is lazy and photos are decoded at tile size', (
    tester,
  ) async {
    final photos = <PhotoRequest>[];
    await tester.pumpWidget(_host(count: 60, photos: photos));
    final grid = tester.widget<GridView>(
      find.byKey(const Key('evidence-grid')),
    );
    expect(grid.childrenDelegate, isA<SliverChildBuilderDelegate>());
    expect(find.byType(NetworkPhoto).evaluate().length, lessThan(60));
    expect(photos, isNotEmpty);
    for (final p in photos) {
      expect(p.cacheWidth, isNotNull, reason: p.url);
      expect(
        p.cacheWidth!,
        lessThanOrEqualTo(400),
        reason: 'tile ≈ 125dp at 3x',
      );
    }
  });

  testWidgets('scrolling near the end asks for more', (tester) async {
    var ends = 0;
    await tester.pumpWidget(_host(count: 60, onEnd: () => ends++));
    await tester.drag(
      find.byKey(const Key('evidence-grid')),
      const Offset(0, -6000),
    );
    await tester.pumpAndSettle();
    expect(ends, greaterThan(0));
  });

  testWidgets('320dp at 1.3x in both themes; no blur in tiles', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        _host(initial: {'p0'}, width: 320, textScale: 1.3, brightness: b),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    }
  });
}
