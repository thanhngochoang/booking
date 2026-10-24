import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/chat/firestore_chat_repository.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> makeDoc(
    String path,
    Map<String, dynamic>? data,
  ) async {
    final ref = firestore.doc(path);
    if (data != null) {
      await ref.set(data);
    }
    return ref.get();
  }

  group('ChatThread.fromFirestore', () {
    test('parses inquiry thread with full fields and Timestamps', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final doc = await makeDoc('chats/inquiry_1', {
        'kind': 'inquiry',
        'customerId': 'cust1',
        'photographerId': 'photo1',
        'photographerRepliedAt': Timestamp.fromDate(now),
        'customerMessagesBeforeReply': 2,
        'lastMessageAt': Timestamp.fromDate(now),
        'lastMessagePreview': 'Xin chào',
        'lastSenderId': 'cust1',
        'readOnlyAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'rescheduleUsed': false,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final thread = ChatThread.fromFirestore(doc);
      expect(thread.id, 'inquiry_1');
      expect(thread.kind, ChatKind.inquiry);
      expect(thread.customerId, 'cust1');
      expect(thread.photographerId, 'photo1');
      expect(thread.bookingId, isNull);
      expect(thread.photographerRepliedAt, now);
      expect(thread.customerMessagesBeforeReply, 2);
      expect(thread.lastMessageAt, now);
      expect(thread.lastMessagePreview, 'Xin chào');
      expect(thread.lastSenderId, 'cust1');
      expect(thread.readOnlyAt, now.add(const Duration(days: 30)));
      expect(thread.rescheduleUsed, isFalse);
      expect(thread.createdAt, now);
      expect(thread.updatedAt, now);
    });

    test('parses booking thread with bookingId and string dates', () async {
      final doc = await makeDoc('chats/chat_b1', {
        'kind': 'booking',
        'customerId': 'cust2',
        'photographerId': 'photo2',
        'bookingId': 'book123',
        'rescheduleUsed': true,
        'createdAt': '2026-10-01T08:00:00.000Z',
      });

      final thread = ChatThread.fromFirestore(doc);
      expect(thread.id, 'chat_b1');
      expect(thread.kind, ChatKind.booking);
      expect(thread.bookingId, 'book123');
      expect(thread.rescheduleUsed, isTrue);
      expect(thread.createdAt, DateTime.parse('2026-10-01T08:00:00.000Z'));
    });

    test('kind collab parses to ChatKind.collab', () async {
      // S27 (#151 Decision 16): the studio is in the customerId slot.
      final doc = await makeDoc('chats/collab_cuc_dung', {
        'kind': 'collab',
        'customerId': 'cuc',
        'photographerId': 'dung',
        'readOnlyAt': '2026-10-20T03:00:00.000Z',
      });
      final thread = ChatThread.fromFirestore(doc);
      expect(thread.kind, ChatKind.collab);
      expect(thread.customerId, 'cuc');
      expect(thread.photographerId, 'dung');
      expect(thread.readOnlyAt, DateTime.parse('2026-10-20T03:00:00.000Z'));
      // An unknown kind still reads as inquiry.
      final odd = await makeDoc('chats/odd', {'kind': 'something_new'});
      expect(ChatThread.fromFirestore(odd).kind, ChatKind.inquiry);
      expect(oneToOneChatKinds, contains('collab'));
    });

    test('handles empty or missing data gracefully with defaults', () async {
      final doc = await makeDoc('chats/empty_1', null);
      final thread = ChatThread.fromFirestore(doc);
      expect(thread.id, 'empty_1');
      expect(thread.kind, ChatKind.inquiry);
      expect(thread.customerId, '');
      expect(thread.photographerId, '');
      expect(thread.customerMessagesBeforeReply, 0);
      expect(thread.rescheduleUsed, isFalse);
    });

    test('equality and hashCode match for identical values', () {
      const t1 = ChatThread(
        id: 't1',
        kind: ChatKind.inquiry,
        customerId: 'c1',
        photographerId: 'p1',
      );
      const t2 = ChatThread(
        id: 't1',
        kind: ChatKind.inquiry,
        customerId: 'c1',
        photographerId: 'p1',
      );
      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
    });
  });

  group('booking status and closed inquiries', () {
    test('ChatThread reads bookingStatus', () async {
      final doc = await makeDoc('chats/b1', {
        'kind': 'booking',
        'customerId': 'c1',
        'photographerId': 'p1',
        'bookingId': 'bk1',
        'bookingStatus': 'upcoming',
      });
      final thread = ChatThread.fromFirestore(doc);
      expect(thread.bookingStatus, 'upcoming');
      expect(thread.copyWith(lastSenderId: 'x').bookingStatus, 'upcoming');
      expect(thread, isNot(thread.copyWith(bookingStatus: 'completed')));

      final none = ChatThread.fromFirestore(
        await makeDoc('chats/b2', {'kind': 'booking', 'bookingStatus': 3}),
      );
      expect(none.bookingStatus, isNull);
    });

    test('bookingStatusValue parses known codes and is null otherwise', () {
      ChatThread t(String? s) => ChatThread(
        id: 'c',
        kind: ChatKind.booking,
        customerId: 'c1',
        photographerId: 'p1',
        bookingStatus: s,
      );
      expect(t('accepted').bookingStatusValue, BookingStatus.accepted);
      expect(t('reviewed').bookingStatusValue, BookingStatus.reviewed);
      expect(t('someday').bookingStatusValue, isNull);
      expect(t(null).bookingStatusValue, isNull);
    });

    test('isClosedInquiryAt matches the domain rule', () {
      final now = DateTime.utc(2026, 10, 20, 12);
      ChatThread chat(
        ChatKind kind, {
        DateTime? lastMessageAt,
        DateTime? createdAt,
      }) => ChatThread(
        id: 'c',
        kind: kind,
        customerId: 'c1',
        photographerId: 'p1',
        lastMessageAt: lastMessageAt,
        createdAt: createdAt,
      );
      final cases = [
        (
          'inquiry 13 d 23 h → open',
          chat(
            ChatKind.inquiry,
            lastMessageAt: now.subtract(const Duration(days: 13, hours: 23)),
          ),
          false,
        ),
        (
          'inquiry 14 d → closed',
          chat(
            ChatKind.inquiry,
            lastMessageAt: now.subtract(const Duration(days: 14)),
          ),
          true,
        ),
        (
          'inquiry one ms before 14 d → open',
          chat(
            ChatKind.inquiry,
            lastMessageAt: now.subtract(
              const Duration(days: 14) - const Duration(milliseconds: 1),
            ),
          ),
          false,
        ),
        (
          'no message + createdAt 15 d → closed',
          chat(
            ChatKind.inquiry,
            createdAt: now.subtract(const Duration(days: 15)),
          ),
          true,
        ),
        (
          'booking chat → never',
          chat(
            ChatKind.booking,
            lastMessageAt: now.subtract(const Duration(days: 60)),
          ),
          false,
        ),
      ];
      for (final (name, thread, closed) in cases) {
        expect(thread.isClosedInquiryAt(now), closed, reason: name);
      }
      expect(inquiryCloseDays, 14);
    });
  });

  group('ChatMessage.fromFirestore', () {
    test('parses text message', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final doc = await makeDoc('chats/c1/messages/msg1', {
        'senderId': 'c1',
        'type': 'text',
        'body': 'Hello world',
        'createdAt': Timestamp.fromDate(now),
      });

      final msg = ChatMessage.fromFirestore(doc);
      expect(msg.id, 'msg1');
      expect(msg.senderId, 'c1');
      expect(msg.type, MessageType.text);
      expect(msg.body, 'Hello world');
      expect(msg.imagePath, isNull);
      expect(msg.point, isNull);
      expect(msg.system, isNull);
      expect(msg.createdAt, now);
      expect(msg.sendState, MessageSendState.sent);
    });

    test('parses image message', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final doc = await makeDoc('chats/c1/messages/msg2', {
        'senderId': 'p1',
        'type': 'image',
        'imagePath': 'chats/c1/p1/img.webp',
        'createdAt': Timestamp.fromDate(now),
      });

      final msg = ChatMessage.fromFirestore(doc);
      expect(msg.type, MessageType.image);
      expect(msg.imagePath, 'chats/c1/p1/img.webp');
    });

    test('parses location message with GeoPoint', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final doc = await makeDoc('chats/c1/messages/msg3', {
        'senderId': 'c1',
        'type': 'location',
        'point': const GeoPoint(10.7769, 106.7009),
        'createdAt': Timestamp.fromDate(now),
      });

      final msg = ChatMessage.fromFirestore(doc);
      expect(msg.type, MessageType.location);
      expect(msg.point, isNotNull);
      expect(msg.point?.lat, 10.7769);
      expect(msg.point?.lng, 106.7009);
    });

    test('parses location message with map point', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final doc = await makeDoc('chats/c1/messages/msg3b', {
        'senderId': 'c1',
        'type': 'location',
        'point': {'lat': 21.0285, 'lng': 105.8542},
        'createdAt': Timestamp.fromDate(now),
      });

      final msg = ChatMessage.fromFirestore(doc);
      expect(msg.point?.lat, 21.0285);
      expect(msg.point?.lng, 105.8542);
    });

    test('parses system message with reschedule proposal', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final doc = await makeDoc('chats/c1/messages/msg4', {
        'senderId': null,
        'type': 'system',
        'system': {
          'kind': 'reschedule_proposal',
          'proposal': {
            'day': '2026-10-15',
            'start': '14:00',
            'end': '16:00',
            'byRole': 'customer',
          },
          'answer': 'accepted',
          'answeredBy': 'p1',
          'answeredAt': Timestamp.fromDate(now),
        },
        'createdAt': Timestamp.fromDate(now),
      });

      final msg = ChatMessage.fromFirestore(doc);
      expect(msg.type, MessageType.system);
      expect(msg.system, isNotNull);
      expect(msg.system?.kind, 'reschedule_proposal');
      expect(msg.system?.proposal?.day, '2026-10-15');
      expect(msg.system?.proposal?.start, '14:00');
      expect(msg.system?.proposal?.end, '16:00');
      expect(msg.system?.proposal?.byRole, 'customer');
      expect(msg.system?.answer, 'accepted');
      expect(msg.system?.answeredBy, 'p1');
      expect(msg.system?.answeredAt, now);
    });

    test('equality and hashCode match for identical messages', () {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final m1 = ChatMessage(
        id: 'm1',
        type: MessageType.text,
        body: 'test',
        createdAt: now,
      );
      final m2 = ChatMessage(
        id: 'm1',
        type: MessageType.text,
        body: 'test',
        createdAt: now,
      );
      expect(m1, equals(m2));
      expect(m1.hashCode, equals(m2.hashCode));
    });
  });

  group('RescheduleProposal & SystemPayload mapping', () {
    test('RescheduleProposal toMap and fromMap round trip', () {
      const prop = RescheduleProposal(
        day: '2026-10-25',
        start: '09:00',
        end: '11:00',
        byRole: 'photographer',
      );
      final map = prop.toMap();
      final restored = RescheduleProposal.fromMap(map);
      expect(restored, equals(prop));
      expect(restored.hashCode, equals(prop.hashCode));
    });

    test('SystemPayload toMap and fromMap round trip', () {
      final now = DateTime(2026, 10, 3, 12, 0, 0);
      final payload = SystemPayload(
        kind: 'reschedule_proposal',
        status: 'pending',
        proposal: const RescheduleProposal(
          day: '2026-10-25',
          start: '09:00',
          end: '11:00',
          byRole: 'customer',
        ),
        answer: 'accepted',
        answeredBy: 'p1',
        answeredAt: now,
      );

      final map = payload.toMap();
      final restored = SystemPayload.fromMap(map);
      expect(restored.kind, payload.kind);
      expect(restored.status, payload.status);
      expect(restored.proposal, equals(payload.proposal));
      expect(restored.answer, payload.answer);
      expect(restored.answeredBy, payload.answeredBy);
      expect(restored.answeredAt?.toIso8601String(), now.toIso8601String());
      expect(restored, equals(payload));
      expect(restored.hashCode, equals(payload.hashCode));
    });
  });

  group('FirestoreChatRepository.mapFunctionsError', () {
    test('maps limit_exceeded and resource-exhausted', () {
      final e1 = FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'limit_exceeded',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e1),
        ChatErrorCode.limitExceeded,
      );

      final e2 = FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'other',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e2),
        ChatErrorCode.limitExceeded,
      );
    });

    test('maps not_eligible and failed-precondition', () {
      final e1 = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'not_eligible',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e1),
        ChatErrorCode.notEligible,
      );
    });

    test('maps permission_denied and permission-denied', () {
      final e = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'permission_denied',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e),
        ChatErrorCode.permissionDenied,
      );
    });

    test('maps not_found and not-found', () {
      final e = FirebaseFunctionsException(
        code: 'not-found',
        message: 'not_found',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e),
        ChatErrorCode.notFound,
      );
    });

    test('maps conflict and aborted', () {
      final e = FirebaseFunctionsException(
        code: 'aborted',
        message: 'conflict',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e),
        ChatErrorCode.conflict,
      );
    });

    test('maps day_taken and already-exists', () {
      final e = FirebaseFunctionsException(
        code: 'already-exists',
        message: 'day_taken',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e),
        ChatErrorCode.dayTaken,
      );
    });

    test('maps invalid_argument and invalid-argument', () {
      final e = FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'invalid_argument',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e),
        ChatErrorCode.invalidArgument,
      );
    });

    test('maps network errors: unavailable and deadline-exceeded', () {
      final e1 = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'unavailable',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e1),
        ChatErrorCode.network,
      );

      final e2 = FirebaseFunctionsException(
        code: 'deadline-exceeded',
        message: 'timeout',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e2),
        ChatErrorCode.network,
      );
    });

    test('prefers details.code when available', () {
      final e = FirebaseFunctionsException(
        code: 'internal',
        message: 'something failed',
        details: {'code': 'limit_exceeded'},
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e),
        ChatErrorCode.limitExceeded,
      );
    });

    test('falls back to unknown for unhandled errors', () {
      final e = FirebaseFunctionsException(
        code: 'unknown_code',
        message: 'random',
      );
      expect(
        FirestoreChatRepository.mapFunctionsError(e),
        ChatErrorCode.unknown,
      );

      expect(
        FirestoreChatRepository.mapFunctionsError(Exception('non functions')),
        ChatErrorCode.unknown,
      );
    });
  });

  group('S07.02 hides event groups', () {
    test('watchMyChats drops event_group and keeps 1-1 chats', () async {
      final auth = _Auth();
      final user = _User();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
      final now = Timestamp.fromDate(DateTime(2026, 10, 3, 10));
      await firestore.doc('chats/c1').set({
        'kind': 'inquiry',
        'members': ['u1', 'p1'],
        'customerId': 'u1',
        'photographerId': 'p1',
        'lastMessageAt': now,
      });
      await firestore.doc('chats/event_ev1').set({
        'kind': 'event_group',
        'eventId': 'ev1',
        'title': 'Photo walk',
        'members': ['u1', 'p1'],
        'lastMessageAt': now,
      });
      final repo = FirestoreChatRepository(
        firestore: firestore,
        auth: auth,
        mediaUploader: FakeMediaUploader(),
      );
      final items = await repo.watchMyChats().first;
      expect(items.map((i) => i.thread.id), ['c1']);
    });

    test('the query filters on kind, so a newer group never takes a row of the page', () async {
      final auth = _Auth();
      final user = _User();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
      await firestore.doc('chats/c1').set({
        'kind': 'booking',
        'members': ['u1', 'p1'],
        'customerId': 'u1',
        'photographerId': 'p1',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 10, 3, 9)),
      });
      await firestore.doc('chats/event_ev1').set({
        'kind': 'event_group',
        'eventId': 'ev1',
        'title': 'Photo walk',
        'members': ['u1', 'p1'],
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 10, 3, 10)),
      });
      final repo = FirestoreChatRepository(
        firestore: firestore,
        auth: auth,
        mediaUploader: FakeMediaUploader(),
      );
      // With a one-row page, a client-side filter alone would return nothing.
      final items = await repo.watchMyChats(limit: 1).first;
      expect(items.map((i) => i.thread.id), ['c1']);
      expect(oneToOneChatKinds, ['inquiry', 'booking', 'collab']);
    });
  });

  group('group chat messages', () {
    test(
      'a group message parses the sender name, a tombstone and a join line',
      () async {
        final now = Timestamp.fromDate(DateTime(2026, 10, 3, 10));
        final text = await makeDoc('chats/event_ev1/messages/m1', {
          'senderId': 'u2',
          'senderName': 'Lan Anh',
          'type': 'text',
          'body': 'Chào cả nhóm',
          'createdAt': now,
        });
        final m = ChatMessage.fromFirestore(text);
        expect(
          (m.senderName, m.body, m.deletedAt),
          ('Lan Anh', 'Chào cả nhóm', null),
        );

        final gone = await makeDoc('chats/event_ev1/messages/m2', {
          'senderId': 'u2',
          'senderName': 'Lan Anh',
          'type': 'text',
          'body': null,
          'createdAt': now,
          'deletedAt': now,
        });
        expect(
          ChatMessage.fromFirestore(gone).deletedAt,
          DateTime(2026, 10, 3, 10),
        );

        final join = await makeDoc('chats/event_ev1/messages/m3', {
          'senderId': null,
          'type': 'system',
          'system': {
            'kind': 'member_joined',
            'userId': 'u3',
            'name': 'Minh Khoa',
          },
          'createdAt': now,
        });
        final j = ChatMessage.fromFirestore(join);
        expect(
          (j.system?.kind, j.system?.name, j.system?.userId),
          ('member_joined', 'Minh Khoa', 'u3'),
        );
      },
    );
  });
}
