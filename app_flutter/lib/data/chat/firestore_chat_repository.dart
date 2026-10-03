import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/media/firebase_media_uploader.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    MediaUploader? mediaUploader,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _customFunctions = functions,
        _auth = auth ?? FirebaseAuth.instance,
        _mediaUploader = mediaUploader ?? FirebaseMediaUploader();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _customFunctions;
  final FirebaseAuth _auth;
  final MediaUploader _mediaUploader;

  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  @visibleForTesting
  static ChatErrorCode mapFunctionsError(dynamic e) {
    if (e is FirebaseFunctionsException) {
      final detailsCode =
          e.details is Map ? (e.details as Map)['code'] as String? : null;
      for (final candidate in [detailsCode, e.code, e.message]) {
        if (candidate == null) continue;
        final mapped = switch (candidate) {
          'limit_exceeded' ||
          'resource-exhausted' => ChatErrorCode.limitExceeded,
          'not_eligible' ||
          'failed-precondition' => ChatErrorCode.notEligible,
          'permission_denied' ||
          'permission-denied' => ChatErrorCode.permissionDenied,
          'not_found' || 'not-found' => ChatErrorCode.notFound,
          'conflict' || 'aborted' => ChatErrorCode.conflict,
          'day_taken' || 'already-exists' => ChatErrorCode.dayTaken,
          'invalid_argument' ||
          'invalid-argument' => ChatErrorCode.invalidArgument,
          'unavailable' || 'deadline-exceeded' => ChatErrorCode.network,
          _ => null,
        };
        if (mapped != null) return mapped;
      }
    }
    return ChatErrorCode.unknown;
  }

  @override
  Stream<ChatThread?> watchThread(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatThread.fromFirestore(doc);
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final msgs =
              snap.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
          return msgs.reversed.toList();
        });
  }

  @override
  Future<List<ChatMessage>> olderMessages(
    String chatId, {
    required DateTime before,
    int limit = 50,
  }) async {
    final snap = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final msgs =
        snap.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
    return msgs.reversed.toList();
  }

  @override
  Stream<List<ChatListItem>> watchMyChats({int limit = 50}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('chats')
        .where('members', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
          final items = <ChatListItem>[];
          for (final doc in snap.docs) {
            final thread = ChatThread.fromFirestore(doc);
            int unread = 0;
            try {
              final memberDoc = await _firestore
                  .collection('chats')
                  .doc(doc.id)
                  .collection('members')
                  .doc(uid)
                  .get();
              if (memberDoc.exists) {
                unread = (memberDoc.data()?['unreadCount'] as num?)?.toInt() ?? 0;
              }
            } catch (_) {}
            items.add(ChatListItem(thread: thread, unreadCount: unread));
          }
          return items;
        });
  }

  @override
  Stream<int> watchTotalUnread() {
    return watchMyChats().map((items) {
      return items.fold<int>(0, (acc, item) => acc + item.unreadCount);
    });
  }

  @override
  Future<String> openInquiry(String photographerId) async {
    try {
      final res = await _functions
          .httpsCallable('openInquiry')
          .call<Map<String, dynamic>>({'photographerId': photographerId});
      final data = res.data;
      final chatId = data['chatId'] as String?;
      if (chatId == null) {
        throw const ChatException(
          ChatErrorCode.unknown,
          'Missing chatId in response',
        );
      }
      return chatId;
    } catch (e) {
      if (e is ChatException) rethrow;
      throw ChatException(mapFunctionsError(e), e.toString());
    }
  }

  @override
  Future<void> sendText(
    String chatId,
    String text, {
    required String clientId,
  }) async {
    try {
      await _functions.httpsCallable('sendMessage').call<dynamic>({
        'chatId': chatId,
        'message': {'type': 'text', 'body': text, 'clientId': clientId},
      });
    } catch (e) {
      throw ChatException(mapFunctionsError(e), e.toString());
    }
  }

  @override
  Future<void> sendImage(
    String chatId,
    PickedImage image, {
    required String clientId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChatException(
        ChatErrorCode.permissionDenied,
        'Unauthenticated',
      );
    }
    final storagePath = 'chats/$chatId/$uid/$clientId.webp';
    try {
      await _mediaUploader
          .upload(image, storagePath: storagePath)
          .lastWhere((event) => event.isDone);
      await _functions.httpsCallable('sendMessage').call<dynamic>({
        'chatId': chatId,
        'message': {
          'type': 'image',
          'imagePath': storagePath,
          'clientId': clientId,
        },
      });
    } catch (e) {
      throw ChatException(mapFunctionsError(e), e.toString());
    }
  }

  @override
  Future<void> sendLocation(
    String chatId,
    ({double lat, double lng}) point, {
    required String clientId,
  }) async {
    try {
      await _functions.httpsCallable('sendMessage').call<dynamic>({
        'chatId': chatId,
        'message': {
          'type': 'location',
          'point': {'lat': point.lat, 'lng': point.lng},
          'clientId': clientId,
        },
      });
    } catch (e) {
      throw ChatException(mapFunctionsError(e), e.toString());
    }
  }

  @override
  Future<void> markRead(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('members')
          .doc(uid)
          .update({
            'unreadCount': 0,
            'lastReadAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
  }

  @override
  Future<void> proposeReschedule(
    String bookingId, {
    required String day,
    required String start,
    required String clientId,
  }) async {
    try {
      await _functions.httpsCallable('proposeReschedule').call<dynamic>({
        'bookingId': bookingId,
        'day': day,
        'start': start,
        'clientId': clientId,
      });
    } catch (e) {
      throw ChatException(mapFunctionsError(e), e.toString());
    }
  }

  @override
  Future<void> answerReschedule(
    String chatId,
    String messageId, {
    required bool accept,
  }) async {
    try {
      await _functions.httpsCallable('answerReschedule').call<dynamic>({
        'chatId': chatId,
        'messageId': messageId,
        'accept': accept,
      });
    } catch (e) {
      throw ChatException(mapFunctionsError(e), e.toString());
    }
  }
}
