// lib/data/events/firestore_event_chat_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/events/event_callable.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/events/event_chat_repository.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate().toUtc() : null;

String chatIdOfEvent(String eventId) => 'event_$eventId';

/// `chats/event_{id}` → thread; null for a chat that is not an event group.
GroupChatThread? groupChatFromFirestore(String id, Map<String, dynamic>? d) {
  if (d == null || d['kind'] != 'event_group') {
    return null;
  }
  final members = d['members'];
  return GroupChatThread(
    id: id,
    eventId: d['eventId'] is String ? d['eventId'] as String : '',
    title: d['title'] is String ? d['title'] as String : '',
    memberCount: d['memberCount'] is num
        ? (d['memberCount'] as num).toInt()
        : (members is List ? members.length : 0),
    moderators: [
      if (d['moderators'] is List)
        ...(d['moderators'] as List).whereType<String>(),
    ],
    moderatorsOnly: d['moderatorsOnly'] == true,
    readOnlyAt: _date(d['readOnlyAt']),
  );
}

/// [make]'s values; on a `permission-denied` refusal it emits [fallback] and
/// listens again after [every], at most [attempts] listens in all. Cancelling
/// stops the wait at once: no listen starts after the subscription is gone
/// (review M1).
Stream<T> healingStream<T>(
  Stream<T> Function() make,
  T fallback, {
  required int attempts,
  required Duration every,
}) {
  late final StreamController<T> out;
  StreamSubscription<T>? sub;
  Timer? wait;
  var tries = 0;
  var stopped = false;

  void listen() {
    if (stopped) {
      return;
    }
    tries++;
    sub = make().listen(
      out.add,
      onError: (Object error, StackTrace stack) {
        final refused =
            error is FirebaseException && error.code == 'permission-denied';
        // A refused (or failed) listen is over; drop it before going on.
        final old = sub;
        sub = null;
        unawaited(old?.cancel());
        if (!refused) {
          out.addError(error, stack);
          unawaited(out.close());
          return;
        }
        out.add(fallback);
        if (tries < attempts) {
          wait = Timer(every, listen);
        } else {
          unawaited(out.close());
        }
      },
      onDone: () {
        if (wait?.isActive != true) {
          unawaited(out.close());
        }
      },
    );
  }

  out = StreamController<T>(
    onListen: listen,
    onCancel: () async {
      stopped = true;
      wait?.cancel();
      await sub?.cancel();
    },
  );
  return out.stream;
}

GroupRole _role(Object? v) =>
    v == 'moderator' ? GroupRole.moderator : GroupRole.member;

/// Reads the group chat directly (members only, by the rules); every write is
/// a callable, so rate limits and moderation hold on the server.
class FirestoreEventChatRepository implements EventChatRepository {
  FirestoreEventChatRepository({
    required this.uid,
    required this.uploader,
    required this.urls,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
    this.healAttempts = 10,
    this.healEvery = const Duration(seconds: 3),
  }) : _override = db,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final String? uid;
  final MediaUploader uploader;
  final MediaUrlResolver urls;

  /// Re-listens after a refusal: 10 tries, 3 seconds apart by default, about
  /// the time the membership trigger needs.
  final int healAttempts;
  final Duration healEvery;
  final FirebaseFirestore? _override;
  final FirebaseFunctions _functions;

  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _chat(String eventId) =>
      _db.collection('chats').doc(chatIdOfEvent(eventId));

  /// A read the rules refuse (not a member, removed) is "nothing there".
  Stream<T> _orIfDenied<T>(Stream<T> source, T fallback) => source.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (error, stack, sink) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          sink.add(fallback);
        } else {
          sink.addError(error, stack);
        }
      },
    ),
  );

  /// Like [_orIfDenied], but tries again: a person who registers a moment
  /// before the server adds them to the chat is refused at first, and a
  /// Firestore listener never recovers from a refusal by itself.
  Stream<T> _healing<T>(Stream<T> Function() make, T fallback) =>
      healingStream(make, fallback, attempts: healAttempts, every: healEvery);

  @override
  Stream<GroupChatThread?> watchChat(String eventId) {
    if (!validEventPathId(eventId)) {
      return Stream.value(null);
    }
    return _healing<GroupChatThread?>(
      () => _chat(eventId)
          .snapshots()
          .map((s) => s.exists ? groupChatFromFirestore(s.id, s.data()) : null),
      null,
    );
  }

  @override
  Stream<GroupMemberState?> watchMe(String eventId) {
    final me = uid;
    if (me == null || !validEventPathId(eventId)) {
      return Stream.value(null);
    }
    return _healing<GroupMemberState?>(
      () => _chat(eventId).collection('members').doc(me).snapshots().map((s) {
        final d = s.data();
        if (!s.exists || d == null || d['role'] == null) {
          return null;
        }
        return GroupMemberState(
          role: _role(d['role']),
          mutedUntil: _date(d['mutedUntil']),
          removed: d['removedAt'] != null,
        );
      }),
      null,
    );
  }

  @override
  Stream<List<GroupMember>> watchMembers(String eventId) {
    if (!validEventPathId(eventId)) {
      return Stream.value(const []);
    }
    return _orIfDenied<List<GroupMember>>(
      _chat(eventId).collection('members').snapshots().map((qs) {
        final out = [
          for (final d in qs.docs)
            // Members now, and those a moderator removed (they can be
            // restored); someone who left by cancelling is not listed.
            if (d.data()['role'] != null &&
                (d.data()['removedAt'] == null ||
                    d.data()['removedBy'] is String))
              GroupMember(
                uid: d.id,
                name: d.data()['name'] is String
                    ? d.data()['name'] as String
                    : '',
                avatarUrl: d.data()['avatarUrl'] as String?,
                role: _role(d.data()['role']),
                mutedUntil: _date(d.data()['mutedUntil']),
                removedByModerator:
                    d.data()['removedAt'] != null &&
                    d.data()['removedBy'] is String,
              ),
        ];
        out.sort((a, b) {
          if (a.role != b.role) {
            return a.role == GroupRole.moderator ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return out;
      }),
      const [],
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String eventId, {int limit = 50}) {
    if (!validEventPathId(eventId)) {
      return Stream.value(const []);
    }
    return _orIfDenied<List<ChatMessage>>(
      _chat(eventId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snap) => [
              for (final d in snap.docs.reversed) ChatMessage.fromFirestore(d),
            ],
          ),
      const [],
    );
  }

  @override
  Future<List<ChatMessage>> olderMessages(
    String eventId, {
    required DateTime before,
    int limit = 50,
  }) async {
    if (!validEventPathId(eventId)) {
      return const [];
    }
    final snap = await _chat(eventId)
        .collection('messages')
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in snap.docs.reversed) ChatMessage.fromFirestore(d)];
  }

  @override
  Stream<PinnedMessage?> watchLatestPin(String eventId) {
    if (!validEventPathId(eventId)) {
      return Stream.value(null);
    }
    return _orIfDenied<PinnedMessage?>(
      _chat(eventId)
          .collection('pins')
          .orderBy('pinnedAt', descending: true)
          .limit(1)
          .snapshots()
          .map((qs) {
            if (qs.docs.isEmpty) {
              return null;
            }
            final d = qs.docs.first.data();
            final at = _date(d['pinnedAt']);
            if (at == null) {
              return null;
            }
            return PinnedMessage(
              messageId: qs.docs.first.id,
              body: d['body'] is String ? d['body'] as String : '',
              senderName: d['senderName'] is String
                  ? d['senderName'] as String
                  : '',
              pinnedAt: at,
            );
          }),
      null,
    );
  }

  Future<void> _send(String eventId, Map<String, Object?> message) async {
    try {
      await callEventFunction(_functions, 'sendEventMessage', {
        'eventId': eventId,
        'message': message,
      });
    } on EventError catch (e) {
      throw ChatException(_chatCode(e.code), e.code);
    }
  }

  /// The chat screens speak [ChatErrorCode]; map the domain codes onto it.
  static ChatErrorCode _chatCode(String code) => switch (code) {
    'limit_exceeded' => ChatErrorCode.limitExceeded,
    'not_eligible' => ChatErrorCode.notEligible,
    'permission_denied' => ChatErrorCode.permissionDenied,
    'not_found' => ChatErrorCode.notFound,
    'conflict' => ChatErrorCode.conflict,
    'invalid_argument' => ChatErrorCode.invalidArgument,
    'network' => ChatErrorCode.network,
    _ => ChatErrorCode.unknown,
  };

  @override
  Future<void> sendText(
    String eventId,
    String text, {
    required String clientId,
  }) => _send(eventId, {'type': 'text', 'body': text, 'clientId': clientId});

  @override
  Future<void> sendImage(
    String eventId,
    PickedImage image, {
    required String clientId,
  }) async {
    final me = uid;
    if (me == null) {
      throw const ChatException(
        ChatErrorCode.permissionDenied,
        'Unauthenticated',
      );
    }
    final path = 'chats/${chatIdOfEvent(eventId)}/$me/$clientId.jpg';
    try {
      await uploader
          .upload(image, storagePath: path)
          .lastWhere((e) => e.isDone);
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
    await _send(eventId, {
      'type': 'image',
      'imagePath': path,
      'clientId': clientId,
    });
  }

  @override
  Future<void> sendLocation(
    String eventId,
    ({double lat, double lng}) point, {
    required String clientId,
  }) => _send(eventId, {
    'type': 'location',
    'point': {'lat': point.lat, 'lng': point.lng},
    'clientId': clientId,
  });

  @override
  Future<void> moderate(String eventId, ChatModeration action) async {
    try {
      await callEventFunction(_functions, 'moderateEventChat', {
        'eventId': eventId,
        ...action.toCallable(),
      });
    } on EventError catch (e) {
      throw ChatException(_chatCode(e.code), e.code);
    }
  }

  @override
  Future<void> announce(
    String eventId,
    String text, {
    required String clientId,
  }) async {
    try {
      await callEventFunction(_functions, 'postEventAnnouncement', {
        'eventId': eventId,
        'text': text,
        'clientId': clientId,
      });
    } on EventError catch (e) {
      throw ChatException(_chatCode(e.code), e.code);
    }
  }

  @override
  Future<void> markRead(String eventId) async {
    final me = uid;
    if (me == null || !validEventPathId(eventId)) {
      return;
    }
    try {
      await _chat(eventId).collection('members').doc(me).update({
        'unreadCount': 0,
        'lastReadAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // A moderator without a member doc, or a lost connection: not worth a message.
    }
  }

  @override
  Future<String> imageUrl(String imagePath) => urls.downloadUrl(imagePath);
}
