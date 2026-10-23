import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/screen_host.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget strip, {
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = Size(width, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    screenApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: strip),
      ),
      textScale: textScale,
      brightness: brightness,
    ),
  );
}

const _members = [
  MemberStripItem(id: 'minh', name: 'Minh Trí', tomatoPct: 97),
  MemberStripItem(id: 'nhung', name: 'Hồng Nhung', tomatoPct: 91),
  MemberStripItem(id: 'bao', name: 'Quốc Bảo', tomatoPct: 89),
  MemberStripItem(id: 'linh', name: 'Khánh Linh'),
  MemberStripItem(id: 'an', name: 'An', tomatoPct: 80),
];

void main() {
  testWidgets('shows up to 4 and +n; semantics list', (tester) async {
    final semantics = tester.ensureSemantics();
    final tapped = <String>[];
    await _pump(
      tester,
      MemberStrip(
        members: _members,
        total: 6,
        label: 'Thành viên Studio Mây',
        onTap: tapped.add,
      ),
    );

    for (final name in ['Minh Trí', 'Hồng Nhung', 'Quốc Bảo', 'Khánh Linh']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('An'), findsNothing);
    expect(find.text('+2'), findsOneWidget);

    final list = tester.getSemantics(
      find.bySemanticsLabel('Thành viên Studio Mây'),
    );
    expect(list.getSemanticsData().role, SemanticsRole.list);
    expect(
      tester.getSemantics(find.byKey(const Key('member-strip-minh'))),
      matchesSemantics(
        label: 'Minh Trí, 97% cà chua',
        isButton: true,
        hasTapAction: true,
      ),
    );
    // No percent under five reviews.
    expect(find.bySemanticsLabel('Khánh Linh'), findsOneWidget);
    expect(find.bySemanticsLabel('và 2 thành viên khác'), findsOneWidget);
    for (final label in [
      'Minh Trí, 97% cà chua',
      'Khánh Linh',
      'và 2 thành viên khác',
    ]) {
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .role,
        SemanticsRole.listItem,
        reason: label,
      );
    }

    await tester.tap(find.text('Hồng Nhung'));
    expect(tapped, ['nhung']);
    semantics.dispose();
  });

  testWidgets('no "+n" when every member is shown', (tester) async {
    await _pump(
      tester,
      MemberStrip(
        members: _members.take(3).toList(),
        total: 3,
        label: 'Thành viên Studio Mây',
      ),
    );
    expect(find.byKey(const Key('member-strip-more')), findsNothing);
    expect(find.text('Quốc Bảo'), findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x text, light and dark, and has a skeleton', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      await _pump(
        tester,
        Column(
          children: [
            const MemberStrip(
              members: _members,
              total: 12,
              label: 'Thành viên Studio Mây',
            ),
            MemberStrip.skeleton(),
          ],
        ),
        width: 320,
        textScale: 1.3,
        brightness: b,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('+8'), findsOneWidget);
    }
  });
}
