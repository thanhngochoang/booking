// test/core/widgets/match_overlay_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _body = 'Lan Anh đang chờ ở Công viên Tao Đàn. Tiếp tục để xem đường đi.';

class _Run {
  int continued = 0;
  final haptics = <String>[];
}

Future<_Run> _pump(
  WidgetTester tester, {
  bool reducedMotion = false,
  double width = 390,
  double textScale = 1.0,
}) async {
  final run = _Run();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        run.haptics.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.pumpWidget(
    hostWidget(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: SizedBox(
            height: 700,
            child: MatchOverlay(
              name: 'Lan Anh',
              body: _body,
              onContinue: () => run.continued++,
            ),
          ),
        ),
      ),
      width: width,
      textScale: textScale,
    ),
  );
  return run;
}

double _textOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(const Key('match-text'))).opacity;

void main() {
  testWidgets(
    'reduced motion shows the final frame with name and body at once',
    (tester) async {
      final run = await _pump(tester, reducedMotion: true);

      expect(
        find.text('Đã match với Lan Anh', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(_body), findsOneWidget);
      expect(_textOpacity(tester), 1);
      // Nothing animates, no flash, no haptic.
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(run.haptics, isEmpty);
    },
  );

  testWidgets('animates: text after the drawing, one haptic at the flash', (
    tester,
  ) async {
    final run = await _pump(tester);

    expect(_textOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 1700));
    expect(run.haptics, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(run.haptics, ['HapticFeedbackType.lightImpact']);
    await tester.pump(const Duration(milliseconds: 800));
    expect(_textOpacity(tester), 1);
    expect(run.haptics, hasLength(1));
  });

  testWidgets('"Tiếp tục" calls onContinue once', (tester) async {
    final run = await _pump(tester);

    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump(const Duration(seconds: 4));

    expect(run.continued, 1);
  });

  testWidgets('auto-continues after 3 s', (tester) async {
    final run = await _pump(tester);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(run.continued, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(run.continued, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(run.continued, 1);
  });

  testWidgets('tap skips to the last frame', (tester) async {
    final run = await _pump(tester);

    await tester.pump(const Duration(milliseconds: 200));
    expect(_textOpacity(tester), 0);
    await tester.tap(find.byKey(const Key('match-camera')));
    await tester.pump();

    expect(_textOpacity(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);
    // Skipping is not continuing, and skips the flash.
    expect(run.continued, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(run.haptics, isEmpty);
  });

  testWidgets('no timer left after dispose', (tester) async {
    final run = await _pump(tester);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    expect(run.continued, 0);
  });

  testWidgets('semantics live region reads "Đã match với Lan Anh"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, reducedMotion: true);

    final node = tester.getSemantics(
      find.bySemanticsLabel('Đã match với Lan Anh'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('fits 320dp at 1.3× text', (tester) async {
    await _pump(tester, reducedMotion: true, width: 320, textScale: 1.3);

    expect(tester.takeException(), isNull);
    final camera = tester.getSize(find.byKey(const Key('match-camera')));
    // Mock `.mcam`: min(240, 78%) wide, 420:250.
    expect(camera.width, lessThanOrEqualTo(240));
    expect(camera.width / camera.height, closeTo(420 / 250, 0.01));
  });
}
