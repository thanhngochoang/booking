import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

typedef _Change = (VerdictKind?, int);

const _tomatoKey = Key('verdict-tomato');
const _brickKey = Key('verdict-brick');

/// A pad that keeps its own state, the way the review screen does.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.log,
    this.kind,
    this.hits = 0,
    this.compact = false,
    this.enabled = true,
  });
  final List<_Change> log;
  final VerdictKind? kind;
  final int hits;
  final bool compact;
  final bool enabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late VerdictKind? kind = widget.kind;
  late int hits = widget.hits;

  @override
  Widget build(BuildContext context) => VerdictPad(
    kind: kind,
    hits: hits,
    compact: widget.compact,
    enabled: widget.enabled,
    onChanged: (k, h) {
      widget.log.add((k, h));
      setState(() {
        kind = k;
        hits = h;
      });
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<_Change> log, {
  VerdictKind? kind,
  int hits = 0,
  bool compact = false,
  bool enabled = true,
  double width = 390,
}) => tester.pumpWidget(
  hostWidget(
    _Harness(
      log: log,
      kind: kind,
      hits: hits,
      compact: compact,
      enabled: enabled,
    ),
    width: width,
  ),
);

List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
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
  return calls;
}

void _act(WidgetTester tester, String label, SemanticsAction action) =>
    tester.semantics.performAction(find.semantics.byLabel(label), action);

Future<void> _tap(WidgetTester tester, Key key, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('taps', () {
    testWidgets('first tap on tomato selects tomato ×1', (tester) async {
      final log = <_Change>[];
      await _pump(tester, log);
      await _tap(tester, _tomatoKey);
      expect(log, [(VerdictKind.tomato, 1)]);
    });

    testWidgets('each tap on the selected side adds one hit', (tester) async {
      final log = <_Change>[];
      await _pump(tester, log);
      await _tap(tester, _brickKey, 4);
      expect(log.map((c) => c.$2), [1, 2, 3, 4]);
      expect(log.every((c) => c.$1 == VerdictKind.brick), isTrue);
    });

    testWidgets('the 11th tap changes nothing', (tester) async {
      final log = <_Change>[];
      await _pump(tester, log);
      await _tap(tester, _tomatoKey, 11);
      expect(log.length, 10);
      expect(log.last, (VerdictKind.tomato, 10));
    });

    testWidgets('tapping the other side resets to that side ×1', (
      tester,
    ) async {
      final log = <_Change>[];
      await _pump(tester, log, kind: VerdictKind.tomato, hits: 7);
      await _tap(tester, _brickKey);
      expect(log, [(VerdictKind.brick, 1)]);
    });

    testWidgets('the selected side shows ×n, the other shows no count', (
      tester,
    ) async {
      await _pump(tester, [], kind: VerdictKind.tomato, hits: 3);
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('Hài lòng'), findsOneWidget);
      expect(find.text('Chưa hài lòng'), findsOneWidget);
      expect(find.textContaining('×'), findsOneWidget);
    });

    testWidgets('a disabled pad ignores taps', (tester) async {
      final log = <_Change>[];
      await _pump(tester, log, enabled: false);
      await _tap(tester, _tomatoKey);
      expect(log, isEmpty);
    });
  });

  group('haptics', () {
    testWidgets('light on each hit, heavier at 10', (tester) async {
      final calls = _haptics(tester);
      await _pump(tester, [], kind: VerdictKind.tomato, hits: 8);
      await _tap(tester, _tomatoKey); // 9
      await _tap(tester, _tomatoKey); // 10
      await _tap(tester, _tomatoKey); // 11th: nothing
      expect(calls, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    testWidgets('switching side gives a light impact', (tester) async {
      final calls = _haptics(tester);
      await _pump(tester, [], kind: VerdictKind.tomato, hits: 5);
      await _tap(tester, _brickKey);
      expect(calls, ['HapticFeedbackType.lightImpact']);
    });
  });

  group('semantics', () {
    testWidgets('each side is a slider labelled with its count', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [], kind: VerdictKind.tomato, hits: 3);
      for (final (label, key) in [
        ('Ném cà chua, 3 trên 10', _tomatoKey),
        ('Ném gạch, 0 trên 10', _brickKey),
      ]) {
        expect(
          tester.getSemantics(find.byKey(key)),
          matchesSemantics(
            label: label,
            isSlider: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
            hasIncreaseAction: true,
            hasDecreaseAction: true,
          ),
        );
      }
      handle.dispose();
    });

    testWidgets('increase and decrease change hits by one without a tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <_Change>[];
      await _pump(tester, log, kind: VerdictKind.tomato, hits: 3);
      _act(tester, 'Ném cà chua, 3 trên 10', SemanticsAction.increase);
      await tester.pumpAndSettle();
      _act(tester, 'Ném cà chua, 4 trên 10', SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(log, [(VerdictKind.tomato, 4), (VerdictKind.tomato, 3)]);
      handle.dispose();
    });

    testWidgets('increase on the empty side selects it at ×1', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <_Change>[];
      await _pump(tester, log);
      _act(tester, 'Ném gạch, 0 trên 10', SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(log, [(VerdictKind.brick, 1)]);
      handle.dispose();
    });

    testWidgets('decrease at 1 clears the side', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <_Change>[];
      await _pump(tester, log, kind: VerdictKind.brick, hits: 1);
      _act(tester, 'Ném gạch, 1 trên 10', SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(log, [(null, 0)]);
      handle.dispose();
    });

    testWidgets('increase at 10 and decrease on the other side do nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <_Change>[];
      await _pump(tester, log, kind: VerdictKind.tomato, hits: 10);
      _act(tester, 'Ném cà chua, 10 trên 10', SemanticsAction.increase);
      _act(tester, 'Ném gạch, 0 trên 10', SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      handle.dispose();
    });

    testWidgets('a disabled pad exposes no actions', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [], enabled: false);
      final data = tester
          .getSemantics(find.byKey(_tomatoKey))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });
  });

  group('motion', () {
    testWidgets('the bounce runs once per tap and settles', (tester) async {
      await _pump(tester, []);
      await tester.tap(find.byKey(_tomatoKey));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      final frames = await tester.pumpAndSettle();
      expect(frames, lessThan(30));
      await expectIdle(tester);
    });

    testWidgets('a pad at rest schedules no frames', (tester) async {
      await _pump(tester, [], kind: VerdictKind.brick, hits: 6);
      await expectIdle(tester);
    });
  });

  group('layout', () {
    testWidgets('tap targets are at least 48 dp, compact too', (tester) async {
      for (final compact in [false, true]) {
        await _pump(tester, [], compact: compact, width: 320);
        for (final key in [_tomatoKey, _brickKey]) {
          final size = tester.getSize(find.byKey(key));
          expect(
            size.height,
            greaterThanOrEqualTo(48),
            reason: '$compact $key',
          );
          expect(size.width, greaterThanOrEqualTo(48));
        }
      }
    });

    testWidgets('compact puts icon, label and hits on one row', (tester) async {
      await _pump(
        tester,
        [],
        kind: VerdictKind.tomato,
        hits: 8,
        compact: true,
        width: 340,
      );
      final icon = tester.getCenter(
        find.descendant(
          of: find.byKey(_tomatoKey),
          matching: find.byType(VerdictIcon),
        ),
      );
      final label = tester.getCenter(find.text('Hài lòng'));
      final hits = tester.getCenter(find.text('×8'));
      expect((icon.dy - label.dy).abs(), lessThan(2));
      expect((hits.dy - label.dy).abs(), lessThan(2));
      expect(icon.dx, lessThan(label.dx));
      expect(label.dx, lessThan(hits.dx));
    });

    testWidgets('the regular pad draws the hit label inside its button', (
      tester,
    ) async {
      for (final (kind, key) in [
        (VerdictKind.tomato, _tomatoKey),
        (VerdictKind.brick, _brickKey),
      ]) {
        await tester.pumpWidget(const SizedBox()); // drop the harness state
        await _pump(tester, [], kind: kind, hits: 10);
        final button = tester.getRect(find.byKey(key));
        final hit = tester.getRect(find.text('×10'));
        expect(button.contains(hit.topLeft), isTrue, reason: '$kind topLeft');
        expect(
          button.contains(hit.bottomRight),
          isTrue,
          reason: '$kind bottomRight',
        );
        // Mock .vbtn .hit: top 8, right 11 from the border box.
        expect(hit.top - button.top, inInclusiveRange(4, 10));
        expect(button.right - hit.right, inInclusiveRange(9, 13));
      }
    });

    testWidgets(
      'the compact brick label is "Chưa ưng", the regular one is not',
      (tester) async {
        await _pump(tester, [], compact: true);
        expect(find.text('Chưa ưng'), findsOneWidget);
        expect(find.text('Chưa hài lòng'), findsNothing);
        await _pump(tester, []);
        expect(find.text('Chưa hài lòng'), findsOneWidget);
        expect(find.text('Chưa ưng'), findsNothing);
      },
    );

    testWidgets('the regular pad stacks the label under the icon', (
      tester,
    ) async {
      await _pump(tester, [], kind: VerdictKind.tomato, hits: 8);
      final icon = tester.getCenter(
        find.descendant(
          of: find.byKey(_tomatoKey),
          matching: find.byType(VerdictIcon),
        ),
      );
      expect(
        tester.getCenter(find.text('Hài lòng')).dy,
        greaterThan(icon.dy + 10),
      );
    });

    testWidgets('fits 320 wide at text scale 1.3 without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostWidget(
          VerdictPad(
            kind: VerdictKind.brick,
            hits: 10,
            onChanged: (_, _) {},
            compact: true,
          ),
          width: 320,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('VerdictLevel', () {
    Future<void> pumpLevel(
      WidgetTester tester,
      VerdictKind kind,
      int hits, {
      VoidCallback? onReset,
    }) => tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) => VerdictLevel(
            kind: kind,
            hits: hits,
            label: verdictLevelLabel(context.l10n, kind, hits),
            onReset: onReset ?? () {},
          ),
        ),
      ),
    );

    testWidgets('showHint false drops the tap hint and keeps the rest', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostWidget(
          Builder(
            builder: (context) => VerdictLevel(
              kind: VerdictKind.brick,
              hits: 3,
              label: 'Chưa ưng',
              onReset: () {},
              showHint: false,
            ),
          ),
        ),
      );
      expect(find.text('Chạm tiếp để tăng mức độ, tối đa 10'), findsNothing);
      expect(find.text('Chưa ưng'), findsOneWidget);
      expect(find.text('Làm lại'), findsOneWidget);
      expect(find.byKey(const Key('verdict-track')), findsOneWidget);
    });

    testWidgets('labels by hits', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        hostWidget(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final l = ctx.l10n;
      final tomato = {
        1: 'Ổn',
        2: 'Ổn',
        3: 'Hài lòng',
        5: 'Hài lòng',
        6: 'Rất hài lòng',
        9: 'Rất hài lòng',
        10: 'Tuyệt vời!',
      };
      for (final e in tomato.entries) {
        expect(
          verdictLevelLabel(l, VerdictKind.tomato, e.key),
          e.value,
          reason: 'tomato ${e.key}',
        );
      }
      final brick = {
        1: 'Hơi tiếc',
        2: 'Hơi tiếc',
        3: 'Chưa ưng',
        5: 'Chưa ưng',
        6: 'Thất vọng',
        9: 'Thất vọng',
        10: 'Rất thất vọng',
      };
      for (final e in brick.entries) {
        expect(
          verdictLevelLabel(l, VerdictKind.brick, e.key),
          e.value,
          reason: 'brick ${e.key}',
        );
      }
    });

    testWidgets('shows the label, the hint and "Làm lại"', (tester) async {
      await pumpLevel(tester, VerdictKind.tomato, 7);
      expect(find.text('Rất hài lòng'), findsOneWidget);
      expect(find.text('Làm lại'), findsOneWidget);
      expect(find.text('Chạm tiếp để tăng mức độ, tối đa 10'), findsOneWidget);
    });

    testWidgets('track width is intensity (7 hits → 0.91)', (tester) async {
      await pumpLevel(tester, VerdictKind.tomato, 7);
      final fill = tester.widget<FractionallySizedBox>(
        find.byKey(const Key('verdict-track-fill')),
      );
      expect(fill.widthFactor, 0.91);
      final track = tester.getSize(find.byKey(const Key('verdict-track')));
      final filled = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('verdict-track-fill')),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(filled.width / track.width, closeTo(0.91, 0.001));
    });

    testWidgets('the fill uses the side colour', (tester) async {
      await pumpLevel(tester, VerdictKind.brick, 3);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(const Key('verdict-track-fill')),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).color, AppColorsDark.brick);
    });

    testWidgets('"Làm lại" calls onReset', (tester) async {
      var resets = 0;
      await pumpLevel(tester, VerdictKind.brick, 3, onReset: () => resets++);
      await tester.tap(find.text('Làm lại'));
      expect(resets, 1);
    });
  });

  group('goldens', () {
    for (final b in Brightness.values) {
      for (final (name, kind, hits) in [
        ('tomato_3', VerdictKind.tomato, 3),
        ('brick_10', VerdictKind.brick, 10),
      ]) {
        testWidgets('VerdictPad $name, ${b.name}', tags: ['golden'], (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(390, 200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            hostWidget(
              RepaintBoundary(
                key: const Key('golden'),
                child: Container(
                  color: b == Brightness.dark
                      ? AppColorsDark.background
                      : AppColors.background,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 358,
                        child: _Harness(log: const [], kind: kind, hits: hits),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 358,
                        child: _Harness(
                          log: const [],
                          kind: kind,
                          hits: hits,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              brightness: b,
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(const Key('golden')),
            matchesGoldenFile('goldens/verdict_pad_${name}_${b.name}.png'),
          );
        });
      }
    }
  });
}
