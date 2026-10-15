// test/core/widgets/hashtag_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('HashtagChip reads tag and count', (tester) async {
    await tester.pumpWidget(
      hostWidget(const HashtagChip(tag: 'PhotoWalkPhoCo1020', count: 48)),
    );
    expect(find.text('#PhotoWalkPhoCo1020'), findsOneWidget);
    expect(find.text('48 bài'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(HashtagChip)),
      matchesSemantics(label: '#PhotoWalkPhoCo1020, 48 bài'),
    );
  });

  testWidgets('a tag with its # is not doubled; no count hides the number', (
    tester,
  ) async {
    await tester.pumpWidget(hostWidget(const HashtagChip(tag: '#Tag1')));
    expect(find.text('#Tag1'), findsOneWidget);
    expect(find.text('##Tag1'), findsNothing);
    expect(find.textContaining('bài'), findsNothing);
  });

  testWidgets('with onTap it is a 48dp button, without it a plain label', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      hostWidget(HashtagChip(tag: 'Tag1', count: 3, onTap: () => taps++)),
    );
    expect(
      tester.getSize(find.byType(HashtagChip)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('#Tag1'));
    expect(taps, 1);
    await tester.pumpWidget(
      hostWidget(const HashtagChip(tag: 'Tag1', count: 3)),
    );
    expect(tester.getSize(find.byType(HashtagChip)).height, lessThan(48));
    expect(
      find.byType(InkWell),
      findsOneWidget,
    ); // the pill's own, with no tap handler
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });

  testWidgets(
    'a long tag shrinks instead of overflowing at 320dp and 1.3 text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        hostWidget(
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: HashtagChip(
              tag: 'MotCaiHashtagRatDaiDeKiemTraTrenManHinhHep1020',
              count: 1234,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
