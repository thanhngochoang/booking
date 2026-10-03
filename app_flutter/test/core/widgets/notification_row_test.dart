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
  NotificationKind kind = NotificationKind.booking,
  String title = 'Lịch chụp đã được xác nhận',
  String body = 'Nhiếp ảnh gia Minh Trí đã xác nhận buổi chụp vào 14:30 T7 12/10.',
  String timeLabel = '5 phút',
  bool unread = true,
  String? thumbUrl,
  List<String> groupAvatars = const [],
}) {
  return NotificationRowData(
    id: id,
    kind: kind,
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

    testWidgets('one icon per kind', (tester) async {
      for (final kind in NotificationKind.values) {
        await tester.pumpWidget(_wrap(
          NotificationRow(
            item: _item(kind: kind),
            onTap: () {},
            onMarkRead: () {},
            onMuteKind: () {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(ValueKey('notification_kind_icon_${kind.name}')), findsOneWidget);
      }
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

  group('NotificationBell', () {
    testWidgets('hidden dot at 0, 9+ at 10, labels per count, target 48', (tester) async {
      final handle = tester.ensureSemantics();

      // 0 unread: no dot, label 'Thông báo'
      await tester.pumpWidget(_wrap(NotificationBell(unread: 0, onTap: () {})));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification_bell_dot')), findsNothing);
      expect(tester.getSemantics(find.byType(NotificationBell)).label, 'Thông báo');

      // 5 unread: badge '5', label '5 thông báo chưa đọc'
      await tester.pumpWidget(_wrap(NotificationBell(unread: 5, onTap: () {})));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification_bell_dot')), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(tester.getSemantics(find.byType(NotificationBell)).label, '5 thông báo chưa đọc');

      // 10 unread: badge '9+', label '10 thông báo chưa đọc'
      await tester.pumpWidget(_wrap(NotificationBell(unread: 10, onTap: () {})));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification_bell_dot')), findsOneWidget);
      expect(find.text('9+'), findsOneWidget);
      expect(tester.getSemantics(find.byType(NotificationBell)).label, '10 thông báo chưa đọc');

      // Target size >= 48
      final bellSize = tester.getSize(find.byType(NotificationBell));
      expect(bellSize.width, greaterThanOrEqualTo(48.0));
      expect(bellSize.height, greaterThanOrEqualTo(48.0));

      handle.dispose();
    });
  });
}
