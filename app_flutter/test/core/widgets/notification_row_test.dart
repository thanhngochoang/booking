import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _wrap(Widget child, {double width = 390}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: child,
        ),
      ),
    ),
  );
}

NotificationRowData _item({
  String id = 'n1',
  IconData icon = AppIcons.calendar,
  NotificationTone tone = NotificationTone.neutral,
  String title = 'Lịch chụp đã được xác nhận',
  String body = 'Nhiếp ảnh gia Minh Trí đã xác nhận buổi chụp vào 14:30 T7 12/10.',
  String timeLabel = '5 phút',
  bool unread = true,
  String? thumbUrl,
  List<String> groupAvatars = const [],
}) {
  return NotificationRowData(
    id: id,
    icon: icon,
    tone: tone,
    title: title,
    body: body,
    timeLabel: timeLabel,
    unread: unread,
    thumbUrl: thumbUrl,
    groupAvatars: groupAvatars,
  );
}

void main() {
  group('NotificationRow', () {
    testWidgets("unread shows the dot and reads 'Chưa đọc. {title}. {body}. {time}'", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(unread: true),
          onTap: () {},
          onMarkRead: () {},
          onMuteKind: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Dot is visible
      expect(find.byKey(const ValueKey('notification_unread_dot')), findsOneWidget);

      // Semantics label contains 'Chưa đọc.'
      final semantics = tester.getSemantics(find.byType(NotificationRow));
      expect(
        semantics.label,
        'Chưa đọc. Lịch chụp đã được xác nhận. Nhiếp ảnh gia Minh Trí đã xác nhận buổi chụp vào 14:30 T7 12/10.. 5 phút',
      );
      handle.dispose();
    });

    testWidgets("read row has no dot and no 'Chưa đọc'", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(unread: false),
          onTap: () {},
          onMarkRead: () {},
          onMuteKind: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notification_unread_dot')), findsNothing);

      final semantics = tester.getSemantics(find.byType(NotificationRow));
      expect(semantics.label, isNot(contains('Chưa đọc')));
      expect(
        semantics.label,
        'Lịch chụp đã được xác nhận. Nhiếp ảnh gia Minh Trí đã xác nhận buổi chụp vào 14:30 T7 12/10.. 5 phút',
      );
      handle.dispose();
    });

    testWidgets('row shows the given icon and tone disc', (tester) async {
      final expected = <NotificationTone, (Color, Color)>{
        NotificationTone.neutral: (AppColors.primarySubtle, AppColors.primary),
        NotificationTone.success: (AppColors.successSubtle, AppColors.success),
        NotificationTone.action: (AppColors.warningSubtle, AppColors.foreground),
        NotificationTone.danger: (AppColors.errorSubtle, AppColors.error),
        NotificationTone.muted: (
          AppColors.surfaceMuted,
          AppColors.foregroundMuted,
        ),
      };
      for (final e in expected.entries) {
        await tester.pumpWidget(_wrap(
          NotificationRow(
            item: _item(icon: AppIcons.award, tone: e.key),
            onTap: () {},
            onMarkRead: () {},
            onMuteKind: () {},
          ),
        ));
        await tester.pumpAndSettle();

        final disc = tester.widget<Container>(find.byKey(const ValueKey('notification_disc')));
        expect((disc.decoration! as BoxDecoration).color, e.value.$1, reason: '${e.key} disc');
        final icon = tester.widget<AppIcon>(find.byKey(const ValueKey('notification_icon')));
        expect(icon.icon, AppIcons.award);
        expect(icon.color, e.value.$2, reason: '${e.key} glyph');
      }
    });

    testWidgets('null onMuteKind hides the menu item and the custom action', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(unread: true),
          onTap: () {},
          onMarkRead: () {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(NotificationRow));
      await tester.pumpAndSettle();
      expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
      expect(find.text('Tắt loại thông báo này'), findsNothing);
      await tester.tap(find.text('Đánh dấu đã đọc'));
      await tester.pumpAndSettle();

      final semanticsWidget = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(NotificationRow),
          matching: find.byType(Semantics),
        ).first,
      );
      final labels = semanticsWidget.properties.customSemanticsActions!.keys.map((a) => a.label);
      expect(labels, ['Đánh dấu đã đọc']);
      handle.dispose();
    });

    testWidgets('grouped row shows at most 3 avatars', (tester) async {
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(
            groupAvatars: ['https://example.com/1.jpg', 'https://example.com/2.jpg', 'https://example.com/3.jpg', 'https://example.com/4.jpg', 'https://example.com/5.jpg'],
          ),
          onTap: () {},
          onMarkRead: () {},
          onMuteKind: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // At most 3 avatar widgets rendered
      expect(find.byType(AppAvatar), findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('notification_group_avatar_$i')), findsOneWidget);
      }
    });

    testWidgets('long press offers mark read and mute; read rows only mute', (tester) async {
      var markReadCalled = false;
      var muteKindCalled = false;

      // 1. Unread row: long press shows mark read and mute
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(unread: true),
          onTap: () {},
          onMarkRead: () => markReadCalled = true,
          onMuteKind: () => muteKindCalled = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(NotificationRow));
      await tester.pumpAndSettle();

      expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
      expect(find.text('Tắt loại thông báo này'), findsOneWidget);

      await tester.tap(find.text('Đánh dấu đã đọc'));
      await tester.pumpAndSettle();
      expect(markReadCalled, isTrue);

      // 2. Read row: long press shows ONLY mute
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(unread: false),
          onTap: () {},
          onMarkRead: () {},
          onMuteKind: () => muteKindCalled = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(NotificationRow));
      await tester.pumpAndSettle();

      expect(find.text('Đánh dấu đã đọc'), findsNothing);
      expect(find.text('Tắt loại thông báo này'), findsOneWidget);

      await tester.tap(find.text('Tắt loại thông báo này'));
      await tester.pumpAndSettle();
      expect(muteKindCalled, isTrue);
    });

    testWidgets('custom semantics actions call onMarkRead/onMuteKind', (tester) async {
      var markReadCalled = false;
      var muteKindCalled = false;

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(unread: true),
          onTap: () {},
          onMarkRead: () => markReadCalled = true,
          onMuteKind: () => muteKindCalled = true,
        ),
      ));
      await tester.pumpAndSettle();

      final semanticsWidget = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(NotificationRow),
          matching: find.byType(Semantics),
        ).first,
      );
      final customActions = semanticsWidget.properties.customSemanticsActions;
      expect(customActions, isNotNull);

      expect(customActions!.keys.any((a) => a.label == 'Đánh dấu đã đọc'), isTrue);
      expect(customActions.keys.any((a) => a.label == 'Tắt loại thông báo này'), isTrue);

      final markAction = customActions.keys.firstWhere((a) => a.label == 'Đánh dấu đã đọc');
      customActions[markAction]!();
      expect(markReadCalled, isTrue);

      final muteAction = customActions.keys.firstWhere((a) => a.label == 'Tắt loại thông báo này');
      customActions[muteAction]!();
      expect(muteKindCalled, isTrue);

      handle.dispose();
    });

    testWidgets('body max 2 lines', (tester) async {
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(body: 'A very long body line that should be clamped to at most two lines when displayed in the notification row.'),
          onTap: () {},
          onMarkRead: () {},
          onMuteKind: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final bodyText = tester.widget<Text>(find.byKey(const ValueKey('notification_body_text')));
      expect(bodyText.maxLines, 2);
      expect(bodyText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('row height >= 48', (tester) async {
      await tester.pumpWidget(_wrap(
        NotificationRow(
          item: _item(),
          onTap: () {},
          onMarkRead: () {},
          onMuteKind: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(NotificationRow));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('skeleton matches size at 390 and 320 dp', (tester) async {
      for (final width in [390.0, 320.0]) {
        await tester.pumpWidget(_wrap(
          NotificationRow(
            item: _item(),
            onTap: () {},
            onMarkRead: () {},
            onMuteKind: () {},
          ),
          width: width,
        ));
        await tester.pump();
        final realSize = tester.getSize(find.byType(NotificationRow));

        await tester.pumpWidget(_wrap(
          AppSkeletonScope(child: NotificationRow.skeleton()),
          width: width,
        ));
        await tester.pump();
        final skeletonSize = tester.getSize(find.byKey(const ValueKey('notification_row_skeleton')));

        expect(skeletonSize.height, closeTo(realSize.height, 2.0), reason: 'height at $width');
        expect(skeletonSize.width, realSize.width, reason: 'width at $width');
      }
    });
  });
}
