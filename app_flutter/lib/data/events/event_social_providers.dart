// lib/data/events/event_social_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/events/event_chat_repository.dart';
import 'package:photobooking/data/events/event_timeline_repository.dart';
import 'package:photobooking/data/events/firestore_event_chat_repository.dart';
import 'package:photobooking/data/events/firestore_event_timeline_repository.dart';
import 'package:photobooking/data/media/media_providers.dart';

/// The timeline of an event (S11.05). Rebuilt when the signed-in user changes.
final eventTimelineRepositoryProvider = Provider<EventTimelineRepository>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return FirestoreEventTimelineRepository(
    uid: uid,
    uploader: ref.watch(mediaUploaderProvider),
  );
});

/// The group chat of an event (S11.06).
final eventChatRepositoryProvider = Provider<EventChatRepository>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return FirestoreEventChatRepository(
    uid: uid,
    uploader: ref.watch(mediaUploaderProvider),
    urls: ref.watch(mediaUrlResolverProvider),
  );
});

/// Posts waiting for approval (managers see the "Chờ duyệt" tab with it).
final timelinePendingCountProvider = StreamProvider.autoDispose
    .family<int, String>(
      (ref, eventId) =>
          ref.watch(eventTimelineRepositoryProvider).watchPendingCount(eventId),
    );

final groupChatProvider = StreamProvider.autoDispose
    .family<GroupChatThread?, String>(
      (ref, eventId) =>
          ref.watch(eventChatRepositoryProvider).watchChat(eventId),
    );

final groupMeProvider = StreamProvider.autoDispose
    .family<GroupMemberState?, String>(
      (ref, eventId) => ref.watch(eventChatRepositoryProvider).watchMe(eventId),
    );

final groupMembersProvider = StreamProvider.autoDispose
    .family<List<GroupMember>, String>(
      (ref, eventId) =>
          ref.watch(eventChatRepositoryProvider).watchMembers(eventId),
    );

final groupMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
      (ref, eventId) =>
          ref.watch(eventChatRepositoryProvider).watchMessages(eventId),
    );

final groupPinProvider = StreamProvider.autoDispose
    .family<PinnedMessage?, String>(
      (ref, eventId) =>
          ref.watch(eventChatRepositoryProvider).watchLatestPin(eventId),
    );

/// The download URL of a chat image (an image message stores its storage path).
final groupImageUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(eventChatRepositoryProvider).imageUrl(path),
);
