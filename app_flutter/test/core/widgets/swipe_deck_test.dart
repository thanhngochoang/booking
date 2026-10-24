import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/screen_host.dart';

/// Records what the deck reported.
class _Log {
  final liked = <String>[];
  final skipped = <String>[];
  var undone = 0;
  var emptied = 0;
}

const _like = Key('swipe-like');
const _skip = Key('swipe-skip');
const _undo = Key('swipe-undo');

Finder _card(String id) => find.byKey(Key('card-$id'));

/// A 360 × 600 deck of [items]; [reduceMotion] sets `disableAnimations`.
Future<_Log> _pumpDeck(
  WidgetTester tester, {
  List<String> items = const ['a', 'b', 'c', 'd'],
  bool reduceMotion = false,
  int initialIndex = 0,
  int initialUndoDepth = 0,
  _Log? into,
}) async {
  final log = into ?? _Log();
  await tester.pumpWidget(
    screenApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 600,
                child: SwipeDeck<String>(
                  items: items,
                  cardBuilder: (_, id) => ColoredBox(
                    key: Key('card-$id'),
                    color: Colors.blueGrey,
                    child: Center(child: Text('card $id')),
                  ),
                  onLike: log.liked.add,
                  onSkip: log.skipped.add,
                  onUndo: () => log.undone++,
                  onEmpty: () => log.emptied++,
                  likeStampLabel: 'CHỌN',
                  likeLabel: 'Chọn',
                  skipLabel: 'Bỏ qua',
                  undoLabel: 'Hoàn tác',
                  initialIndex: initialIndex,
                  initialUndoDepth: initialUndoDepth,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return log;
}

/// The card on top: the last one painted (the deck paints the farthest first).
bool _onTop(WidgetTester tester, String id) =>
    tester
        .widgetList(find.byType(ColoredBox))
        .whereType<ColoredBox>()
        .where((b) {
          final k = b.key;
          return k is ValueKey<String> && k.value.startsWith('card-');
        })
        .lastOrNull
        ?.key ==
    Key('card-$id');

/// Lets a fly-out or snap-back run to its end (its first frame starts it).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('drag right past 30% likes, left skips, short drag snaps back', (
    tester,
  ) async {
    final log = await _pumpDeck(tester);
    expect(_onTop(tester, 'a'), isTrue);

    // Slow drags (no fling): only the distance decides. 30% of 360 = 108.
    await tester.timedDrag(
      _card('a'),
      const Offset(200, 0),
      const Duration(milliseconds: 800),
    );
    await _settle(tester);
    expect(log.liked, ['a']);
    expect(_onTop(tester, 'b'), isTrue);

    await tester.timedDrag(
      _card('b'),
      const Offset(-200, 0),
      const Duration(milliseconds: 800),
    );
    await _settle(tester);
    expect(log.skipped, ['b']);
    expect(_onTop(tester, 'c'), isTrue);

    await tester.timedDrag(
      _card('c'),
      const Offset(60, 0),
      const Duration(milliseconds: 800),
    );
    await _settle(tester);
    expect(log.liked, ['a']);
    expect(log.skipped, ['b']);
    expect(_onTop(tester, 'c'), isTrue);
    // Back in place.
    expect(
      tester.getCenter(_card('c')).dx,
      moreOrLessEquals(
        tester.getCenter(find.byType(SwipeDeck<String>)).dx,
        epsilon: 1,
      ),
    );
  });

  testWidgets('a fast short fling likes too', (tester) async {
    final log = await _pumpDeck(tester);
    await tester.fling(_card('a'), const Offset(60, 0), 1500);
    await _settle(tester);
    expect(log.liked, ['a']);
  });

  testWidgets('♥ and ✕ buttons give the same results as the gestures', (
    tester,
  ) async {
    final log = await _pumpDeck(tester);
    await tester.tap(find.byKey(_like));
    await _settle(tester);
    expect(log.liked, ['a']);
    expect(_onTop(tester, 'b'), isTrue);

    await tester.tap(find.byKey(_skip));
    await _settle(tester);
    expect(log.skipped, ['b']);
    expect(_onTop(tester, 'c'), isTrue);
  });

  testWidgets('a second tap while a card flies away is ignored', (
    tester,
  ) async {
    final log = await _pumpDeck(tester);
    await tester.tap(find.byKey(_like));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(_like), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(log.liked, ['a']);
  });

  testWidgets('Hoàn tác restores the last card and calls onUndo', (
    tester,
  ) async {
    final log = await _pumpDeck(tester, reduceMotion: true);
    // Nothing to undo yet: the button is there but does nothing.
    await tester.tap(find.byKey(_undo));
    await tester.pump();
    expect(log.undone, 0);

    await tester.tap(find.byKey(_skip));
    await tester.pump();
    await tester.tap(find.byKey(_like));
    await tester.pump();
    expect(_onTop(tester, 'c'), isTrue);

    await tester.tap(find.byKey(_undo));
    await tester.pump();
    expect(log.undone, 1);
    expect(_onTop(tester, 'b'), isTrue);

    await tester.tap(find.byKey(_undo));
    await tester.pump();
    expect(log.undone, 2);
    expect(_onTop(tester, 'a'), isTrue);
  });

  testWidgets('stamp "CHỌN" appears while dragging right', (tester) async {
    await _pumpDeck(tester);
    expect(find.text('CHỌN'), findsNothing);

    final left = await tester.startGesture(tester.getCenter(_card('a')));
    await left.moveBy(const Offset(-20, 0));
    await left.moveBy(const Offset(-30, 0));
    await left.moveBy(const Offset(-50, 0));
    await tester.pump();
    expect(find.text('CHỌN'), findsNothing);
    await left.up();
    await _settle(tester);

    final right = await tester.startGesture(tester.getCenter(_card('a')));
    // The first moves only win the drag (pan slop); the last one shows.
    await right.moveBy(const Offset(20, 0));
    await right.moveBy(const Offset(30, 0));
    await right.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(find.text('CHỌN'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('CHỌN'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, greaterThan(0));
    expect(opacity.opacity, lessThan(1));
    await right.up();
    await _settle(tester);
  });

  testWidgets('reduced motion: no fly-out, next card at once', (tester) async {
    final log = await _pumpDeck(tester, reduceMotion: true);
    await tester.tap(find.byKey(_like));
    await tester.pump();
    expect(log.liked, ['a']);
    expect(_onTop(tester, 'b'), isTrue);

    await tester.timedDrag(
      _card('b'),
      const Offset(-200, 0),
      const Duration(milliseconds: 800),
    );
    await tester.pump();
    expect(log.skipped, ['b']);
    expect(_onTop(tester, 'c'), isTrue);
  });

  testWidgets('buttons are ≥ 48dp and labelled Chọn / Bỏ qua / Hoàn tác', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpDeck(tester);
    for (final (key, label) in [
      (_like, 'Chọn'),
      (_skip, 'Bỏ qua'),
      (_undo, 'Hoàn tác'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
      expect(
        tester.getSemantics(find.byKey(key)),
        isSemantics(label: label, isButton: true),
      );
    }
    // Mock `.sacts .ra`: ♥ and ✕ are 56dp.
    expect(tester.getSize(find.byKey(_like)), const Size(56, 56));
    expect(tester.getSize(find.byKey(_skip)), const Size(56, 56));
    semantics.dispose();
  });

  testWidgets('onEmpty after the last card', (tester) async {
    final log = await _pumpDeck(tester, items: const ['a', 'b']);
    await tester.tap(find.byKey(_like));
    await _settle(tester);
    expect(log.emptied, 0);
    await tester.tap(find.byKey(_skip));
    await _settle(tester);
    expect(log.emptied, 1);
    expect(_card('a'), findsNothing);
    expect(_card('b'), findsNothing);
    // Nothing left to swipe: ♥ does nothing.
    await tester.tap(find.byKey(_like));
    await _settle(tester);
    expect(log.liked, ['a']);
    expect(log.emptied, 1);
  });

  testWidgets('shows up to three cards, nearest on top', (tester) async {
    await _pumpDeck(tester);
    expect(_card('a'), findsOneWidget);
    expect(_card('b'), findsOneWidget);
    expect(_card('c'), findsOneWidget);
    expect(_card('d'), findsNothing);
  });

  testWidgets('a rebuilt deck can still undo what it was told', (tester) async {
    final log = await _pumpDeck(
      tester,
      reduceMotion: true,
      initialIndex: 2,
      initialUndoDepth: 1,
    );
    expect(_onTop(tester, 'c'), isTrue);
    await tester.tap(find.byKey(_undo));
    await tester.pump();
    expect(_onTop(tester, 'b'), isTrue);
    expect(log.undone, 1);
    // 'a' was answered before the history the deck was given.
    await tester.tap(find.byKey(_undo));
    await tester.pump();
    expect(_onTop(tester, 'b'), isTrue);
    expect(log.undone, 1);
  });

  testWidgets('fewer items while a card flies away: no crash, no callback', (
    tester,
  ) async {
    final log = await _pumpDeck(tester, items: const ['a', 'b', 'c']);
    await tester.tap(find.byKey(_skip));
    await _settle(tester);
    await tester.tap(find.byKey(_like));
    await tester.pump(const Duration(milliseconds: 50));
    // Same deck, now only one item: the flying card ('b') is gone.
    await _pumpDeck(tester, items: const ['a'], into: log);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(log.liked, isEmpty);
    expect(log.skipped, ['a']);
    // The deck kept its place: past the only item.
    expect(_card('a'), findsNothing);
  });

  testWidgets('no ticker left after dispose', (tester) async {
    final log = await _pumpDeck(tester);
    await tester.tap(find.byKey(_like));
    await tester.pump(const Duration(milliseconds: 50));
    // Mid-flight: the screen goes away.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
    expect(log.liked, isEmpty);
  });
}
