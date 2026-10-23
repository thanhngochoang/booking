// test/core/widgets/slot_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/screen_host.dart';

void main() {
  const slots = <({String start, String end, bool free})>[
    (start: '06:00', end: '06:30', free: true),
    (start: '06:40', end: '07:10', free: false),
    (start: '07:20', end: '07:50', free: true),
    (start: '08:00', end: '08:30', free: false),
    (start: '08:40', end: '09:10', free: true),
    (start: '09:20', end: '09:50', free: true),
    (start: '10:00', end: '10:30', free: false),
  ];

  Widget host({
    String? selected,
    ValueChanged<String>? onPick,
    Brightness brightness = Brightness.dark,
    double textScale = 1,
  }) => screenApp(
    brightness: brightness,
    textScale: textScale,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SlotGrid(
          slots: slots,
          selected: selected,
          onPick: onPick ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('taken slots are dimmed with "Đã kín" and not tappable', (
    tester,
  ) async {
    final picked = <String>[];
    await tester.pumpWidget(host(onPick: picked.add));

    expect(find.text('Đã kín'), findsNWidgets(3));
    expect(find.text('–06:30'), findsOneWidget);
    final dim = find.ancestor(
      of: find.text('06:40'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(dim.first).opacity, 0.5);

    await tester.tap(find.text('06:40'));
    await tester.pump();
    expect(picked, isEmpty);
  });

  testWidgets('picking calls onPick with the start', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(host(onPick: picked.add, selected: '08:40'));

    await tester.tap(find.text('07:20'));
    await tester.pump();
    expect(picked, ['07:20']);

    expect(
      tester.getSemantics(find.byKey(const Key('slot-08:40'))),
      isSemantics(label: '08:40–09:10', isChecked: true),
    );
  });

  testWidgets('320 dp, 1.3×, dark, light', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final b in Brightness.values) {
      await tester.pumpWidget(host(brightness: b, textScale: 1.3));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('09:20'), findsOneWidget);
    }
  });
}
