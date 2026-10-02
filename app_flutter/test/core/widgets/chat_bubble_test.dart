// test/core/widgets/chat_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/chat_bubble.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

import 'widget_host.dart';

void main() {
  testWidgets(
    'mine alignment and CTA gradient background; theirs glass background',
    (tester) async {
      await tester.pumpWidget(
        hostWidget(
          const Column(
            children: [
              ChatBubble(content: TextContent('Tin nhắn của tôi'), mine: true),
              ChatBubble(
                content: TextContent('Tin nhắn của bạn'),
                mine: false,
                senderName: 'Minh Trí',
              ),
            ],
          ),
        ),
      );

      // Mine has CtaSurface (gradient)
      expect(find.byType(CtaSurface), findsOneWidget);
      // Theirs displays senderName
      expect(find.text('Minh Trí'), findsOneWidget);

      // Both texts visible
      expect(find.text('Tin nhắn của tôi'), findsOneWidget);
      expect(find.text('Tin nhắn của bạn'), findsOneWidget);
    },
  );

  testWidgets('image and location bubbles render correctly', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const Column(
          children: [
            ChatBubble(
              content: ImageContent('https://example.com/photo.jpg'),
              mine: true,
            ),
            ChatBubble(
              content: LocationContent(
                label: 'Bến Bạch Đằng, Quận 1',
                mapUrl: 'https://maps.example.com',
              ),
              mine: false,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Bến Bạch Đằng, Quận 1'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('system bubble is centered and displays text with actions', (
    tester,
  ) async {
    var actionTapped = false;

    await tester.pumpWidget(
      hostWidget(
        ChatBubble(
          content: SystemContent(
            'Buổi chụp đã được xác nhận',
            actions: [
              TextButton(
                onPressed: () => actionTapped = true,
                child: const Text('Xem chi tiết'),
              ),
            ],
          ),
          mine: false,
        ),
      ),
    );

    expect(find.text('Buổi chụp đã được xác nhận'), findsOneWidget);
    expect(find.text('Xem chi tiết'), findsOneWidget);

    await tester.tap(find.text('Xem chi tiết'));
    await tester.pumpAndSettle();
    expect(actionTapped, isTrue);
  });

  testWidgets('sending state dims bubble with clock icon', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const ChatBubble(
          content: TextContent('Đang gửi...'),
          mine: true,
          state: BubbleSendState.sending,
        ),
      ),
    );

    expect(find.text('Đang gửi...'), findsOneWidget);
    expect(find.byIcon(Icons.access_time), findsOneWidget);

    final opacityWidget = tester.widget<Opacity>(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.6),
    );
    expect(opacityWidget.opacity, 0.6);
  });

  testWidgets('failed state shows Gửi lại and calls onRetry', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      hostWidget(
        ChatBubble(
          content: const TextContent('Tin gửi thất bại'),
          mine: true,
          state: BubbleSendState.failed,
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Tin gửi thất bại'), findsOneWidget);
    expect(find.text('Gửi lại'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.text('Gửi lại'));
    await tester.pumpAndSettle();
    expect(retried, isTrue);
  });

  testWidgets('skeleton has same size as real widget at 390 and 320 dp', (
    tester,
  ) async {
    for (final width in [390.0, 320.0]) {
      await tester.pumpWidget(
        hostWidget(
          const ChatBubble(content: TextContent('Xin chào bạn'), mine: false),
          width: width,
        ),
      );
      final realSize = tester.getSize(find.byType(ChatBubble));

      await tester.pumpWidget(
        hostWidget(
          AppSkeletonScope(child: ChatBubble.skeleton(mine: false)),
          width: width,
        ),
      );
      final skeletonSize = tester.getSize(
        find.byWidgetPredicate(
          (w) => w.key == const ValueKey('chat_bubble_skeleton'),
        ),
      );

      expect(skeletonSize.height, realSize.height);
    }
  });

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          const ChatBubble(
            content: TextContent(
              'Đoạn hội thoại rất dài để kiểm tra độ co giãn trên màn hình nhỏ và cỡ chữ lớn 1.3x',
            ),
            mine: true,
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
