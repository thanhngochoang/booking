import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/chat/firestore_chat_repository.dart';
import 'package:photobooking/data/media/media_providers.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) =>
      FirestoreChatRepository(mediaUploader: ref.watch(mediaUploaderProvider)),
);

final chatThreadProvider = StreamProvider.autoDispose
    .family<ChatThread?, String>(
      (ref, chatId) => ref.watch(chatRepositoryProvider).watchThread(chatId),
    );

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
      (ref, chatId) => ref.watch(chatRepositoryProvider).watchMessages(chatId),
    );

final myChatsProvider = StreamProvider.autoDispose<List<ChatListItem>>(
  (ref) => ref.watch(chatRepositoryProvider).watchMyChats(),
);

/// Download URL of a chat image's storage path. A download URL is stable, so
/// each image is resolved once per run; an error is not kept (the next read
/// retries).
final chatImageUrlProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  storagePath,
) async {
  final url = await ref
      .watch(mediaUrlResolverProvider)
      .downloadUrl(storagePath);
  ref.keepAlive();
  return url;
});

/// Sum of the unread counts of [myChatsProvider] (the home chat icon); shares
/// its listeners instead of opening a second set.
final totalUnreadProvider = Provider.autoDispose<AsyncValue<int>>(
  (ref) => ref
      .watch(myChatsProvider)
      .whenData((items) => items.fold(0, (n, i) => n + i.unreadCount)),
);
