// test/core/widgets/screen_code_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';

const _childKey = Key('child');

Widget _host({required bool visible, String? label}) => ScreenCodeScope(
  visible: visible,
  child: MaterialApp(
    home: Scaffold(
      body: ScreenCode(
        ScreenCodes.bookingDetail,
        label: label,
        child: const Center(
          child: SizedBox(key: _childKey, width: 120, height: 40),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('shows the code when the switch is on', (tester) async {
    await tester.pumpWidget(_host(visible: true));
    expect(find.text('S09'), findsOneWidget);
  });

  testWidgets('a sub-part shows code.label', (tester) async {
    await tester.pumpWidget(_host(visible: true, label: 'timeline'));
    expect(find.text('S09.timeline'), findsOneWidget);
  });

  testWidgets('shows nothing when the switch is off', (tester) async {
    await tester.pumpWidget(_host(visible: false));
    expect(find.text('S09'), findsNothing);
    expect(find.byKey(_childKey), findsOneWidget);
  });

  testWidgets('without a scope the tag is hidden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScreenCode('S09', child: SizedBox(key: _childKey)),
      ),
    );
    expect(find.text('S09'), findsNothing);
  });

  testWidgets('the tag does not change the child layout or block taps', (
    tester,
  ) async {
    await tester.pumpWidget(_host(visible: false));
    final off = tester.getRect(find.byKey(_childKey));
    await tester.pumpWidget(_host(visible: true));
    expect(tester.getRect(find.byKey(_childKey)), off);

    var taps = 0;
    await tester.pumpWidget(
      ScreenCodeScope(
        visible: true,
        child: MaterialApp(
          home: Scaffold(
            body: ScreenCode(
              'S09',
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  // An empty SizedBox is not hit-testable on its own.
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(
                    key: _childKey,
                    width: 200,
                    height: 200,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Tap the top-left corner of the child, where the tag is drawn.
    await tester.tapAt(
      tester.getTopLeft(find.byKey(_childKey)) + const Offset(8, 8),
    );
    expect(taps, 1);
  });

  testWidgets('the tag is not announced by screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(visible: true));
    expect(find.bySemanticsLabel('S09'), findsNothing);
    handle.dispose();
  });

  testWidgets('a shown tag costs no frames at rest', (tester) async {
    await tester.pumpWidget(_host(visible: true));
    await expectIdle(tester);
  });
}
