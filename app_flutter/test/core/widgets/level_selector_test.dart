import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _stateful({
  int initial = 1,
  bool expertDisabled = false,
  List<int>? log,
}) {
  var level = initial;
  return hostWidget(
    StatefulBuilder(
      builder: (context, setState) => LevelSelector(
        title: 'Chân dung',
        level: level,
        expertDisabled: expertDisabled,
        onChanged: (v) {
          log?.add(v);
          setState(() => level = v);
        },
      ),
    ),
  );
}

void main() {
  testWidgets('shows the genre and the three levels', (tester) async {
    await tester.pumpWidget(_stateful());
    for (final t in ['Chân dung', 'Cơ bản', 'Thành thạo', 'Chuyên sâu']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('a tap reports that level', (tester) async {
    final log = <int>[];
    await tester.pumpWidget(_stateful(log: log));
    await tester.tap(find.text('Chuyên sâu'));
    await tester.pump();
    expect(log, [3]);
  });

  testWidgets(
    'screen readers get "Chân dung, mức Chuyên sâu" and adjust actions',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_stateful(initial: 3));
      final node = find.bySemanticsLabel('Chân dung, mức Chuyên sâu');
      expect(node, findsOneWidget);
      expect(
        tester.getSemantics(node),
        isSemantics(hasDecreaseAction: true, hasIncreaseAction: false),
      );
      await tester.pumpWidget(_stateful(initial: 1));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Chân dung, mức Cơ bản')),
        isSemantics(hasDecreaseAction: false, hasIncreaseAction: true),
      );
      handle.dispose();
    },
  );

  testWidgets('arrow keys step the level once the row has focus', (
    tester,
  ) async {
    final log = <int>[];
    await tester.pumpWidget(_stateful(log: log));
    await tester.tap(find.text('Cơ bản'));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'LevelSelector');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(log, [1, 2, 3, 2]);
  });

  testWidgets(
    'expertDisabled dims Chuyên sâu, explains, still reports the tap',
    (tester) async {
      final handle = tester.ensureSemantics();
      final log = <int>[];
      await tester.pumpWidget(
        _stateful(initial: 2, expertDisabled: true, log: log),
      );
      final style = tester.widget<Text>(find.text('Chuyên sâu')).style!;
      expect(style.color, AppColorsDark.foregroundDisabled);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Chân dung, mức Thành thạo')),
        isSemantics(hint: 'Đã đủ 3 mức Chuyên sâu'),
      );
      await tester.tap(find.text('Chuyên sâu'));
      expect(log, [3]);
      handle.dispose();
    },
  );

  testWidgets('long names wrap; 320dp at 1.3x in both themes; no blur', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        hostWidget(
          LevelSelector(title: 'Bất động sản', level: 2, onChanged: (_) {}),
          width: 320,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('level-option-1'))).height,
        greaterThanOrEqualTo(48),
      );
    }
  });
}
