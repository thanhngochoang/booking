// lib/features/event_chat/event_chat_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/events/event_chat_repository.dart';
import 'package:photobooking/data/events/event_social_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';

@immutable
class EventChatState {
  const EventChatState({
    this.pending = const [],
    this.uploading = false,
    this.errorCode,
    this.errorSeq = 0,
  });

  /// Messages sent from this device that the stream has not returned yet.
  final List<ChatMessage> pending;
  final bool uploading;

  /// The last refusal; [errorSeq] changes with every one, so the screen can
  /// show the same refusal twice.
  final ChatErrorCode? errorCode;
  final int errorSeq;

  EventChatState copyWith({
    List<ChatMessage>? pending,
    bool? uploading,
    ChatErrorCode? errorCode,
  }) => EventChatState(
    pending: pending ?? this.pending,
    uploading: uploading ?? this.uploading,
    errorCode: errorCode ?? this.errorCode,
    errorSeq: errorCode == null ? errorSeq : errorSeq + 1,
  );
}

/// Sends to the group chat of one event and keeps the not-yet-confirmed
/// messages, so a failed one can be retried from its bubble.
class EventChatController extends Notifier<EventChatState> {
  EventChatController(this.eventId);
  final String eventId;

  /// The photo behind a pending image message, for a retry.
  final Map<String, PickedImage> _images = {};

  String? get _uid => ref.read(authStateProvider).value?.uid;
  DateTime get _now => ref.read(clockProvider)();

  @override
  EventChatState build() => const EventChatState();

  /// Drops pending messages the stream now holds.
  void syncWithStream(List<ChatMessage> stream) {
    if (state.pending.isEmpty) {
      return;
    }
    final ids = {for (final m in stream) m.id};
    final rest = [
      for (final m in state.pending)
        if (!ids.contains(m.id)) m,
    ];
    if (rest.length != state.pending.length) {
      Future.microtask(() {
        if (ref.mounted) {
          state = state.copyWith(pending: rest);
        }
      });
    }
  }

  void _set(String id, MessageSendState to, {ChatErrorCode? error}) {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      pending: [
        for (final m in state.pending)
          if (m.id == id) _withState(m, to) else m,
      ],
      errorCode: error,
    );
  }

  ChatMessage _withState(ChatMessage m, MessageSendState s) => ChatMessage(
    id: m.id,
    senderId: m.senderId,
    type: m.type,
    body: m.body,
    imagePath: m.imagePath,
    point: m.point,
    system: m.system,
    createdAt: m.createdAt,
    sendState: s,
    senderName: m.senderName,
  );

  ChatErrorCode _codeOf(Object e) =>
      e is ChatException ? e.code : ChatErrorCode.unknown;

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final id = newUlid(now: _now);
    state = state.copyWith(
      pending: [
        ...state.pending,
        ChatMessage(
          id: id,
          senderId: _uid,
          type: MessageType.text,
          body: trimmed,
          createdAt: _now,
          sendState: MessageSendState.sending,
        ),
      ],
    );
    await _deliver(id, () => _repo.sendText(eventId, trimmed, clientId: id));
  }

  Future<void> pickAndSendImage() async {
    if (state.uploading) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: 1);
    if (picked.isEmpty || !ref.mounted) {
      return;
    }
    final image = picked.first;
    final id = newUlid(now: _now);
    _images[id] = image;
    state = state.copyWith(
      uploading: true,
      pending: [
        ...state.pending,
        ChatMessage(
          id: id,
          senderId: _uid,
          type: MessageType.image,
          imagePath: image.path,
          createdAt: _now,
          sendState: MessageSendState.sending,
        ),
      ],
    );
    await _deliver(id, () => _repo.sendImage(eventId, image, clientId: id));
    if (ref.mounted) {
      state = state.copyWith(uploading: false);
    }
  }

  Future<void> retry(ChatMessage m) async {
    _set(m.id, MessageSendState.sending);
    switch (m.type) {
      case MessageType.text:
        await _deliver(
          m.id,
          () => _repo.sendText(eventId, m.body ?? '', clientId: m.id),
        );
      case MessageType.image:
        final image = _images[m.id];
        if (image != null) {
          await _deliver(
            m.id,
            () => _repo.sendImage(eventId, image, clientId: m.id),
          );
        }
      case MessageType.location || MessageType.system:
        break;
    }
  }

  Future<void> _deliver(String id, Future<void> Function() send) async {
    try {
      await send();
    } catch (e) {
      _set(id, MessageSendState.failed, error: _codeOf(e));
    }
  }

  /// A moderator action; false when the server refused.
  Future<bool> moderate(ChatModeration action) async {
    try {
      await _repo.moderate(eventId, action);
      return true;
    } catch (_) {
      return false;
    }
  }

  EventChatRepository get _repo => ref.read(eventChatRepositoryProvider);
}

final eventChatControllerProvider = NotifierProvider.autoDispose
    .family<EventChatController, EventChatState, String>(
      EventChatController.new,
    );

/// The local "Tắt tiếng nhóm" switch: it only changes this device's
/// indicator in the app bar (there is no push for group chats yet).
class GroupMuteController extends Notifier<bool> {
  GroupMuteController(this.eventId);
  final String eventId;

  String get _key =>
      'eventChatMuted:${ref.read(authStateProvider).value?.uid}:$eventId';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> toggle() async {
    final next = !state;
    state = next;
    await ref.read(sharedPreferencesProvider).setBool(_key, next);
  }
}

final groupMuteProvider = NotifierProvider.autoDispose
    .family<GroupMuteController, bool, String>(GroupMuteController.new);
