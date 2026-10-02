// test/core/widgets/chat_composer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/chat_composer.dart';
import 'package:photobooking/core/widgets/signature_loader.dart';

import 'widget_host.dart';

void main() {
  testWidgets('does not send empty or whitespace and clears after send', (
    tester,
  ) async {
    final sentMessages = <String>[];

    await tester.pumpWidget(
      hostWidget(ChatComposer(onSend: (msg) => sentMessages.add(msg))),
    );

    // Initial state: send button disabled
    final sendFinder = find.bySemanticsLabel('Gửi tin nhắn');
    expect(sendFinder, findsOneWidget);

    // Type whitespace only
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    // Tap send -> not sent
    await tester.tap(sendFinder, warnIfMissed: false);
    await tester.pump();
    expect(sentMessages, isEmpty);

    // Enter actual text
    await tester.enterText(find.byType(TextField), 'Chào bạn!');
    await tester.pump();

    // Tap send
    await tester.tap(sendFinder);
    await tester.pump();

    expect(sentMessages, ['Chào bạn!']);
    // Input is cleared
    expect(find.text('Chào bạn!'), findsNothing);
  });

  testWidgets('shows disabledReason when enabled is false', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        ChatComposer(
          onSend: (_) {},
          enabled: false,
          disabledReason: 'Cuộc trò chuyện đã đóng',
        ),
      ),
    );

    expect(find.text('Cuộc trò chuyện đã đóng'), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
  });

  testWidgets('busy shows inline SignatureLoader and blocks image pick', (
    tester,
  ) async {
    var pickCount = 0;

    await tester.pumpWidget(
      hostWidget(
        ChatComposer(
          onSend: (_) {},
          onPickImage: () => pickCount++,
          busy: true,
        ),
      ),
    );

    // Inline loader shown
    expect(find.byType(SignatureLoader), findsOneWidget);

    // Tap image button -> blocked
    final imageBtnFinder = find.bySemanticsLabel('Chọn ảnh');
    await tester.tap(imageBtnFinder, warnIfMissed: false);
    await tester.pump();

    expect(pickCount, 0);
  });

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          ChatComposer(onSend: (_) {}, onPickImage: () {}),
          width: 320,
          textScale: 1.3,
          brightness: brightness,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
