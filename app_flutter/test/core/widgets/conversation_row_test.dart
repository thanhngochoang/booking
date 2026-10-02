// test/core/widgets/conversation_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/conversation_row.dart';

import 'widget_host.dart';

void main() {
  testWidgets(
    'renders recipient name, preview, time and unread badge semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      var tapped = false;

      await tester.pumpWidget(
        hostWidget(
          ConversationRow(
            name: 'Minh Trí',
            preview: 'Đẹp rồi. 15:30 gặp ở cổng công viên Bạch Đằng.',
            timeLabel: '9:41',
            unread: 3,
            badge: const Text('[Đã đặt]'),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Minh Trí'), findsOneWidget);
      expect(
        find.text('Đẹp rồi. 15:30 gặp ở cổng công viên Bạch Đằng.'),
        findsOneWidget,
      );
      expect(find.text('9:41'), findsOneWidget);
      expect(find.text('[Đã đặt]'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Unread badge announced to screen readers as "{n} tin chưa đọc"
      expect(find.bySemanticsLabel(RegExp(r'3 tin chưa đọc')), findsOneWidget);

      // Tap row
      await tester.tap(find.text('Minh Trí'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      handle.dispose();
    },
  );

  testWidgets('skeleton has same size as real widget at 390 and 320 dp', (
    tester,
  ) async {
    for (final width in [390.0, 320.0]) {
      await tester.pumpWidget(
        hostWidget(
          const ConversationRow(
            name: 'Minh Trí',
            preview: 'Xem trước tin nhắn',
            timeLabel: '10:00',
            unread: 1,
          ),
          width: width,
        ),
      );
      final realSize = tester.getSize(find.byType(ConversationRow));

      await tester.pumpWidget(
        hostWidget(
          AppSkeletonScope(child: ConversationRow.skeleton()),
          width: width,
        ),
      );
      final skeletonSize = tester.getSize(
        find.byWidgetPredicate(
          (w) => w.key == const ValueKey('conversation_row_skeleton'),
        ),
      );

      expect(skeletonSize.height, realSize.height);
      expect(skeletonSize.width, realSize.width);
    }
  });

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          const ConversationRow(
            name: 'Nguyễn Văn Minh Trí Cực Kỳ Dài',
            preview:
                'Đoạn tin nhắn xem trước cũng rất dài để kiểm tra độ co giãn',
            timeLabel: '15:30',
            unread: 12,
          ),
          width: 320,
          textScale: 1.3,
          brightness: brightness,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
