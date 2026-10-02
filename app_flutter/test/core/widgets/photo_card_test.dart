// test/core/widgets/photo_card_test.dart
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/photo_scope.dart';
import 'widget_host.dart';

Widget _card({
  double aspect = 4 / 5,
  String? title = 'Minh Trí',
  String? subtitle = 'Quận 3 · ★ 4,9 (58) · 112 buổi',
  Widget? leading,
  Widget? trailing,
  Widget? action,
  VoidCallback? onTap,
  String? semanticLabel,
  double width = 300,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  List<PhotoRequest>? log,
}) => hostWidget(
  testPhotoScope(
    log: log,
    child: PhotoCard(
      imageUrl: 'https://img.test/a.jpg',
      blurHash: 'LEHV6nWB2yk8',
      aspect: aspect,
      title: title,
      subtitle: subtitle,
      leadingPill: leading,
      trailingPill: trailing,
      action: action,
      onTap: onTap,
      semanticLabel: semanticLabel,
    ),
  ),
  width: width,
  textScale: textScale,
  brightness: brightness,
);

void main() {
  testWidgets('shows the photo, title, subtitle, pills and action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(
        leading: const PhotoPill(label: 'Rảnh T7 này', dot: PhotoPillDot.ok),
        trailing: const PhotoPill(label: 'Chân dung · từ 1,5M'),
        action: const Icon(Icons.bookmark_border, key: Key('save')),
      ),
    );
    expect(
      find.byKey(const ValueKey('photo:https://img.test/a.jpg')),
      findsOneWidget,
    );
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.text('Quận 3 · ★ 4,9 (58) · 112 buổi'), findsOneWidget);
    expect(find.text('Rảnh T7 này'), findsOneWidget);
    expect(find.text('Chân dung · từ 1,5M'), findsOneWidget);
    expect(find.byKey(const Key('save')), findsOneWidget);
  });

  testWidgets('pills sit at the top corners, the action at the bottom right', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(
        leading: const PhotoPill(label: 'L'),
        trailing: const PhotoPill(label: 'R'),
        action: const SizedBox(key: Key('act'), width: 48, height: 48),
      ),
    );
    final card = tester.getRect(find.byType(PhotoCard));
    final l = tester.getRect(find.text('L'));
    final r = tester.getRect(find.text('R'));
    final act = tester.getRect(find.byKey(const Key('act')));
    expect(l.top, lessThan(card.top + 40));
    expect(l.left, lessThan(card.left + 40));
    expect(r.right, greaterThan(card.right - 40));
    expect(act.bottom, greaterThan(card.bottom - 40));
    expect(act.right, greaterThan(card.right - 40));
  });

  testWidgets('keeps the aspect ratio (4:5 and 3:4)', (tester) async {
    await tester.pumpWidget(_card(aspect: 4 / 5));
    var s = tester.getSize(find.byType(PhotoCard));
    expect(s.width / s.height, closeTo(0.8, 0.001));
    await tester.pumpWidget(_card(aspect: 3 / 4));
    s = tester.getSize(find.byType(PhotoCard));
    expect(s.width / s.height, closeTo(0.75, 0.001));
  });

  testWidgets('a card without text has no gradient overlay', (tester) async {
    await tester.pumpWidget(_card(title: null, subtitle: null));
    expect(find.byKey(const Key('photo-card-scrim')), findsNothing);
    await tester.pumpWidget(_card());
    expect(find.byKey(const Key('photo-card-scrim')), findsOneWidget);
  });

  testWidgets(
    'tapping the card calls onTap; without onTap it is not a button',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(_card(onTap: () => taps++));
      await tester.tap(find.byType(PhotoCard));
      expect(taps, 1);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(PhotoCard)).label,
        contains('Minh Trí'),
      );
      handle.dispose();
    },
  );

  testWidgets('the photo is decoded at card size, not original size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final log = <PhotoRequest>[];
    await tester.pumpWidget(_card(width: 120, log: log));
    expect(
      log.single.cacheWidth,
      400,
      reason: '120 dp x 3 = 360 px rounded up to 400',
    );
  });

  testWidgets(
    'an action inside the card gets its own tap; the rest opens the card',
    (tester) async {
      var taps = 0, acts = 0;
      await tester.pumpWidget(
        _card(
          onTap: () => taps++,
          action: IconButton(
            key: const Key('act'),
            onPressed: () => acts++,
            icon: const Icon(Icons.bookmark_border),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('act')));
      expect((taps, acts), (0, 1));
      await tester.tapAt(tester.getCenter(find.text('Minh Trí')));
      expect((taps, acts), (1, 1), reason: 'tapping the title opens the card');
    },
  );

  testWidgets('has no BackdropFilter', (tester) async {
    await tester.pumpWidget(_card());
    expect(find.byType(BackdropFilter), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('a 120dp-wide card with long text fits at 1.3x on ${b.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(
          aspect: 3 / 4,
          title: 'Nguyễn Thị Phương Anh',
          subtitle: 'Gia đình · từ 1,2M',
          width: 120,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a failing photo builder does not break the card or its tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      hostWidget(
        PhotoImageScope(
          builder: (context, url, fit, cacheWidth, retry) =>
              const Center(child: Icon(Icons.broken_image)),
          child: PhotoCard(
            imageUrl: 'https://img.test/a.jpg',
            aspect: 4 / 5,
            title: 'Minh Trí',
            onTap: () => taps++,
          ),
        ),
        width: 300,
      ),
    );
    await tester.tapAt(tester.getCenter(find.byType(PhotoCard)));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the photo is requested without a retry control', (tester) async {
    final log = <PhotoRequest>[];
    await tester.pumpWidget(_card(log: log));
    expect(log.single.retry, isFalse);
  });

  testWidgets('semantics: button with tap only when onTap is set; pills read', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _card(
        onTap: () {},
        leading: const PhotoPill(label: 'Rảnh T7 này'),
      ),
    );
    var node = tester.getSemantics(find.byType(PhotoCard));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.label, contains('Rảnh T7 này'));
    await tester.pumpWidget(_card());
    node = tester.getSemantics(find.byType(PhotoCard));
    expect(node.flagsCollection.isButton, isFalse);
    handle.dispose();
  });

  testWidgets('the action is its own semantics node', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _card(
        onTap: () {},
        action: Semantics(
          button: true,
          label: 'Lưu',
          child: const SizedBox(key: Key('act'), width: 48, height: 48),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Lưu'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(PhotoCard)).label,
      isNot(contains('Lưu')),
    );
    handle.dispose();
  });

  testWidgets('a 320dp card with action, title and subtitle fits at 1.3x', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(
        width: 320,
        textScale: 1.3,
        title: 'Nguyễn Thị Phương Anh Thư Hoàng Gia',
        subtitle: 'Quận 3 · ★ 4,9 (58) · 112 buổi chụp chân dung gia đình',
        action: const Icon(Icons.bookmark_border),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flat fill sits under a photo that draws nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        PhotoImageScope(
          builder: (context, url, fit, cacheWidth, retry) =>
              const SizedBox.shrink(),
          child: const PhotoCard(imageUrl: 'u', aspect: 4 / 5),
        ),
        width: 300,
      ),
    );
    expect(find.byKey(const ValueKey('photo-card-fill')), findsOneWidget);
  });

  testWidgets('semanticLabel replaces the joined text and pill label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _card(
        leading: const PhotoPill(label: 'Rảnh T7 này'),
        semanticLabel: 'Ảnh 3',
      ),
    );
    expect(find.bySemanticsLabel('Ảnh 3'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Rảnh T7 này')), findsNothing);
    handle.dispose();
  });

  group('PhotoPill', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    testWidgets('is a white 94% pill with dark text', (tester) async {
      await tester.pumpWidget(hostWidget(const PhotoPill(label: 'Rảnh')));
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(PhotoPill),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.color, Colors.white.withValues(alpha: 0.94));
      final text = tester.widget<Text>(find.text('Rảnh')).style!.color!;
      expect(text, AppColors.pillInk);
      // On the lightest and the darkest photo the text stays at 4.5:1.
      for (final photo in [Colors.white, Colors.black]) {
        expect(
          contrast(text, Color.alphaBlend(deco.color!, photo)),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    testWidgets('dot is green for ok and yellow for warn, none by default', (
      tester,
    ) async {
      Future<Color?> dotColor(PhotoPillDot? d) async {
        await tester.pumpWidget(hostWidget(PhotoPill(label: 'x', dot: d)));
        final dots = find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        if (dots.evaluate().isEmpty) return null;
        return ((tester.widget<DecoratedBox>(dots).decoration) as BoxDecoration)
            .color;
      }

      expect(await dotColor(null), isNull);
      expect(await dotColor(PhotoPillDot.ok), AppColors.success);
      expect(await dotColor(PhotoPillDot.warn), AppColors.warning);
    });
  });
}
