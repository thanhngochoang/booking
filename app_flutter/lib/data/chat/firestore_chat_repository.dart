import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// The 1-1 chat kinds S07.02 lists (`chats.kind`); event groups (`event_group`) are excluded.
const oneToOneChatKinds = ['inquiry', 'booking'];

class FirestoreChatRepository implements ChatRepository {
  /// [currentUid] defaults to the signed-in Firebase user ([auth] or
  /// `FirebaseAuth.instance`, read lazily), so tests need no FirebaseAuth.
  FirestoreChatRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    String? Function()? currentUid,
    required this.mediaUploader,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _customFunctions = functions,
       _currentUid =
           currentUid ??
           (() => (auth ?? FirebaseAuth.instance).currentUser?.uid);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _customFunctions;
  final String? Function() _currentUid;

  /// Compresses and stores chat photos (`mediaUploaderProvider` in the app).
  final MediaUploader mediaUploader;

  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  @visibleForTesting
  static ChatErrorCode mapFunctionsError(dynamic e) {
    if (e is FirebaseFunctionsException) {
      final detailsCode = e.details is Map
          ? (e.details as Map)['code'] as String?
          : null;
      for (final candidate in [detailsCode, e.code, e.message]) {
        if (candidate == null) continue;
        final mapped = switch (candidate) {
          'limit_exceeded' ||
          'resource-exhausted' => ChatErrorCode.limitExceeded,
          'not_eligible' || 'failed-precondition' => ChatErrorCode.notEligible,
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
          final msgs = snap.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
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

    final msgs = snap.docs
        .map((doc) => ChatMessage.fromFirestore(doc))
        .toList();
    return msgs.reversed.toList();
  }

  @override
  Stream<List<ChatListItem>> watchMyChats({int limit = 50}) {
    final uid = _currentUid();
    if (uid == null) {
      return Stream.value(const []);
    }

    // One listener on the chats query plus one per listed chat on
    // chats/{id}/members/{uid} (the unread count): a new message costs the two
    // changed documents, and markRead (which only touches the member doc)
    // still reaches the list. No member doc is ever re-read with a `get`.
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? chatsSub;
    final memberSubs =
        <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final unread = <String, int>{};
    List<ChatThread>? threads; // null until the first chats snapshot
    late final StreamController<List<ChatListItem>> out;

    void emit() {
      final current = threads;
      // Wait until every listed chat has its member doc, so a badge never
      // shows 0 for a moment before its real number.
      if (current == null ||
          out.isClosed ||
          current.any((t) => !unread.containsKey(t.id))) {
        return;
      }
      out.add([
        for (final t in current)
          ChatListItem(thread: t, unreadCount: unread[t.id]!),
      ]);
    }

    void onChats(QuerySnapshot<Map<String, dynamic>> snap) {
      final next = <ChatThread>[
        for (final d in snap.docs)
          // Event group chats have their own screen (S11.06), never a row here
          // (kept as a guard behind the server filter).
          if (d.data()['kind'] != 'event_group') ChatThread.fromFirestore(d),
      ];
      // A chat nobody has written in yet (an inquiry opened and left) is not
      // listed: it would be a blank row for the photographer.
      next.removeWhere((t) => t.lastMessageAt == null);
      threads = next;
      final ids = {for (final t in next) t.id};
      for (final gone
          in memberSubs.keys.where((k) => !ids.contains(k)).toList()) {
        unawaited(memberSubs.remove(gone)!.cancel());
        unread.remove(gone);
      }
      for (final id in ids.where((k) => !memberSubs.containsKey(k))) {
        memberSubs[id] = _firestore
            .collection('chats')
            .doc(id)
            .collection('members')
            .doc(uid)
            .snapshots()
            .listen(
              (m) {
                unread[id] = (m.data()?['unreadCount'] as num?)?.toInt() ?? 0;
                emit();
              },
              // A member doc that cannot be read counts as nothing unread.
              onError: (Object _) {
                unread[id] ??= 0;
                emit();
              },
            );
      }
      emit();
    }

    out = StreamController<List<ChatListItem>>(
      onListen: () {
        // Filtered on the server (review I2): a group message must not re-fire
        // every member's inbox listener, and groups must not take rows of the
        // page. Index: chats (members CONTAINS, kind ASC, lastMessageAt DESC).
        chatsSub = _firestore
            .collection('chats')
            .where('members', arrayContains: uid)
            .where('kind', whereIn: oneToOneChatKinds)
            .orderBy('lastMessageAt', descending: true)
            .limit(limit)
            .snapshots()
            .listen(onChats, onError: out.addError);
      },
      onCancel: () async {
        await chatsSub?.cancel();
        final subs = memberSubs.values.toList();
        memberSubs.clear();
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return out.stream;
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
  Future<String> uploadChatImage(
    String chatId,
    PickedImage image, {
    required String clientId,
  }) async {
    final uid = _currentUid();
    if (uid == null) {
      throw const ChatException(
        ChatErrorCode.permissionDenied,
        'Unauthenticated',
      );
    }
    final storagePath = 'chats/$chatId/$uid/$clientId.jpg';
    try {
      await mediaUploader
          .upload(image, storagePath: storagePath, purpose: ImagePurpose.chat)
          .lastWhere((event) => event.isDone);
    } on FirebaseException catch (e) {
      throw ChatException(
        e.code == 'unauthorized'
            ? ChatErrorCode.permissionDenied
            : ChatErrorCode.network,
        e.code,
      );
    } catch (e) {
      throw ChatException(ChatErrorCode.unknown, e.toString());
    }
    return storagePath;
  }

  @override
  Future<void> sendImagePath(
    String chatId,
    String storagePath, {
    required String clientId,
  }) async {
    try {
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
    final uid = _currentUid();
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
