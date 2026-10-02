// test/core/widgets/contact_dial_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

const _all = [
  ContactChannel.call,
  ContactChannel.zalo,
  ContactChannel.whatsapp,
];
const _button = Key('contact-dial-button');
const _tray = Key('contact-tray');

/// Puts the dial near the right edge and low on the screen, so the tray has
/// room above it.
Future<void> _pump(
  WidgetTester tester, {
  ContactAccess access = ContactAccess.unlocked,
  List<ContactChannel> channels = _all,
  ValueChanged<ContactChannel>? onSelected,
  ContactDialStyle style = ContactDialStyle.icon,
  bool busy = false,
  bool reduced = false,
  double width = 390,
  double textScale = 1.0,
  double top = 300,
  Brightness brightness = Brightness.dark,
  Widget? sibling,
}) async {
  Widget dial = ContactDial(
    access: access,
    channels: channels,
    onSelected: onSelected ?? (_) {},
    style: style,
    busy: busy,
  );
  if (reduced) {
    final inner = dial;
    dial = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  await tester.pumpWidget(
    hostWidget(
      Padding(
        padding: EdgeInsets.only(top: top, left: width - 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [dial, ?sibling],
        ),
      ),
      width: width,
      textScale: textScale,
      brightness: brightness,
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_button));
  await tester.pumpAndSettle();
}

double _opacityOf(WidgetTester tester, Key key) =>
    tester.widget<Opacity>(find.byKey(key)).opacity;

List<double> _itemOpacities(WidgetTester tester) => [
  for (final c in ['call', 'zalo', 'whatsapp'])
    _opacityOf(tester, Key('contact-item-fade-$c')),
];

Border _itemBorder(WidgetTester tester, String code) {
  final circle = find.descendant(
    of: find.byKey(Key('contact-$code')),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    ),
  );
  return (tester.widget<Container>(circle).decoration! as BoxDecoration).border!
      as Border;
}

void main() {
  group('focus ring', () {
    tearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    testWidgets('a touch open shows no focus ring on any entry', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await _pump(tester);
      await _open(tester);
      final outline = Theme.of(tester.element(find.byKey(_tray)))
          .colorScheme
          .outlineVariant;
      for (final c in ['call', 'zalo', 'whatsapp']) {
        final side = _itemBorder(tester, c).top;
        expect(side.color, outline, reason: c);
        expect(side.width, 1, reason: c);
      }
    });

    testWidgets('a keyboard open rings the first entry', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await _pump(tester);
      await _open(tester);
      expect(_itemBorder(tester, 'call').top.width, 2);
      expect(_itemBorder(tester, 'zalo').top.width, 1);
    });
  });

  group('resting state', () {
    testWidgets('only the small button is visible, no channel names', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byKey(_button), findsOneWidget);
      expect(find.byKey(_tray), findsNothing);
      expect(find.text('Zalo'), findsNothing);
      expect(tester.getSize(find.byKey(_button)), const Size(48, 48));
    });

    testWidgets('labeled style is a 44dp hit area showing "Liên hệ"', (
      tester,
    ) async {
      await _pump(tester, style: ContactDialStyle.labeled);
      expect(find.text('Liên hệ'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(_button)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('no outside channel at all: nothing is drawn', (tester) async {
      await _pump(tester, channels: const []);
      expect(find.byKey(_button), findsNothing);
      await _pump(tester, channels: const [ContactChannel.inApp]);
      expect(find.byKey(_button), findsNothing);
    });
  });

  group('locked: only the inquiry chat', () {
    testWidgets('tap opens the inquiry directly and never expands', (
      tester,
    ) async {
      final picked = <ContactChannel>[];
      await _pump(tester, access: ContactAccess.locked, onSelected: picked.add);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.inApp]);
      expect(find.byKey(_tray), findsNothing);
      expect(find.text('Zalo'), findsNothing);
    });

    testWidgets('it is labelled "Nhắn tin hỏi trước" with the unlock hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        access: ContactAccess.locked,
        channels: const [ContactChannel.call],
      );
      expect(find.bySemanticsLabel('Nhắn tin hỏi trước'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(_button)).hint,
        'Liên hệ qua điện thoại mở sau khi bạn đặt lịch',
      );
      handle.dispose();
    });

    testWidgets('labeled style shows the inquiry text', (tester) async {
      await _pump(
        tester,
        access: ContactAccess.locked,
        style: ContactDialStyle.labeled,
      );
      expect(find.text('Nhắn tin hỏi trước'), findsOneWidget);
    });
  });

  group('single channel', () {
    testWidgets('tap goes straight to that channel, no tray', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(
        tester,
        channels: const [ContactChannel.zalo],
        onSelected: picked.add,
      );
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.zalo]);
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('in-app in the list is ignored once unlocked', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(
        tester,
        channels: const [ContactChannel.inApp, ContactChannel.call],
        onSelected: picked.add,
      );
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.call]);
    });
  });

  group('expanding', () {
    testWidgets(
      'tap shows Gọi điện, Zalo, WhatsApp left to right with text labels',
      (tester) async {
        await _pump(tester);
        await _open(tester);
        expect(find.byKey(_tray), findsOneWidget);
        final xs = [
          for (final k in ['contact-call', 'contact-zalo', 'contact-whatsapp'])
            tester.getCenter(find.byKey(Key(k))).dx,
        ];
        expect(xs[0], lessThan(xs[1]));
        expect(xs[1], lessThan(xs[2]));
        for (final t in ['Gọi điện', 'Zalo', 'WhatsApp']) {
          expect(find.text(t), findsOneWidget);
        }
      },
    );

    testWidgets('only the switched-on channels are listed', (tester) async {
      await _pump(
        tester,
        channels: const [ContactChannel.call, ContactChannel.whatsapp],
      );
      await _open(tester);
      expect(find.byKey(const Key('contact-zalo')), findsNothing);
      expect(find.byKey(const Key('contact-whatsapp')), findsOneWidget);
    });

    testWidgets(
      'it opens upward, right-aligned, without moving or covering anything',
      (tester) async {
        await _pump(
          tester,
          sibling: const SizedBox(key: Key('below'), width: 100, height: 52),
        );
        final button = tester.getRect(find.byKey(_button));
        final below = tester.getRect(find.byKey(const Key('below')));
        await _open(tester);
        final tray = tester.getRect(find.byKey(_tray));
        expect(tray.bottom, lessThanOrEqualTo(button.top));
        expect(tray.right, closeTo(button.right, 1));
        expect(tester.getRect(find.byKey(_button)), button);
        expect(tester.getRect(find.byKey(const Key('below'))), below);
      },
    );

    testWidgets('with no room above it opens downward', (tester) async {
      await _pump(tester, top: 0);
      await _open(tester);
      final button = tester.getRect(find.byKey(_button));
      final tray = tester.getRect(find.byKey(_tray));
      expect(tray.top, greaterThanOrEqualTo(button.bottom));
    });

    testWidgets('the button turns primary while open', (tester) async {
      await _pump(tester);
      Color? border() {
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(_button),
                matching: find.byType(Container),
              )
              .first,
        );
        return ((box.decoration! as BoxDecoration).border! as Border).top.color;
      }

      final resting = border();
      await _open(tester);
      expect(border(), isNot(resting));
      expect(
        border(),
        Theme.of(tester.element(find.byKey(_button))).colorScheme.primary,
      );
    });

    testWidgets('picking an entry reports it and closes', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(tester, onSelected: picked.add);
      await _open(tester);
      await tester.tap(find.byKey(const Key('contact-whatsapp')));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.whatsapp]);
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('a light tap on opening gives selection haptic feedback', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester);
      await _open(tester);
      expect(
        calls
            .where((c) => c.method == 'HapticFeedback.vibrate')
            .map((c) => c.arguments),
        contains('HapticFeedbackType.selectionClick'),
      );
    });
  });

  group('animation', () {
    testWidgets('fades in over 240ms with the right-most entry first', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byKey(_button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final trayOpacity = _opacityOf(tester, const Key('contact-tray-fade'));
      expect(trayOpacity, greaterThan(0));
      final o = _itemOpacities(tester); // left to right: call, zalo, whatsapp
      expect(o[2], greaterThan(o[1]));
      expect(o[1], greaterThan(o[0]));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, const Key('contact-tray-fade')), 1.0);
    });

    testWidgets(
      'closing is faster than opening (done within 150ms) and has no stagger',
      (tester) async {
        await _pump(tester);
        await _open(tester);
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();
        expect(find.byKey(_tray), findsNothing);
      },
    );

    testWidgets('reduced motion shows and hides instantly', (tester) async {
      await _pump(tester, reduced: true);
      await tester.tap(find.byKey(_button));
      await tester.pump(); // one frame, no settling
      expect(find.byKey(_tray), findsOneWidget);
      expect(_opacityOf(tester, const Key('contact-tray-fade')), 1.0);
      expect(_itemOpacities(tester), [1.0, 1.0, 1.0]);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.byKey(_tray), findsNothing);
    });
  });

  group('interruptions', () {
    testWidgets('closing mid-open continues smoothly, no jump', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final before = _opacityOf(tester, const Key('contact-tray-fade'));
      final item = tester.getCenter(find.byKey(const Key('contact-zalo')));
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 16));
      final after = _opacityOf(tester, const Key('contact-tray-fade'));
      expect(before - after, lessThan(0.25));
      expect(item, isNotNull);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping the button during the close reopens the tray', (
      tester,
    ) async {
      await _pump(tester);
      await _open(tester);
      final at = tester.getCenter(find.byKey(_button));
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsOneWidget);
      expect(_opacityOf(tester, const Key('contact-tray-fade')), 1.0);
    });

    testWidgets('becoming locked while open leaves nothing tappable', (
      tester,
    ) async {
      final picked = <ContactChannel>[];
      await _pump(tester, onSelected: picked.add);
      await _open(tester);
      final zalo = tester.getCenter(find.byKey(const Key('contact-zalo')));
      await _pump(tester, access: ContactAccess.locked, onSelected: picked.add);
      await tester.pump();
      await tester.tapAt(zalo);
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
    });
  });

  group('closing', () {
    testWidgets('tap outside', (tester) async {
      await _pump(tester);
      await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('tapping the button again', (tester) async {
      await _pump(tester);
      await _open(tester);
      await tester.tap(
        find.byKey(_button),
        warnIfMissed: false,
      ); // the scrim takes the tap
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('system Back closes the tray and keeps the screen', (
      tester,
    ) async {
      await _pump(tester);
      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsNothing);
      expect(find.byKey(_button), findsOneWidget);
    });

    testWidgets('Esc closes it and returns focus to the button', (
      tester,
    ) async {
      await _pump(tester);
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'ContactDial button',
      );
    });
  });

  group('keyboard and accessibility', () {
    testWidgets('focus lands on the first entry, Tab walks in display order', (
      tester,
    ) async {
      await _pump(tester);
      await _open(tester);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'ContactDial item 0',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'ContactDial item 1',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'ContactDial item 2',
      );
    });

    testWidgets('Enter on the focused entry selects it', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(tester, onSelected: picked.add);
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.zalo]);
    });

    testWidgets('the button is a labelled button that reports expanded', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(find.bySemanticsLabel('Liên hệ'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(_button)),
        isSemantics(
          label: 'Liên hệ',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
        ),
      );
      await _open(tester);
      expect(
        tester.getSemantics(find.byKey(_button)),
        isSemantics(
          label: 'Liên hệ',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('every entry is at least 44dp and 8dp from its neighbour', (
      tester,
    ) async {
      await _pump(tester);
      await _open(tester);
      final rects = [
        for (final k in ['contact-call', 'contact-zalo', 'contact-whatsapp'])
          tester.getRect(find.byKey(Key(k))),
      ];
      for (final r in rects) {
        expect(r.width, greaterThanOrEqualTo(44));
        expect(r.height, greaterThanOrEqualTo(44));
      }
      expect(rects[1].left - rects[0].right, greaterThanOrEqualTo(8));
      expect(rects[2].left - rects[1].right, greaterThanOrEqualTo(8));
    });

    testWidgets(
      'Zalo and WhatsApp use the brand glyph files, labelled by text',
      (tester) async {
        await _pump(tester);
        await _open(tester);
        expect(find.byType(SvgPicture), findsNWidgets(2));
        final handle = tester.ensureSemantics();
        await tester.pump();
        expect(
          tester.getSemantics(find.byKey(const Key('contact-zalo'))),
          isSemantics(label: 'Zalo', isButton: true, hasTapAction: true),
        );
        for (final k in ['contact-call', 'contact-whatsapp']) {
          expect(
            tester.getSemantics(find.byKey(Key(k))),
            isSemantics(isButton: true, hasTapAction: true),
          );
        }
        handle.dispose();
      },
    );
  });

  group('semantics actions', () {
    testWidgets('the screen-reader tap action selects the entry', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final picked = <ContactChannel>[];
      await _pump(tester, onSelected: picked.add);
      await _open(tester);
      tester.semantics.tap(find.semantics.byLabel('Zalo'));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.zalo]);
      handle.dispose();
    });
  });

  group('busy', () {
    testWidgets('shows a spinner and ignores taps while a link is fetched', (
      tester,
    ) async {
      final picked = <ContactChannel>[];
      await _pump(tester, busy: true, onSelected: picked.add);
      expect(
        find.descendant(
          of: find.byKey(_button),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_button));
      await tester.pump(); // a spinner never settles
      expect(picked, isEmpty);
      expect(find.byKey(_tray), findsNothing);
    });
  });

  group('busy (reduced motion and semantics)', () {
    testWidgets('reduced motion shows a static glyph, no spinner', (
      tester,
    ) async {
      await _pump(tester, busy: true, reduced: true);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await expectIdle(tester);
    });

    testWidgets('busy has a screen-reader value', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, busy: true);
      expect(
        tester.getSemantics(find.byKey(_button)).label,
        contains('Đang mở liên hệ'),
      );
      handle.dispose();
    });
  });

  group('layout limits', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '320dp at 1.3x text, ${brightness.name}: tray stays on screen, no overflow',
        (tester) async {
          await _pump(
            tester,
            width: 320,
            textScale: 1.3,
            brightness: brightness,
          );
          await _open(tester);
          expect(tester.takeException(), isNull);
          final tray = tester.getRect(find.byKey(_tray));
          expect(tray.left, greaterThanOrEqualTo(0));
          expect(tray.right, lessThanOrEqualTo(320));
          for (final k in [
            'contact-call',
            'contact-zalo',
            'contact-whatsapp',
          ]) {
            expect(
              tester.getSize(find.byKey(Key(k))).height,
              greaterThanOrEqualTo(44),
            );
          }
        },
      );
    }
  });

  testWidgets('the dial costs no frames closed, open, or after closing', (
    tester,
  ) async {
    await _pump(tester);
    await expectIdle(tester);
    await _open(tester);
    expect(find.byKey(_tray), findsOneWidget);
    await expectIdle(tester);
    // The open tray's scrim covers the button and takes the tap.
    await tester.tapAt(tester.getCenter(find.byKey(_button)));
    await expectIdle(tester);
    expect(find.byKey(_tray), findsNothing);
  });

  testWidgets('the locked dial is idle at rest', (tester) async {
    await _pump(tester, access: ContactAccess.locked);
    await expectIdle(tester);
  });

  testWidgets('reduced motion shows the tray fully in one frame, then idles', (
    tester,
  ) async {
    await _pump(tester, reduced: true);
    await tester.tap(find.byKey(_button));
    await tester.pump();
    expect(find.byKey(_tray), findsOneWidget);
    expect(_opacityOf(tester, const Key('contact-tray-fade')), 1.0);
    expect(_itemOpacities(tester), [1.0, 1.0, 1.0]);
    await expectIdle(tester);
    expect(find.byKey(_tray), findsOneWidget);
  });

  testWidgets('the closed dial adds no blur and no overlay entry', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(_tray), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ContactDial),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });
}
