import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/explore/location_controller.dart';

@immutable
class ChatState {
  const ChatState({
    this.pendingMessages = const [],
    this.isUploadingImage = false,
    this.errorCode,
    this.errorSeq = 0,
  });

  final List<ChatMessage> pendingMessages;
  final bool isUploadingImage;

  /// The last refusal; [errorSeq] changes with every one, so the screen can
  /// show the same refusal twice.
  final ChatErrorCode? errorCode;
  final int errorSeq;

  ChatState copyWith({
    List<ChatMessage>? pendingMessages,
    bool? isUploadingImage,
    ChatErrorCode? errorCode,
  }) {
    return ChatState(
      pendingMessages: pendingMessages ?? this.pendingMessages,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      errorCode: errorCode ?? this.errorCode,
      errorSeq: errorCode == null ? errorSeq : errorSeq + 1,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  ChatController(this.chatId);

  final String chatId;

  /// The photo behind each image message sent from this screen: a retry needs
  /// it when the upload had failed, and the bubble keeps showing it once the
  /// message arrives.
  final Map<String, PickedImage> _images = {};

  /// Storage path of a photo whose upload succeeded. Storage refuses to
  /// overwrite, so a retry after a failed send posts this path again.
  final Map<String, String> _uploaded = {};

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
    if (remaining.length != state.pendingMessages.length && ref.mounted) {
      state = state.copyWith(pendingMessages: remaining);
    }
  }

  /// The file picked for the photo message [clientId], when this screen sent
  /// it; null for any other message.
  String? localFileFor(String clientId) => _images[clientId]?.path;

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

    final repo = _repo;
    try {
      await repo.sendText(chatId, trimmed, clientId: clientId);
    } catch (e) {
      _markFailed(clientId, e);
    }
  }

  Future<void> pickAndSendImage() async {
    final picker = ref.read(imagePickerProvider);
    final pickedList = await picker.pickImages(max: 1);
    if (pickedList.isEmpty || !ref.mounted) return;
    final picked = pickedList.first;

    final clientId = newUlid(now: _now);
    _images[clientId] = picked;
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

    final repo = _repo;
    try {
      await _sendPhoto(repo, clientId);
    } catch (e) {
      _markFailed(clientId, e);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isUploadingImage: false);
      }
    }
  }

  /// Uploads the photo once, then posts its path. After a failed post the
  /// path is already known, so a retry only posts again.
  Future<void> _sendPhoto(ChatRepository repo, String id) async {
    final path =
        _uploaded[id] ??
        await repo.uploadChatImage(chatId, _images[id]!, clientId: id);
    _uploaded[id] = path;
    await repo.sendImagePath(chatId, path, clientId: id);
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
    if (pos == null || !ref.mounted) {
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

    final repo = _repo;
    try {
      await repo.sendLocation(chatId, pos, clientId: clientId);
      return true;
    } catch (e) {
      _markFailed(clientId, e);
      return true;
    }
  }

  Future<void> retryMessage(ChatMessage msg) async {
    final clientId = msg.id;
    // An image whose file this screen does not know stays failed.
    if (msg.type == MessageType.image && !_images.containsKey(clientId)) {
      return;
    }
    _setState(clientId, MessageSendState.sending);

    final repo = _repo;
    try {
      switch (msg.type) {
        case MessageType.text:
          await repo.sendText(chatId, msg.body ?? '', clientId: clientId);
        case MessageType.location:
          if (msg.point != null) {
            await repo.sendLocation(chatId, msg.point!, clientId: clientId);
          }
        case MessageType.image:
          await _sendPhoto(repo, clientId);
        case MessageType.system:
          break;
      }
    } catch (e) {
      _markFailed(clientId, e);
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

  void _markFailed(String clientId, Object error) {
    _setState(
      clientId,
      MessageSendState.failed,
      error: error is ChatException ? error.code : ChatErrorCode.unknown,
    );
  }

  void _setState(String clientId, MessageSendState to, {ChatErrorCode? error}) {
    if (!ref.mounted) return;
    state = state.copyWith(
      pendingMessages: [
        for (final m in state.pendingMessages)
          if (m.id == clientId)
            ChatMessage(
              id: m.id,
              senderId: m.senderId,
              type: m.type,
              body: m.body,
              imagePath: m.imagePath,
              point: m.point,
              system: m.system,
              createdAt: m.createdAt,
              sendState: to,
            )
          else
            m,
      ],
      errorCode: error,
    );
  }
}

final chatControllerProvider = NotifierProvider.autoDispose
    .family<ChatController, ChatState, String>(ChatController.new);
