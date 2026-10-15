import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/chat_bubble.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/features/chat/chat_bubble_mapping.dart';
import 'package:photobooking/l10n/app_localizations.dart';

void main() {
  group('sendStateOf', () {
    test('maps correctly', () {
      expect(sendStateOf(MessageSendState.sent), BubbleSendState.sent);
      expect(sendStateOf(MessageSendState.sending), BubbleSendState.sending);
      expect(sendStateOf(MessageSendState.failed), BubbleSendState.failed);
    });
  });

  group('bubbleContentOf', () {
    testWidgets('maps text, image, location and system to ChatBubbleContent', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      final now = DateTime(2026, 10, 5, 10, 0);

      // Text
      final textMsg = ChatMessage(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.text,
        body: 'Xin chào',
        createdAt: now,
      );
      final textContent = bubbleContentOf(textMsg, l: l10n, senderName: 'Alice');
      expect(textContent, isA<TextContent>());
      expect((textContent as TextContent).text, 'Xin chào');

      // Image
      final imgMsg = ChatMessage(
        id: 'm2',
        senderId: 'u1',
        type: MessageType.image,
        imagePath: 'chats/c1/u1/img1.webp',
        createdAt: now,
      );
      final imgContent = bubbleContentOf(
        imgMsg,
        imageUrl: 'https://cdn.example.com/img1.webp',
        l: l10n,
        senderName: 'Alice',
      );
      expect(imgContent, isA<ImageContent>());
      expect((imgContent as ImageContent).url, 'https://cdn.example.com/img1.webp');

      // Location
      final locMsg = ChatMessage(
        id: 'm3',
        senderId: 'u1',
        type: MessageType.location,
        point: (lat: 10.762622, lng: 106.660172),
        createdAt: now,
      );
      final locContent = bubbleContentOf(locMsg, l: l10n, senderName: 'Alice');
      expect(locContent, isA<LocationContent>());
      final loc = locContent as LocationContent;
      expect(loc.label, 'Vị trí của Alice');
      expect(loc.mapUrl, 'https://www.google.com/maps?q=10.762622,106.660172');

      // System booking status
      final sysMsg = ChatMessage(
        id: 'm4',
        type: MessageType.system,
        system: const SystemPayload(kind: 'booking_status', status: 'accepted'),
        createdAt: now,
      );
      final sysContent = bubbleContentOf(sysMsg, l: l10n, senderName: 'System');
      expect(sysContent, isA<SystemContent>());
      expect((sysContent as SystemContent).text, 'Nhiếp ảnh gia đã nhận buổi chụp.');

      // System reschedule proposal unanswered with action
      final propMsg = ChatMessage(
        id: 'm5',
        type: MessageType.system,
        system: const SystemPayload(
          kind: 'reschedule_proposal',
          proposal: RescheduleProposal(
            day: '2026-10-10',
            start: '09:00',
            end: '11:00',
            byRole: 'customer',
          ),
        ),
        createdAt: now,
      );
      final actionWidget = const Text('Chấp nhận');
      final propContent = bubbleContentOf(
        propMsg,
        l: l10n,
        senderName: 'System',
        systemActions: [actionWidget],
      );
      expect(propContent, isA<SystemContent>());
      final propSys = propContent as SystemContent;
      expect(propSys.text, 'Đề nghị đổi sang 2026-10-10 09:00–11:00');
      expect(propSys.actions, [actionWidget]);

      // System reschedule proposal answered
      final answeredMsg = ChatMessage(
        id: 'm6',
        type: MessageType.system,
        system: const SystemPayload(
          kind: 'reschedule_proposal',
          proposal: RescheduleProposal(
            day: '2026-10-10',
            start: '09:00',
            end: '11:00',
            byRole: 'customer',
          ),
          answer: 'accepted',
        ),
        createdAt: now,
      );
      final answeredContent = bubbleContentOf(
        answeredMsg,
        l: l10n,
        senderName: 'System',
        systemActions: [actionWidget],
      );
      expect(answeredContent, isA<SystemContent>());
      final sys = answeredContent as SystemContent;
      expect(sys.text, 'Đã đổi lịch thành công');
      expect(sys.actions, isEmpty);
    });

    testWidgets('an image uses the resolved URL, never the storage path', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      final msg = ChatMessage(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.image,
        imagePath: 'chats/c1/u1/img1.jpg',
        createdAt: DateTime(2026, 10, 5),
      );

      final resolved =
          bubbleContentOf(
                msg,
                imageUrl: 'https://storage.test/chats/c1/u1/img1.jpg',
                l: l10n,
                senderName: 'A',
              )
              as ImageContent;
      expect(resolved.url, 'https://storage.test/chats/c1/u1/img1.jpg');
      expect(resolved.localPath, isNull);

      // Not resolved yet: empty, the storage path is never a URL.
      final unresolved =
          bubbleContentOf(msg, l: l10n, senderName: 'A') as ImageContent;
      expect(unresolved.url, isEmpty);
    });

    testWidgets('a pending image uses the local file', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      final msg = ChatMessage(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.image,
        imagePath: '/tmp/photo.jpg',
        createdAt: DateTime(2026, 10, 5),
        sendState: MessageSendState.sending,
      );

      final content =
          bubbleContentOf(
                msg,
                localPath: '/tmp/photo.jpg',
                l: l10n,
                senderName: 'A',
              )
              as ImageContent;

      expect(content.localPath, '/tmp/photo.jpg');
      expect(content.url, isEmpty);
    });
  });
}
