import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

enum ChatErrorCode {
  limitExceeded,
  notEligible,
  permissionDenied,
  notFound,
  conflict,
  dayTaken,
  invalidArgument,
  blocked,
  network,
  unknown,
}

class ChatException implements Exception {
  const ChatException(this.code, [this.message]);
  final ChatErrorCode code;
  final String? message;

  @override
  String toString() => 'ChatException($code, $message)';
}

abstract class ChatRepository {
  Stream<ChatThread?> watchThread(String chatId);

  /// Newest [limit] messages, oldest first; [olderThan] pages back.
  Stream<List<ChatMessage>> watchMessages(String chatId, {int limit = 50});

  Future<List<ChatMessage>> olderMessages(
    String chatId, {
    required DateTime before,
    int limit = 50,
  });

  /// The signed-in user's 1-1 chats (inquiry and booking) that have at least
  /// one message, newest first, each with that user's unread count; live on
  /// both the chat and the user's member document.
  Stream<List<ChatListItem>> watchMyChats({int limit = 50});

  Future<String> openInquiry(String photographerId);

  Future<void> sendText(String chatId, String text, {required String clientId});

  /// Uploads [image] to `chats/{chatId}/{uid}/{clientId}.jpg` and returns that
  /// path. Storage never overwrites it, so a retry after a failed send reuses
  /// the path with [sendImagePath] instead of uploading again.
  Future<String> uploadChatImage(
    String chatId,
    PickedImage image, {
    required String clientId,
  });

  /// Posts an image message for an already uploaded [storagePath]
  /// (idempotent by [clientId] on the server).
  Future<void> sendImagePath(
    String chatId,
    String storagePath, {
    required String clientId,
  });

  Future<void> sendLocation(
    String chatId,
    ({double lat, double lng}) point, {
    required String clientId,
  });

  Future<void> markRead(String chatId);

  Future<void> proposeReschedule(
    String bookingId, {
    required String day,
    required String start,
    required String clientId,
  });

  Future<void> answerReschedule(
    String chatId,
    String messageId, {
    required bool accept,
  });
}
