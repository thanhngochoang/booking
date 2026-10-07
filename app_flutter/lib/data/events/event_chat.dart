// lib/data/events/event_chat.dart
import 'package:flutter/foundation.dart';

/// `chats/event_{eventId}` as S11.06 needs it.
@immutable
class GroupChatThread {
  const GroupChatThread({
    required this.id,
    required this.eventId,
    required this.title,
    required this.memberCount,
    this.moderators = const [],
    this.moderatorsOnly = false,
    this.readOnlyAt,
  });

  final String id;
  final String eventId;
  final String title;
  final int memberCount;

  /// Uids of the host and the creator.
  final List<String> moderators;

  /// Only moderators may post.
  final bool moderatorsOnly;

  /// From this instant nobody sends (7 days after the event completes).
  final DateTime? readOnlyAt;

  bool isReadOnlyAt(DateTime now) =>
      readOnlyAt != null && !now.isBefore(readOnlyAt!);

  @override
  bool operator ==(Object other) =>
      other is GroupChatThread &&
      other.id == id &&
      other.eventId == eventId &&
      other.title == title &&
      other.memberCount == memberCount &&
      listEquals(other.moderators, moderators) &&
      other.moderatorsOnly == moderatorsOnly &&
      other.readOnlyAt == readOnlyAt;

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    title,
    memberCount,
    Object.hashAll(moderators),
    moderatorsOnly,
    readOnlyAt,
  );
}

enum GroupRole { member, moderator }

/// My own member doc: my role, a mute, whether I was removed.
@immutable
class GroupMemberState {
  const GroupMemberState({
    required this.role,
    this.mutedUntil,
    this.removed = false,
  });

  final GroupRole role;
  final DateTime? mutedUntil;
  final bool removed;

  bool isMutedAt(DateTime now) =>
      mutedUntil != null && now.isBefore(mutedUntil!);

  @override
  bool operator ==(Object other) =>
      other is GroupMemberState &&
      other.role == role &&
      other.mutedUntil == mutedUntil &&
      other.removed == removed;

  @override
  int get hashCode => Object.hash(role, mutedUntil, removed);
}

/// A row of the member list: names and avatars only, never a phone.
@immutable
class GroupMember {
  const GroupMember({
    required this.uid,
    required this.name,
    this.avatarUrl,
    this.role = GroupRole.member,
    this.mutedUntil,
    this.removedByModerator = false,
  });

  final String uid;
  final String name;
  final String? avatarUrl;
  final GroupRole role;
  final DateTime? mutedUntil;

  /// A moderator removed them (O1/M8): listed under "Đã mời ra" for the
  /// moderators, who can restore them. Members who left by cancelling are not
  /// listed at all.
  final bool removedByModerator;

  bool isMutedAt(DateTime now) =>
      mutedUntil != null && now.isBefore(mutedUntil!);

  @override
  bool operator ==(Object other) =>
      other is GroupMember &&
      other.uid == uid &&
      other.name == name &&
      other.avatarUrl == avatarUrl &&
      other.role == role &&
      other.mutedUntil == mutedUntil &&
      other.removedByModerator == removedByModerator;

  @override
  int get hashCode =>
      Object.hash(uid, name, avatarUrl, role, mutedUntil, removedByModerator);
}

/// The newest pinned message, shown at the top of the chat.
@immutable
class PinnedMessage {
  const PinnedMessage({
    required this.messageId,
    required this.body,
    required this.senderName,
    required this.pinnedAt,
  });

  final String messageId;
  final String body;
  final String senderName;
  final DateTime pinnedAt;

  @override
  bool operator ==(Object other) =>
      other is PinnedMessage &&
      other.messageId == messageId &&
      other.body == body &&
      other.senderName == senderName &&
      other.pinnedAt == pinnedAt;

  @override
  int get hashCode => Object.hash(messageId, body, senderName, pinnedAt);
}

/// A moderator action on the chat (`moderateEventChat`).
sealed class ChatModeration {
  const ChatModeration();

  /// The callable fields besides `eventId`.
  Map<String, Object?> toCallable();
}

final class PinMessage extends ChatModeration {
  const PinMessage(this.messageId);
  final String messageId;
  @override
  Map<String, Object?> toCallable() => {
    'action': 'pin',
    'messageId': messageId,
  };
}

final class UnpinMessage extends ChatModeration {
  const UnpinMessage(this.messageId);
  final String messageId;
  @override
  Map<String, Object?> toCallable() => {
    'action': 'unpin',
    'messageId': messageId,
  };
}

final class DeleteMessage extends ChatModeration {
  const DeleteMessage(this.messageId);
  final String messageId;
  @override
  Map<String, Object?> toCallable() => {
    'action': 'delete',
    'messageId': messageId,
  };
}

final class MuteMember extends ChatModeration {
  const MuteMember(this.userId, {this.minutes = 24 * 60});
  final String userId;
  final int minutes;
  @override
  Map<String, Object?> toCallable() => {
    'action': 'mute',
    'userId': userId,
    'minutes': minutes,
  };
}

final class UnmuteMember extends ChatModeration {
  const UnmuteMember(this.userId);
  final String userId;
  @override
  Map<String, Object?> toCallable() => {'action': 'unmute', 'userId': userId};
}

final class RemoveMember extends ChatModeration {
  const RemoveMember(this.userId);
  final String userId;
  @override
  Map<String, Object?> toCallable() => {'action': 'remove', 'userId': userId};
}

/// Lifts a moderator removal (O1/M8): back in at once with a paid ticket,
/// otherwise their next ticket lets them in.
final class RestoreMember extends ChatModeration {
  const RestoreMember(this.userId);
  final String userId;
  @override
  Map<String, Object?> toCallable() => {'action': 'restore', 'userId': userId};
}

final class SetModeratorsOnly extends ChatModeration {
  const SetModeratorsOnly({required this.on});
  final bool on;
  @override
  Map<String, Object?> toCallable() => {'action': 'moderatorsOnly', 'on': on};
}
