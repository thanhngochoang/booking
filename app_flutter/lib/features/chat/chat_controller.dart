import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/explore/location_controller.dart';

@immutable
class ChatState {
  const ChatState({
    this.pendingMessages = const [],
    this.isUploadingImage = false,
    this.error,
  });

  final List<ChatMessage> pendingMessages;
  final bool isUploadingImage;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? pendingMessages,
    bool? isUploadingImage,
    String? error,
  }) {
    return ChatState(
      pendingMessages: pendingMessages ?? this.pendingMessages,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      error: error,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  ChatController(this.chatId);

  final String chatId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  String? get _currentUserId => ref.read(authStateProvider).value?.uid;
  DateTime get _now => ref.read(clockProvider)();

  @override
  ChatState build() {
    return const ChatState();
  }

  /// Cleans up any pending messages whose clientId/id is already in the stream.
  void syncWithStream(List<ChatMessage> streamMessages) {
    if (state.pendingMessages.isEmpty) return;
    final streamIds = streamMessages.map((m) => m.id).toSet();
    final remaining = state.pendingMessages
        .where((m) => !streamIds.contains(m.id))
        .toList();
    if (remaining.length != state.pendingMessages.length) {
      state = state.copyWith(pendingMessages: remaining);
    }
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final clientId = newUlid(now: _now);
    final pendingMsg = ChatMessage(
      id: clientId,
      senderId: _currentUserId,
      type: MessageType.text,
      body: trimmed,
      createdAt: _now,
      sendState: MessageSendState.sending,
    );

    state = state.copyWith(
      pendingMessages: [...state.pendingMessages, pendingMsg],
    );

    try {
      await _repo.sendText(chatId, trimmed, clientId: clientId);
    } catch (e) {
      _markFailed(clientId);
    }
  }

  Future<void> pickAndSendImage() async {
    final picker = ref.read(imagePickerProvider);
    final pickedList = await picker.pickImages(max: 1);
    if (pickedList.isEmpty) return;
    final picked = pickedList.first;

    final clientId = newUlid(now: _now);
    final pendingMsg = ChatMessage(
      id: clientId,
      senderId: _currentUserId,
      type: MessageType.image,
      imagePath: picked.path,
      createdAt: _now,
      sendState: MessageSendState.sending,
    );

    state = state.copyWith(
      isUploadingImage: true,
      pendingMessages: [...state.pendingMessages, pendingMsg],
    );

    try {
      final path = await _repo.uploadChatImage(
        chatId,
        picked,
        clientId: clientId,
      );
      await _repo.sendImagePath(chatId, path, clientId: clientId);
    } catch (e) {
      _markFailed(clientId);
    } finally {
      state = state.copyWith(isUploadingImage: false);
    }
  }

  Future<bool> sendLocation() async {
    final locationRepo = ref.read(locationRepositoryProvider);
    var status = await locationRepo.permissionStatus();
    if (status != LocationPermissionStatus.granted) {
      status = await locationRepo.request();
    }
    if (status != LocationPermissionStatus.granted) {
      return false;
    }
    final pos = await locationRepo.currentPosition();
    if (pos == null) {
      return false;
    }

    final clientId = newUlid(now: _now);
    final pendingMsg = ChatMessage(
      id: clientId,
      senderId: _currentUserId,
      type: MessageType.location,
      point: pos,
      createdAt: _now,
      sendState: MessageSendState.sending,
    );

    state = state.copyWith(
      pendingMessages: [...state.pendingMessages, pendingMsg],
    );

    try {
      await _repo.sendLocation(chatId, pos, clientId: clientId);
      return true;
    } catch (e) {
      _markFailed(clientId);
      return true;
    }
  }

  Future<void> retryMessage(ChatMessage msg) async {
    final clientId = msg.id;
    // Mark as sending
    state = state.copyWith(
      pendingMessages: state.pendingMessages.map((m) {
        if (m.id == clientId) {
          return ChatMessage(
            id: m.id,
            senderId: m.senderId,
            type: m.type,
            body: m.body,
            imagePath: m.imagePath,
            point: m.point,
            system: m.system,
            createdAt: m.createdAt,
            sendState: MessageSendState.sending,
          );
        }
        return m;
      }).toList(),
    );

    try {
      switch (msg.type) {
        case MessageType.text:
          await _repo.sendText(chatId, msg.body ?? '', clientId: clientId);
        case MessageType.location:
          if (msg.point != null) {
            await _repo.sendLocation(chatId, msg.point!, clientId: clientId);
          }
        case MessageType.image:
          break;
        case MessageType.system:
          break;
      }
    } catch (e) {
      _markFailed(clientId);
    }
  }

  Future<void> proposeReschedule({
    required String bookingId,
    required String day,
    required String start,
  }) async {
    final clientId = newUlid(now: _now);
    await _repo.proposeReschedule(
      bookingId,
      day: day,
      start: start,
      clientId: clientId,
    );
  }

  Future<void> answerReschedule(
    String messageId, {
    required bool accept,
  }) async {
    await _repo.answerReschedule(chatId, messageId, accept: accept);
  }

  void _markFailed(String clientId) {
    state = state.copyWith(
      pendingMessages: state.pendingMessages.map((m) {
        if (m.id == clientId) {
          return ChatMessage(
            id: m.id,
            senderId: m.senderId,
            type: m.type,
            body: m.body,
            imagePath: m.imagePath,
            point: m.point,
            system: m.system,
            createdAt: m.createdAt,
            sendState: MessageSendState.failed,
          );
        }
        return m;
      }).toList(),
    );
  }
}

final chatControllerProvider = NotifierProvider.autoDispose
    .family<ChatController, ChatState, String>(ChatController.new);
