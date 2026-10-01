import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/photo_scope.dart';
import 'widget_host.dart';

void main() {
  test('the initial is the first letter of the given name', () {
    expect(avatarInitial('Minh Trí'), 'T');
    expect(avatarInitial('  nguyễn thị phương '), 'P');
    expect(avatarInitial('Lan'), 'L');
    expect(avatarInitial('đức'), 'Đ');
    expect(avatarInitial(''), '?');
    expect(avatarInitial('   '), '?');
    expect(avatarInitial('Lan 🌸'), 'L');
    expect(avatarInitial('🌸'), '?');
  });

  test('sizes follow the spec', () {
    expect(AppAvatarSize.values.map((s) => s.dimension), [32, 40, 48, 64, 96]);
  });

  testWidgets('without a photo it shows the initial at the requested size', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const AppAvatar(name: 'Minh Trí', size: AppAvatarSize.lg)),
    );
    expect(find.text('T'), findsOneWidget);
    expect(tester.getSize(find.byType(AppAvatar)), const Size(64, 64));
    expect(find.byType(NetworkPhoto), findsNothing);
  });

  testWidgets('with a photo the image is requested without a retry button', (
    tester,
  ) async {
    final log = <PhotoRequest>[];
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          log: log,
          child: const AppAvatar(
            url: 'https://img.test/a.jpg',
            name: 'Minh Trí',
          ),
        ),
      ),
    );
    expect(log.single.url, 'https://img.test/a.jpg');
    expect(log.single.retry, isFalse);
    expect(find.text('T'), findsOneWidget, reason: 'initials stay underneath');
  });

  testWidgets('a badge sits at the bottom right', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const AppAvatar(
          name: 'Minh Trí',
          badge: Icon(Icons.circle, key: Key('badge'), size: 12),
        ),
      ),
    );
    final avatar = tester.getRect(find.byType(AppAvatar));
    final badge = tester.getRect(find.byKey(const Key('badge')));
    expect(badge.center.dx, greaterThan(avatar.center.dx));
    expect(badge.center.dy, greaterThan(avatar.center.dy));
  });

  testWidgets('the 2dp ring is page-coloured and the photo area is size - 4', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const AppAvatar(name: 'Minh Trí', size: AppAvatarSize.lg)),
    );
    final ring = tester.widget<DecoratedBox>(
      find.byKey(const Key('avatar-ring')),
    );
    final border = (ring.decoration as BoxDecoration).border! as Border;
    expect(border.top.width, 2);
    expect(
      border.top.color,
      Theme.of(tester.element(find.byType(AppAvatar))).scaffoldBackgroundColor,
    );
    expect(tester.getSize(find.byType(ClipOval)), const Size(60, 60));
  });

  testWidgets('a decorative avatar is silent but its badge is not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        AppAvatar(
          name: 'Minh Trí',
          decorative: true,
          badge: Semantics(
            label: 'Đang online',
            child: const SizedBox(width: 12),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Minh Trí'), findsNothing);
    expect(find.bySemanticsLabel('Đang online'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a named avatar keeps its badge semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        AppAvatar(
          name: 'Minh Trí',
          badge: Semantics(
            label: 'Đang online',
            child: const SizedBox(width: 12),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Minh Trí'), findsOneWidget);
    expect(find.bySemanticsLabel('Đang online'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('screen readers hear the name once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const AppAvatar(name: 'Minh Trí')));
    expect(find.bySemanticsLabel('Minh Trí'), findsOneWidget);
    handle.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('renders on ${b.name} without overflow', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          const Row(
            children: [
              AppAvatar(name: 'A', size: AppAvatarSize.xs),
              AppAvatar(name: 'B', size: AppAvatarSize.xl),
            ],
          ),
          brightness: b,
          width: 320,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
