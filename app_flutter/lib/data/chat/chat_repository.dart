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

  Stream<List<ChatListItem>> watchMyChats({int limit = 50});

  Stream<int> watchTotalUnread();

  Future<String> openInquiry(String photographerId);

  Future<void> sendText(String chatId, String text, {required String clientId});

  Future<void> sendImage(
    String chatId,
    PickedImage image, {
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
