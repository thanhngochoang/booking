import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

import '../../support/fake_chat_repository.dart';

void main() {
  group('FakeChatRepository', () {
    late FakeChatRepository repo;

    setUp(() {
      repo = FakeChatRepository(currentUserId: 'cust1');
    });

    test('seedThread and watchThread emits thread updates', () async {
      const thread = ChatThread(
        id: 'chat_1',
        kind: ChatKind.inquiry,
        customerId: 'cust1',
        photographerId: 'photo1',
      );

      final emissions = <ChatThread?>[];
      final sub = repo.watchThread('chat_1').listen(emissions.add);

      repo.seedThread(thread);
      await pumpEventQueue();

      expect(emissions.first, isNull);
      expect(emissions.last?.id, 'chat_1');
      await sub.cancel();
    });

    test('openInquiry creates idempotent thread', () async {
      final id1 = await repo.openInquiry('photo1');
      expect(id1, 'cust1_photo1');
      expect(repo.threads.containsKey('cust1_photo1'), isTrue);

      final id2 = await repo.openInquiry('photo1');
      expect(id2, id1);
      expect(repo.threads.length, 1);
    });

    test('watchMessages and olderMessages return correct ordering and paging', () async {
      const chatId = 'chat_pages';
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final msgs = List.generate(
        10,
        (i) => ChatMessage(
          id: 'm_$i',
          senderId: 'cust1',
          type: MessageType.text,
          body: 'Message $i',
          createdAt: now.add(Duration(minutes: i)),
        ),
      );

      repo.seedThread(
        const ChatThread(
          id: chatId,
          kind: ChatKind.inquiry,
          customerId: 'cust1',
          photographerId: 'photo1',
        ),
      );
      repo.seedMessages(chatId, msgs);

      final streamList = await repo.watchMessages(chatId, limit: 5).first;
      expect(streamList.length, 5);
      expect(streamList.first.id, 'm_5');
      expect(streamList.last.id, 'm_9');

      final older = await repo.olderMessages(
        chatId,
        before: now.add(const Duration(minutes: 5)),
        limit: 3,
      );
      expect(older.length, 3);
      expect(older.first.id, 'm_2');
      expect(older.last.id, 'm_4');
    });

    test('sendText, sendImage, sendLocation update messages and thread preview', () async {
      final chatId = await repo.openInquiry('photo1');

      await repo.sendText(chatId, 'Hello photographer', clientId: 'txt_1');
      expect(repo.messages[chatId]?.length, 1);
      expect(repo.threads[chatId]?.lastMessagePreview, 'Hello photographer');
      expect(repo.threads[chatId]?.lastSenderId, 'cust1');

      const fakeImage = PickedImage(
        path: '/tmp/test.jpg',
        name: 'test.jpg',
      );
      await repo.sendImage(chatId, fakeImage, clientId: 'img_1');
      expect(repo.messages[chatId]?.length, 2);
      expect(repo.threads[chatId]?.lastMessagePreview, 'Ảnh');

      await repo.sendLocation(chatId, (lat: 10.7, lng: 106.6), clientId: 'loc_1');
      expect(repo.messages[chatId]?.length, 3);
      expect(repo.threads[chatId]?.lastMessagePreview, 'Vị trí');
    });

    test('retry by clientId is idempotent (no duplicate message)', () async {
      final chatId = await repo.openInquiry('photo1');
      await repo.sendText(chatId, 'First try', clientId: 'client_unique_1');
      expect(repo.messages[chatId]?.length, 1);

      // Same clientId resent
      await repo.sendText(chatId, 'First try again', clientId: 'client_unique_1');
      expect(repo.messages[chatId]?.length, 1);
      expect(repo.messages[chatId]?.first.body, 'First try');
    });

    test('enforces 3-message inquiry limit for customer until photographer replies', () async {
      final chatId = await repo.openInquiry('photo1');

      // 3 customer messages allowed
      await repo.sendText(chatId, 'msg 1', clientId: 'c_1');
      await repo.sendText(chatId, 'msg 2', clientId: 'c_2');
      await repo.sendText(chatId, 'msg 3', clientId: 'c_3');
      expect(repo.threads[chatId]?.customerMessagesBeforeReply, 3);

      // 4th customer message fails
      expect(
        () => repo.sendText(chatId, 'msg 4', clientId: 'c_4'),
        throwsA(
          isA<ChatException>().having(
            (e) => e.code,
            'code',
            ChatErrorCode.limitExceeded,
          ),
        ),
      );

      // Photographer replies
      repo.currentUserId = 'photo1';
      await repo.sendText(chatId, 'Hi there!', clientId: 'p_1');
      expect(repo.threads[chatId]?.photographerRepliedAt, isNotNull);

      // Now customer can send again
      repo.currentUserId = 'cust1';
      await repo.sendText(chatId, 'msg 4 unblocked', clientId: 'c_4');
      expect(repo.messages[chatId]?.length, 5);
    });

    test('reschedule proposal and answer lifecycle', () async {
      const thread = ChatThread(
        id: 'chat_booking_1',
        kind: ChatKind.booking,
        customerId: 'cust1',
        photographerId: 'photo1',
        bookingId: 'booking_1',
      );
      repo.seedThread(thread);

      // Propose reschedule
      await repo.proposeReschedule(
        'booking_1',
        day: '2026-10-25',
        start: '09:00',
        clientId: 'prop_1',
      );

      final msgs = repo.messages['chat_booking_1']!;
      expect(msgs.length, 1);
      expect(msgs.first.type, MessageType.system);
      expect(msgs.first.system?.kind, 'reschedule_proposal');
      expect(msgs.first.system?.proposal?.day, '2026-10-25');

      // Answer accept
      repo.currentUserId = 'photo1';
      await repo.answerReschedule('chat_booking_1', 'prop_1', accept: true);

      final answeredMsg = repo.messages['chat_booking_1']!.first;
      expect(answeredMsg.system?.answer, 'accepted');
      expect(answeredMsg.system?.answeredBy, 'photo1');
      expect(repo.threads['chat_booking_1']?.rescheduleUsed, isTrue);

      // Subsequent proposal fails because rescheduleUsed is true
      repo.currentUserId = 'cust1';
      expect(
        () => repo.proposeReschedule(
          'booking_1',
          day: '2026-10-26',
          start: '10:00',
          clientId: 'prop_2',
        ),
        throwsA(
          isA<ChatException>().having(
            (e) => e.code,
            'code',
            ChatErrorCode.limitExceeded,
          ),
        ),
      );
    });

    test('unread counts and markRead update streams', () async {
      const thread1 = ChatThread(
        id: 'c1',
        kind: ChatKind.inquiry,
        customerId: 'cust1',
        photographerId: 'p1',
      );
      const thread2 = ChatThread(
        id: 'c2',
        kind: ChatKind.inquiry,
        customerId: 'cust1',
        photographerId: 'p2',
      );
      repo.seedThread(thread1);
      repo.seedThread(thread2);

      final unreadEmissions = <int>[];
      final unreadSub = repo.watchTotalUnread().listen(unreadEmissions.add);

      repo.seedUnread('c1', 2);
      repo.seedUnread('c2', 3);
      await pumpEventQueue();

      expect(unreadEmissions.last, 5);

      await repo.markRead('c1');
      await pumpEventQueue();

      expect(unreadEmissions.last, 3);
      await unreadSub.cancel();
    });

    test('respects online flag and failNext simulation', () async {
      repo.online = false;
      expect(
        () => repo.openInquiry('p1'),
        throwsA(
          isA<ChatException>().having(
            (e) => e.code,
            'code',
            ChatErrorCode.network,
          ),
        ),
      );

      repo.online = true;
      repo.failNext = ChatErrorCode.conflict;

      expect(
        () => repo.openInquiry('p1'),
        throwsA(
          isA<ChatException>().having(
            (e) => e.code,
            'code',
            ChatErrorCode.conflict,
          ),
        ),
      );

      // failNext is consumed, next call works
      final chatId = await repo.openInquiry('p1');
      expect(chatId, isNotEmpty);
    });

    test('rejects send in read-only chat', () async {
      final thread = ChatThread(
        id: 'ro_chat',
        kind: ChatKind.booking,
        customerId: 'cust1',
        photographerId: 'p1',
        readOnlyAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      repo.seedThread(thread);

      expect(
        () => repo.sendText('ro_chat', 'Hi', clientId: 'msg_ro'),
        throwsA(
          isA<ChatException>().having(
            (e) => e.code,
            'code',
            ChatErrorCode.notEligible,
          ),
        ),
      );
    });
  });
}
