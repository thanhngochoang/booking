// test/core/widgets/app_bottom_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _opener(WidgetBuilder content, {void Function(Object?)? onResult}) =>
    hostWidget(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final r = await showAppSheet<String>(context, builder: content);
            onResult?.call(r);
          },
          child: const Text('mở'),
        ),
      ),
    );

void main() {
  testWidgets('shows the content in a glass frame with a grab handle', (
    tester,
  ) async {
    await tester.pumpWidget(_opener((_) => const Text('Nội dung')));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung'), findsOneWidget);
    expect(find.byKey(const Key('app-sheet')), findsOneWidget);
    expect(find.byKey(const Key('app-sheet-handle')), findsOneWidget);
  });

  testWidgets('never taller than 88% of the screen, long content scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _opener(
        (_) => ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < 60; i++) ListTile(title: Text('Dòng $i')),
          ],
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('app-sheet'))).height,
      lessThanOrEqualTo(568 * 0.88 + 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pop returns the value; tapping outside returns null', (
    tester,
  ) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      _opener(
        (c) => TextButton(
          onPressed: () => Navigator.of(c).pop('xong'),
          child: const Text('chọn'),
        ),
        onResult: results.add,
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('chọn'));
    await tester.pumpAndSettle();
    expect(results, ['xong']);

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(results, ['xong', null]);
  });

  testWidgets('the handle is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_opener((_) => const Text('Nội dung')));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    // The key is on the ExcludeSemantics itself.
    final excluder = tester.widget(find.byKey(const Key('app-sheet-handle')));
    expect(excluder, isA<ExcludeSemantics>());
    expect((excluder as ExcludeSemantics).excluding, isTrue);
    handle.dispose();
  });

  testWidgets('AppSheetFrame caps at 88 % of the height', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      hostWidget(
        const AppSheetFrame(
          child: SizedBox(
            height: 1000,
            child: Text('Long content'),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('app-sheet'))).height,
      lessThanOrEqualTo(568 * 0.88 + 0.5),
    );
  });

  testWidgets('showAppSheet with canDismiss false ignores the barrier tap', (
    tester,
  ) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final r = await showAppSheet<String>(
                context,
                canDismiss: () => false,
                builder: (c) => const Text('Locked sheet'),
              );
              results.add(r);
            },
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Locked sheet'), findsOneWidget);

    // Tap barrier outside sheet
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Locked sheet'), findsOneWidget);
    expect(results, isEmpty);
  });
}
