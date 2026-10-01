// test/core/widgets/photo_card_test.dart
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
        leading: const PhotoPill(label: 'Rảnh T7 này', dot: true),
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
        action: const SizedBox(key: Key('act'), width: 30, height: 30),
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
      await tester.tap(find.text('Minh Trí'));
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
}
