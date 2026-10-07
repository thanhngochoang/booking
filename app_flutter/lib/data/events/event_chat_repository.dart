// lib/data/events/event_chat_repository.dart
import 'dart:async';

import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

/// The group chat of an event (S11.06). Every write is a callable; a refusal
/// is a [ChatException].
abstract class EventChatRepository {
  /// Null when the chat does not exist or I may not read it (not a member).
  Stream<GroupChatThread?> watchChat(String eventId);

  /// My member doc; null for a moderator who has none yet and for non-members.
  Stream<GroupMemberState?> watchMe(String eventId);

  /// The people in the chat, names and avatars only, plus those a moderator
  /// removed ([GroupMember.removedByModerator]).
  Stream<List<GroupMember>> watchMembers(String eventId);

  /// Newest [limit] messages, oldest first.
  Stream<List<ChatMessage>> watchMessages(String eventId, {int limit = 50});

  Future<List<ChatMessage>> olderMessages(
    String eventId, {
    required DateTime before,
    int limit = 50,
  });

  Stream<PinnedMessage?> watchLatestPin(String eventId);

  Future<void> sendText(
    String eventId,
    String text, {
    required String clientId,
  });

  /// Uploads [image] to `chats/event_{eventId}/{uid}/{clientId}.jpg`, then sends it.
  Future<void> sendImage(
    String eventId,
    PickedImage image, {
    required String clientId,
  });

  Future<void> sendLocation(
    String eventId,
    ({double lat, double lng}) point, {
    required String clientId,
  });

  Future<void> moderate(String eventId, ChatModeration action);

  /// S12.03 "Nhắn nhóm": a moderator message, pinned. A retry with the same
  /// [clientId] posts it once.
  Future<void> announce(
    String eventId,
    String text, {
    required String clientId,
  });

  /// Zeroes my unread marker; failures are ignored.
  Future<void> markRead(String eventId);

  /// The download URL of an image message's storage path.
  Future<String> imageUrl(String imagePath);
}

/// In-memory group chat for tests and previews.
class FakeEventChatRepository implements EventChatRepository {
  FakeEventChatRepository({
    this.uid = 'u1',
    GroupChatThread? chat,
    GroupMemberState? me,
    List<GroupMember> members = const [],
    List<ChatMessage> messages = const [],
    PinnedMessage? pin,
  }) {
    _chat.value = chat;
    _me.value = me;
    _members.value = members;
    _messages.value = messages;
    _pin.value = pin;
  }

  final String uid;
  final _chat = _Cell<GroupChatThread?>(null);
  final _me = _Cell<GroupMemberState?>(null);
  final _members = _Cell<List<GroupMember>>(const []);
  final _messages = _Cell<List<ChatMessage>>(const []);
  final _pin = _Cell<PinnedMessage?>(null);

  /// Set while sends should fail; `failOnce` clears it after one throw.
  Object? failWith;
  bool failOnce = false;

  final List<({String eventId, String text, String clientId})> texts = [];
  final List<({String eventId, PickedImage image, String clientId})> images =
      [];
  final List<({String eventId, String clientId})> locations = [];
  final List<ChatModeration> moderations = [];
  final List<String> announcements = [];
  final List<String> announcementIds = [];
  int markedRead = 0;

  /// Download URLs by storage path; unknown paths resolve to a made-up URL.
  final Map<String, String> imageUrls = {};

  void setChat(GroupChatThread? v) => _chat.value = v;
  void setMe(GroupMemberState? v) => _me.value = v;
  void setMembers(List<GroupMember> v) => _members.value = v;
  void setMessages(List<ChatMessage> v) => _messages.value = v;
  void setPin(PinnedMessage? v) => _pin.value = v;
  GroupChatThread? get chat => _chat.value;
  List<ChatMessage> get messages => _messages.value;

  void _maybeFail() {
    final e = failWith;
    if (e != null) {
      if (failOnce) {
        failWith = null;
      }
      throw e;
    }
  }

  @override
  Stream<GroupChatThread?> watchChat(String eventId) => _chat.watch();

  @override
  Stream<GroupMemberState?> watchMe(String eventId) => _me.watch();

  @override
  Stream<List<GroupMember>> watchMembers(String eventId) => _members.watch();

  @override
  Stream<List<ChatMessage>> watchMessages(String eventId, {int limit = 50}) =>
      _messages.watch();

  @override
  Future<List<ChatMessage>> olderMessages(
    String eventId, {
    required DateTime before,
    int limit = 50,
  }) async => const [];

  @override
  Stream<PinnedMessage?> watchLatestPin(String eventId) => _pin.watch();

  void _land(ChatMessage m) => _messages.value = [..._messages.value, m];

  @override
  Future<void> sendText(
    String eventId,
    String text, {
    required String clientId,
  }) async {
    texts.add((eventId: eventId, text: text, clientId: clientId));
    _maybeFail();
    _land(
      ChatMessage(
        id: clientId,
        senderId: uid,
        type: MessageType.text,
        body: text,
        createdAt: DateTime.now().toUtc(),
        senderName: 'Tôi',
      ),
    );
  }

  @override
  Future<void> sendImage(
    String eventId,
    PickedImage image, {
    required String clientId,
  }) async {
    images.add((eventId: eventId, image: image, clientId: clientId));
    _maybeFail();
    _land(
      ChatMessage(
        id: clientId,
        senderId: uid,
        type: MessageType.image,
        imagePath: 'chats/event_$eventId/$uid/$clientId.jpg',
        createdAt: DateTime.now().toUtc(),
        senderName: 'Tôi',
      ),
    );
  }

  @override
  Future<void> sendLocation(
    String eventId,
    ({double lat, double lng}) point, {
    required String clientId,
  }) async {
    locations.add((eventId: eventId, clientId: clientId));
    _maybeFail();
    _land(
      ChatMessage(
        id: clientId,
        senderId: uid,
        type: MessageType.location,
        point: point,
        createdAt: DateTime.now().toUtc(),
        senderName: 'Tôi',
      ),
    );
  }

  @override
  Future<void> moderate(String eventId, ChatModeration action) async {
    _maybeFail();
    moderations.add(action);
    switch (action) {
      case PinMessage(:final messageId):
        final m = _messages.value.where((x) => x.id == messageId).firstOrNull;
        if (m != null) {
          _pin.value = PinnedMessage(
            messageId: messageId,
            body: m.body ?? '',
            senderName: m.senderName ?? '',
            pinnedAt: DateTime.now().toUtc(),
          );
        }
      case UnpinMessage(:final messageId):
        if (_pin.value?.messageId == messageId) {
          _pin.value = null;
        }
      case DeleteMessage(:final messageId):
        _messages.value = [
          for (final m in _messages.value)
            if (m.id == messageId)
              ChatMessage(
                id: m.id,
                senderId: m.senderId,
                type: m.type,
                createdAt: m.createdAt,
                senderName: m.senderName,
                deletedAt: DateTime.now().toUtc(),
              )
            else
              m,
        ];
      case SetModeratorsOnly(:final on):
        final c = _chat.value;
        if (c != null) {
          _chat.value = GroupChatThread(
            id: c.id,
            eventId: c.eventId,
            title: c.title,
            memberCount: c.memberCount,
            moderators: c.moderators,
            moderatorsOnly: on,
            readOnlyAt: c.readOnlyAt,
          );
        }
      case RemoveMember(:final userId):
        _setRemoved(userId, true);
      case RestoreMember(:final userId):
        _setRemoved(userId, false);
      case MuteMember() || UnmuteMember():
        break;
    }
  }

  void _setRemoved(String userId, bool removed) {
    _members.value = [
      for (final m in _members.value)
        if (m.uid == userId)
          GroupMember(
            uid: m.uid,
            name: m.name,
            avatarUrl: m.avatarUrl,
            role: m.role,
            mutedUntil: m.mutedUntil,
            removedByModerator: removed,
          )
        else
          m,
    ];
  }

  @override
  Future<void> announce(
    String eventId,
    String text, {
    required String clientId,
  }) async {
    announcementIds.add(clientId);
    _maybeFail();
    announcements.add(text);
  }

  @override
  Future<void> markRead(String eventId) async {
    markedRead++;
  }

  @override
  Future<String> imageUrl(String imagePath) async =>
      imageUrls[imagePath] ?? 'https://storage.test/$imagePath';
}

/// A value that replays to each new listener and then follows changes.
class _Cell<T> {
  _Cell(this._v);

  T _v;
  final _changes = StreamController<void>.broadcast();

  T get value => _v;
  set value(T v) {
    _v = v;
    _changes.add(null);
  }

  Stream<T> watch() {
    late final StreamController<T> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<T>(
      onListen: () {
        controller.add(_v);
        sub = _changes.stream.listen((_) => controller.add(_v));
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}
