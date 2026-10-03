import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/chat/firestore_chat_repository.dart';

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
}
