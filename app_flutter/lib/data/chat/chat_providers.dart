import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/chat/firestore_chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => FirestoreChatRepository(),
);

final chatThreadProvider =
    StreamProvider.autoDispose.family<ChatThread?, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchThread(chatId),
);

final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchMessages(chatId),
);

final myChatsProvider = StreamProvider.autoDispose<List<ChatListItem>>(
  (ref) => ref.watch(chatRepositoryProvider).watchMyChats(),
);

final totalUnreadProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(chatRepositoryProvider).watchTotalUnread(),
);
